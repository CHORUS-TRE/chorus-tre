#!/usr/bin/env bash
# ci/run-chart-e2e.sh — Generic chart e2e test runner
#
# Deploys a chart into a Kind+Cilium cluster and runs connectivity tests
# based on the central test registry (ci/chart-tests.yaml).
#
# Usage: ./ci/run-chart-e2e.sh <chart_path> <chart_name>
#   e.g.: ./ci/run-chart-e2e.sh charts/i2b2-wildfly i2b2-wildfly
#
# Requires: helm, kubectl, yq (v4+)
# Expects: a running Kind cluster with Cilium CNI installed

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REGISTRY="${REPO_ROOT}/ci/chart-tests.yaml"
TEST_IMAGE="busybox:1.36"
CONNECT_TIMEOUT=5  # seconds for positive tests
BLOCK_TIMEOUT=5    # seconds for negative tests (expect timeout)

# ── Colors ────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ── Helpers ───────────────────────────────────────────────────
pass() { echo -e "${GREEN}  ✅ PASS: $1${NC}"; }
fail() { echo -e "${RED}  ❌ FAIL: $1${NC}"; FAILURES=$((FAILURES + 1)); }
info() { echo -e "${CYAN}  ℹ️  $1${NC}"; }
warn() { echo -e "${YELLOW}  ⚠️  $1${NC}"; }
section() { echo -e "\n${CYAN}━━━ $1 ━━━${NC}"; }

FAILURES=0
TESTS_RUN=0

# ── Args ──────────────────────────────────────────────────────
if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <chart_path> <chart_name>"
    echo "  e.g.: $0 charts/i2b2-wildfly i2b2-wildfly"
    exit 1
fi

CHART_PATH="$1"
CHART_NAME="$2"

# ── Read config from registry ─────────────────────────────────
chart_config() {
    # Read a value from chart-tests.yaml for this chart, with a default fallback
    local key="$1"
    local default="${2:-}"
    local val
    val=$(yq ".charts.\"${CHART_NAME}\".${key} // \"\"" "$REGISTRY" 2>/dev/null)
    if [[ -z "$val" || "$val" == "null" ]]; then
        echo "$default"
    else
        echo "$val"
    fi
}

defaults_config() {
    local key="$1"
    local default="${2:-}"
    local val
    val=$(yq ".defaults.${key} // \"\"" "$REGISTRY" 2>/dev/null)
    if [[ -z "$val" || "$val" == "null" ]]; then
        echo "$default"
    else
        echo "$val"
    fi
}

NAMESPACE=$(chart_config "namespace" "$(defaults_config "namespace" "test")")
TIMEOUT=$(chart_config "timeout" "$(defaults_config "timeout" "120")")
SKIP_DEPLOY=$(chart_config "skip_deploy" "false")
VALUES_FILE=$(chart_config "values_file" "")
RELEASE_NAME="e2e-${CHART_NAME}"

section "Chart E2E: ${CHART_NAME}"
echo "  Chart path:   ${CHART_PATH}"
echo "  Namespace:    ${NAMESPACE}"
echo "  Release:      ${RELEASE_NAME}"
echo "  Timeout:      ${TIMEOUT}s"

# ── Check if chart should be skipped ──────────────────────────
if [[ "$SKIP_DEPLOY" == "true" ]]; then
    info "Chart marked as skip_deploy (CRD/infra only). Skipping."
    exit 0
fi

# ── Phase 0: Setup namespace ─────────────────────────────────
section "Phase 0: Setup"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
info "Namespace '${NAMESPACE}' ready"

# Debug: show namespace labels (important for namespaceSelector-based NetworkPolicies)
info "Namespace labels:"
kubectl get namespace "$NAMESPACE" --show-labels 2>/dev/null || true

# Run pre_install commands if defined (e.g., create secrets)
PRE_INSTALL_COUNT=$(yq ".charts.\"${CHART_NAME}\".pre_install | length // 0" "$REGISTRY" 2>/dev/null || echo 0)
if [[ "$PRE_INSTALL_COUNT" -gt 0 ]]; then
    info "Running ${PRE_INSTALL_COUNT} pre-install command(s)..."
    for i in $(seq 0 $((PRE_INSTALL_COUNT - 1))); do
        CMD=$(yq -r ".charts.\"${CHART_NAME}\".pre_install[$i]" "$REGISTRY")
        info "  → $CMD"
        eval "$CMD"
    done
fi

# ── Phase 0b: Deploy dependency charts (depends_on) ──────────
DEP_COUNT=$(yq ".charts.\"${CHART_NAME}\".depends_on | length // 0" "$REGISTRY" 2>/dev/null || echo 0)

if [[ "$DEP_COUNT" -gt 0 ]]; then
    section "Phase 0b: Deploy Dependencies"
    for d in $(seq 0 $((DEP_COUNT - 1))); do
        DEP_NAME=$(yq -r ".charts.\"${CHART_NAME}\".depends_on[$d]" "$REGISTRY")
        DEP_RELEASE="e2e-${DEP_NAME}"
        DEP_NS=$(yq ".charts.\"${DEP_NAME}\".namespace // \"${NAMESPACE}\"" "$REGISTRY")
        DEP_TIMEOUT=$(yq ".charts.\"${DEP_NAME}\".timeout // 120" "$REGISTRY")
        DEP_VALUES_FILE=$(yq ".charts.\"${DEP_NAME}\".values_file // \"\"" "$REGISTRY")

        info "Dependency: ${DEP_NAME} (release ${DEP_RELEASE}, ns ${DEP_NS})"

        # Check if already deployed (from a previous chart's depends_on)
        if helm status "$DEP_RELEASE" -n "$DEP_NS" &>/dev/null; then
            info "  Already deployed — skipping"
            continue
        fi

        # Create namespace if different from main chart
        if [[ "$DEP_NS" != "$NAMESPACE" ]]; then
            kubectl create namespace "$DEP_NS" --dry-run=client -o yaml | kubectl apply -f -
        fi

        # Run dependency's pre_install commands
        DEP_PRE_COUNT=$(yq ".charts.\"${DEP_NAME}\".pre_install | length // 0" "$REGISTRY" 2>/dev/null || echo 0)
        if [[ "$DEP_PRE_COUNT" -gt 0 ]]; then
            info "  Running ${DEP_PRE_COUNT} pre-install command(s) for ${DEP_NAME}..."
            for pi in $(seq 0 $((DEP_PRE_COUNT - 1))); do
                DEP_CMD=$(yq -r ".charts.\"${DEP_NAME}\".pre_install[$pi]" "$REGISTRY")
                info "    → $DEP_CMD"
                eval "$DEP_CMD"
            done
        fi

        # Build helm install command for dependency
        DEP_CHART_PATH="charts/${DEP_NAME}"
        DEP_HELM_CMD=(helm install "$DEP_RELEASE" "${REPO_ROOT}/${DEP_CHART_PATH}"
            --namespace "$DEP_NS"
            --values "${REPO_ROOT}/${DEP_CHART_PATH}/values.yaml"
            --set "fullnameOverride=${DEP_RELEASE}"
            --wait --timeout "${DEP_TIMEOUT}s"
        )
        if [[ -n "$DEP_VALUES_FILE" && "$DEP_VALUES_FILE" != "null" ]]; then
            DEP_HELM_CMD+=(--values "${REPO_ROOT}/${DEP_VALUES_FILE}")
        fi

        # Build dependencies (sub-charts)
        helm dependency build "${REPO_ROOT}/${DEP_CHART_PATH}" 2>/dev/null || true

        info "  Installing dependency chart..."
        echo "    ${DEP_HELM_CMD[*]}"
        if "${DEP_HELM_CMD[@]}" 2>&1; then
            pass "Dependency ${DEP_NAME} deployed"
        else
            fail "Dependency ${DEP_NAME} failed to deploy — aborting"
            exit 1
        fi
    done
fi

# ── Phase 1: Deploy chart ─────────────────────────────────────
section "Phase 1: Deploy"

# Build --set flags from registry
HELM_SET_ARGS=()
while IFS='=' read -r key val; do
    [[ -z "$key" ]] && continue
    HELM_SET_ARGS+=(--set "$key=$val")
done < <(yq -r ".charts.\"${CHART_NAME}\".values // {} | to_entries[] | .key + \"=\" + (.value | tostring)" "$REGISTRY" 2>/dev/null || true)

# Add fullnameOverride so we know the resource names
HELM_SET_ARGS+=(--set "fullnameOverride=${RELEASE_NAME}")

# Build dependencies
info "Updating Helm dependencies..."
helm dependency build "${REPO_ROOT}/${CHART_PATH}" 2>/dev/null || true

# Build helm install command
HELM_CMD=(helm install "$RELEASE_NAME" "${REPO_ROOT}/${CHART_PATH}"
    --namespace "$NAMESPACE"
    --values "${REPO_ROOT}/${CHART_PATH}/values.yaml"
    --wait --timeout "${TIMEOUT}s"
)

# Add CI values file if specified
if [[ -n "$VALUES_FILE" ]]; then
    HELM_CMD+=(--values "${REPO_ROOT}/${VALUES_FILE}")
fi

# Add --set overrides
HELM_CMD+=("${HELM_SET_ARGS[@]}")

info "Installing chart..."
echo "  ${HELM_CMD[*]}"

if "${HELM_CMD[@]}" 2>&1; then
    pass "Chart deployed successfully"
else
    # Deploy failed — the image may not start (expected for apps needing backends)
    # Try without --wait so we can still test network policies on the service
    warn "Helm install with --wait failed. Retrying without --wait..."
    HELM_CMD_NOWAIT=(helm install "$RELEASE_NAME" "${REPO_ROOT}/${CHART_PATH}"
        --namespace "$NAMESPACE"
        --values "${REPO_ROOT}/${CHART_PATH}/values.yaml"
        --timeout "${TIMEOUT}s"
    )
    if [[ -n "$VALUES_FILE" ]]; then
        HELM_CMD_NOWAIT+=(--values "${REPO_ROOT}/${VALUES_FILE}")
    fi
    HELM_CMD_NOWAIT+=("${HELM_SET_ARGS[@]}")

    # Uninstall the failed release first
    helm uninstall "$RELEASE_NAME" -n "$NAMESPACE" 2>/dev/null || true
    sleep 2

    if "${HELM_CMD_NOWAIT[@]}" 2>&1; then
        info "Chart deployed (pods may not be fully ready — expected for apps needing backends)"
        # Give pods a moment to create
        sleep 10
    else
        fail "Chart deployment failed"
        exit 1
    fi
fi

# Show what got deployed
echo ""
info "Deployed resources:"
kubectl get all -n "$NAMESPACE" -l "app.kubernetes.io/instance=${RELEASE_NAME}" 2>/dev/null || \
    kubectl get all -n "$NAMESPACE" 2>/dev/null | head -20
echo ""

# Check for network policies
info "Network policies:"
kubectl get networkpolicy -n "$NAMESPACE" 2>/dev/null || true
kubectl get ciliumnetworkpolicy -n "$NAMESPACE" 2>/dev/null || true

# Debug: show full netpol spec for this release
info "NetworkPolicy YAML (for debugging):"
kubectl get networkpolicy -n "$NAMESPACE" -l "app.kubernetes.io/instance=${RELEASE_NAME}" -o yaml 2>/dev/null | head -60 || true

# ── Phase 2: Smoke test — verify services respond ────────────
section "Phase 2: Smoke Test"

SERVICE_COUNT=$(yq ".charts.\"${CHART_NAME}\".services | length // 0" "$REGISTRY" 2>/dev/null || echo 0)

if [[ "$SERVICE_COUNT" -gt 0 ]]; then
    for i in $(seq 0 $((SERVICE_COUNT - 1))); do
        SVC_PORT=$(yq ".charts.\"${CHART_NAME}\".services[$i].port" "$REGISTRY")
        SVC_NAME="${RELEASE_NAME}"

        TESTS_RUN=$((TESTS_RUN + 1))
        info "Smoke test: ${SVC_NAME}:${SVC_PORT} in ${NAMESPACE}"

        # Create a test pod and try to reach the service
        if kubectl run "smoke-test-${i}" \
            --image="$TEST_IMAGE" \
            --restart=Never \
            --rm -i \
            --namespace "$NAMESPACE" \
            --timeout="${CONNECT_TIMEOUT}s" \
            -- wget -qO- --timeout="$CONNECT_TIMEOUT" "http://${SVC_NAME}:${SVC_PORT}/" 2>/dev/null; then
            pass "Service ${SVC_NAME}:${SVC_PORT} is reachable"
        else
            # Service might return non-200 but still be "up" (e.g., 404, 500)
            # Try with just a TCP check
            if kubectl run "smoke-tcp-${i}" \
                --image="$TEST_IMAGE" \
                --restart=Never \
                --rm -i \
                --namespace "$NAMESPACE" \
                --timeout="${CONNECT_TIMEOUT}s" \
                -- sh -c "echo | nc -w $CONNECT_TIMEOUT ${SVC_NAME} ${SVC_PORT} 2>/dev/null && echo 'TCP_OK'" 2>/dev/null | grep -q "TCP_OK"; then
                pass "Service ${SVC_NAME}:${SVC_PORT} is reachable (TCP)"
            else
                warn "Service ${SVC_NAME}:${SVC_PORT} not responding (pod may not be ready — expected for apps needing backends)"
            fi
        fi
    done
else
    info "No services defined in registry — skipping smoke test"
fi

# ── Phase 3: Ingress connectivity tests ──────────────────────
section "Phase 3: Ingress Tests"

HAS_INGRESS_TESTS=$(yq ".charts.\"${CHART_NAME}\".ingress // null" "$REGISTRY" 2>/dev/null)

if [[ "$HAS_INGRESS_TESTS" != "null" && -n "$HAS_INGRESS_TESTS" ]]; then

    # Helper: get the first service port for this chart
    TARGET_PORT=$(yq ".charts.\"${CHART_NAME}\".services[0].port // 80" "$REGISTRY")
    TARGET_SVC="${RELEASE_NAME}"

    # ── Allowed ingress ───────────────────────────────────────
    ALLOWED_COUNT=$(yq ".charts.\"${CHART_NAME}\".ingress.allowed | length // 0" "$REGISTRY" 2>/dev/null || echo 0)

    for i in $(seq 0 $((ALLOWED_COUNT - 1))); do
        TESTS_RUN=$((TESTS_RUN + 1))
        PORT=$(yq ".charts.\"${CHART_NAME}\".ingress.allowed[$i].port" "$REGISTRY")
        SRC_NS=$(yq ".charts.\"${CHART_NAME}\".ingress.allowed[$i].source_namespace // \"${NAMESPACE}\"" "$REGISTRY")

        # Build label args for the test pod
        LABEL_ARGS=""
        while IFS='=' read -r lkey lval; do
            [[ -z "$lkey" ]] && continue
            LABEL_ARGS="${LABEL_ARGS}${lkey}=${lval},"
        done < <(yq -r ".charts.\"${CHART_NAME}\".ingress.allowed[$i].labels | to_entries[] | .key + \"=\" + .value" "$REGISTRY" 2>/dev/null)
        LABEL_ARGS="${LABEL_ARGS%,}"  # trim trailing comma

        LABEL_DESC=$(echo "$LABEL_ARGS" | tr ',' ' ')
        info "Ingress ALLOWED test: pod(${LABEL_DESC}) in ns(${SRC_NS}) → ${TARGET_SVC}:${PORT}"

        # Create source namespace if different
        if [[ "$SRC_NS" != "$NAMESPACE" ]]; then
            kubectl create namespace "$SRC_NS" --dry-run=client -o yaml | kubectl apply -f -
        fi

        # Retry loop: slow-starting apps (e.g., databases) may not be
        # accepting connections immediately after deploy. Retry up to
        # ALLOWED_RETRIES times with a delay between attempts.
        ALLOWED_RETRIES=5
        RETRY_DELAY=15  # seconds between retries
        INGRESS_PASSED=false

        for attempt in $(seq 1 "$ALLOWED_RETRIES"); do
            POD_NAME="ingress-allow-${i}-a${attempt}"

            # Use wget to test connectivity. We capture ALL output (stdout +
            # stderr) and check for signs of network-level blocking.
            #
            # A successful TCP connection can look different depending on the
            # service:  HTTP services return HTML, non-HTTP services (postgres)
            # cause "error getting response".  Both mean the netpol ALLOWED it.
            #
            # A blocked connection shows "Operation not permitted" (Cilium DROP)
            # or "Connection refused" / "can't connect" (port not open yet).
            WGET_OUTPUT=$(kubectl run "$POD_NAME" \
                --image="$TEST_IMAGE" \
                --restart=Never \
                --rm -i \
                --namespace "$SRC_NS" \
                --labels="$LABEL_ARGS" \
                --timeout="$((CONNECT_TIMEOUT + 5))s" \
                -- wget -qO- --timeout="$CONNECT_TIMEOUT" \
                   "http://${TARGET_SVC}.${NAMESPACE}.svc.cluster.local:${PORT}/" 2>&1 || true)

            if echo "$WGET_OUTPUT" | grep -qi 'Operation not permitted\|Connection refused\|can'\''t connect\|Network is unreachable\|timed out'; then
                # Network policy blocked the connection or service not ready
                :
            else
                # No blocking indicators → TCP connection succeeded
                pass "Ingress ALLOWED: ${LABEL_DESC} → ${TARGET_SVC}:${PORT}"
                INGRESS_PASSED=true
                break
            fi

            if [[ "$attempt" -lt "$ALLOWED_RETRIES" ]]; then
                warn "Attempt ${attempt}/${ALLOWED_RETRIES} failed — retrying in ${RETRY_DELAY}s..."
                info "  wget output: ${WGET_OUTPUT}"
                sleep "$RETRY_DELAY"
            fi
        done

        if [[ "$INGRESS_PASSED" != "true" ]]; then
            fail "Ingress ALLOWED: ${LABEL_DESC} → ${TARGET_SVC}:${PORT} — connection failed after ${ALLOWED_RETRIES} attempts (expected success)"
        fi
    done

    # ── Denied ingress ────────────────────────────────────────
    DENIED_COUNT=$(yq ".charts.\"${CHART_NAME}\".ingress.denied | length // 0" "$REGISTRY" 2>/dev/null || echo 0)

    for i in $(seq 0 $((DENIED_COUNT - 1))); do
        TESTS_RUN=$((TESTS_RUN + 1))
        PORT=$(yq ".charts.\"${CHART_NAME}\".ingress.denied[$i].port" "$REGISTRY")
        SRC_NS=$(yq ".charts.\"${CHART_NAME}\".ingress.denied[$i].source_namespace // \"${NAMESPACE}\"" "$REGISTRY")

        LABEL_ARGS=""
        while IFS='=' read -r lkey lval; do
            [[ -z "$lkey" ]] && continue
            LABEL_ARGS="${LABEL_ARGS}${lkey}=${lval},"
        done < <(yq -r ".charts.\"${CHART_NAME}\".ingress.denied[$i].labels | to_entries[] | .key + \"=\" + .value" "$REGISTRY" 2>/dev/null)
        LABEL_ARGS="${LABEL_ARGS%,}"

        LABEL_DESC="${LABEL_ARGS:-<unlabeled>}"
        info "Ingress DENIED test: pod(${LABEL_DESC}) in ns(${SRC_NS}) → ${TARGET_SVC}:${PORT}"

        POD_NAME="ingress-deny-${i}"

        # Create source namespace if different
        if [[ "$SRC_NS" != "$NAMESPACE" ]]; then
            kubectl create namespace "$SRC_NS" --dry-run=client -o yaml | kubectl apply -f -
        fi

        # For denied tests, we expect the connection to FAIL (timeout/drop).
        # Use a TCP check (sh -c with /dev/tcp or nc) so non-HTTP services
        # like databases are tested correctly. wget-to-non-HTTP would give
        # a false positive (exits non-zero even when TCP succeeds).
        if kubectl run "$POD_NAME" \
            --image="$TEST_IMAGE" \
            --restart=Never \
            --rm -i \
            --namespace "$SRC_NS" \
            ${LABEL_ARGS:+--labels="$LABEL_ARGS"} \
            --timeout="$((BLOCK_TIMEOUT + 10))s" \
            -- sh -c "echo | nc -w $BLOCK_TIMEOUT ${TARGET_SVC}.${NAMESPACE}.svc.cluster.local ${PORT} 2>/dev/null && echo 'CONNECTED'" 2>/dev/null | grep -q "CONNECTED"; then
            fail "Ingress DENIED: ${LABEL_DESC} → ${TARGET_SVC}:${PORT} — connection succeeded (expected block)"
        else
            pass "Ingress DENIED: ${LABEL_DESC} → ${TARGET_SVC}:${PORT} — correctly blocked"
        fi
    done
else
    info "No ingress tests defined — skipping"
fi

# ── Phase 4: Egress connectivity tests ───────────────────────
section "Phase 4: Egress Tests"

HAS_EGRESS_TESTS=$(yq ".charts.\"${CHART_NAME}\".egress // null" "$REGISTRY" 2>/dev/null)

if [[ "$HAS_EGRESS_TESTS" != "null" && -n "$HAS_EGRESS_TESTS" ]]; then

    # Find the chart's pod to exec into
    CHART_POD=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/instance=${RELEASE_NAME}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

    if [[ -z "$CHART_POD" ]]; then
        warn "No pod found for release '${RELEASE_NAME}' — skipping egress tests"
    else
        info "Using pod: ${CHART_POD}"

        # ── Allowed egress ────────────────────────────────────
        ALLOWED_COUNT=$(yq ".charts.\"${CHART_NAME}\".egress.allowed | length // 0" "$REGISTRY" 2>/dev/null || echo 0)

        for i in $(seq 0 $((ALLOWED_COUNT - 1))); do
            TESTS_RUN=$((TESTS_RUN + 1))
            TARGET=$(yq ".charts.\"${CHART_NAME}\".egress.allowed[$i].target" "$REGISTRY")
            PORT=$(yq ".charts.\"${CHART_NAME}\".egress.allowed[$i].port" "$REGISTRY")

            info "Egress ALLOWED test: ${CHART_POD} → ${TARGET}:${PORT}"

            EGRESS_PASSED=false

            # Method 1: exec into the chart pod with nc
            if kubectl exec -n "$NAMESPACE" "$CHART_POD" -- \
                sh -c "nc -z -w $CONNECT_TIMEOUT $TARGET $PORT 2>/dev/null && echo EGRESS_OK" 2>/dev/null | grep -q "EGRESS_OK"; then
                EGRESS_PASSED=true
            fi

            # Method 2: exec into the chart pod with bash /dev/tcp
            if [[ "$EGRESS_PASSED" != "true" ]]; then
                if kubectl exec -n "$NAMESPACE" "$CHART_POD" -- \
                    bash -c "echo > /dev/tcp/$TARGET/$PORT && echo EGRESS_OK" 2>/dev/null | grep -q "EGRESS_OK"; then
                    EGRESS_PASSED=true
                fi
            fi

            # Method 3: spawn a test pod with the chart's selector labels.
            # The netpol applies by label, so this pod is subject to the same
            # egress rules. Useful when the real image lacks nc/bash.
            if [[ "$EGRESS_PASSED" != "true" ]]; then
                info "  exec failed (image may lack nc/bash) — falling back to labeled test pod"
                POD_LABELS="app.kubernetes.io/name=${CHART_NAME},app.kubernetes.io/instance=${RELEASE_NAME}"
                EGRESS_OUTPUT=$(kubectl run "egress-allow-${i}" \
                    --image="$TEST_IMAGE" \
                    --restart=Never \
                    --rm -i \
                    --namespace "$NAMESPACE" \
                    --labels="$POD_LABELS" \
                    --timeout="$((CONNECT_TIMEOUT + 10))s" \
                    -- sh -c "nc -z -w $CONNECT_TIMEOUT $TARGET $PORT 2>/dev/null && echo EGRESS_OK" 2>&1 || true)
                if echo "$EGRESS_OUTPUT" | grep -q "EGRESS_OK"; then
                    EGRESS_PASSED=true
                fi
            fi

            if [[ "$EGRESS_PASSED" == "true" ]]; then
                pass "Egress ALLOWED: → ${TARGET}:${PORT}"
            else
                fail "Egress ALLOWED: → ${TARGET}:${PORT} — connection failed (expected success)"
            fi
        done

        # ── Denied egress ─────────────────────────────────────
        DENIED_COUNT=$(yq ".charts.\"${CHART_NAME}\".egress.denied | length // 0" "$REGISTRY" 2>/dev/null || echo 0)

        for i in $(seq 0 $((DENIED_COUNT - 1))); do
            TESTS_RUN=$((TESTS_RUN + 1))
            TARGET=$(yq ".charts.\"${CHART_NAME}\".egress.denied[$i].target" "$REGISTRY")
            PORT=$(yq ".charts.\"${CHART_NAME}\".egress.denied[$i].port" "$REGISTRY")

            # "external" is a special keyword meaning internet
            if [[ "$TARGET" == "external" ]]; then
                TARGET="1.1.1.1"
            fi

            info "Egress DENIED test: ${CHART_POD} → ${TARGET}:${PORT}"

            if kubectl exec -n "$NAMESPACE" "$CHART_POD" -- \
                sh -c "timeout $BLOCK_TIMEOUT sh -c 'nc -z $TARGET $PORT' 2>/dev/null && echo EGRESS_OK" 2>/dev/null | grep -q "EGRESS_OK"; then
                fail "Egress DENIED: → ${TARGET}:${PORT} — connection succeeded (expected block)"
            else
                pass "Egress DENIED: → ${TARGET}:${PORT} — correctly blocked"
            fi
        done
    fi
else
    info "No egress tests defined — skipping"
fi

# ── Summary ───────────────────────────────────────────────────
section "Summary: ${CHART_NAME}"
echo ""
echo "  Tests run:  ${TESTS_RUN}"
echo "  Failures:   ${FAILURES}"
echo ""

if [[ "$FAILURES" -gt 0 ]]; then
    echo -e "${RED}  ❌ ${FAILURES} test(s) FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}  ✅ All tests passed${NC}"
    exit 0
fi
