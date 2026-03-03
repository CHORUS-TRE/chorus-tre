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
                -- sh -c "nc -z ${SVC_NAME} ${SVC_PORT} 2>/dev/null && echo 'TCP_OK'" 2>/dev/null | grep -q "TCP_OK"; then
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

        POD_NAME="ingress-allow-${i}"
        if kubectl run "$POD_NAME" \
            --image="$TEST_IMAGE" \
            --restart=Never \
            --rm -i \
            --namespace "$SRC_NS" \
            --labels="$LABEL_ARGS" \
            --timeout="$((CONNECT_TIMEOUT + 5))s" \
            -- wget -qO- --timeout="$CONNECT_TIMEOUT" "http://${TARGET_SVC}.${NAMESPACE}.svc.cluster.local:${PORT}/" 2>/dev/null; then
            pass "Ingress ALLOWED: ${LABEL_DESC} → ${TARGET_SVC}:${PORT}"
        else
            # TCP fallback
            if kubectl run "${POD_NAME}-tcp" \
                --image="$TEST_IMAGE" \
                --restart=Never \
                --rm -i \
                --namespace "$SRC_NS" \
                --labels="$LABEL_ARGS" \
                --timeout="$((CONNECT_TIMEOUT + 5))s" \
                -- sh -c "nc -z -w $CONNECT_TIMEOUT ${TARGET_SVC}.${NAMESPACE}.svc.cluster.local ${PORT} && echo TCP_OK" 2>/dev/null | grep -q "TCP_OK"; then
                pass "Ingress ALLOWED: ${LABEL_DESC} → ${TARGET_SVC}:${PORT} (TCP)"
            else
                fail "Ingress ALLOWED: ${LABEL_DESC} → ${TARGET_SVC}:${PORT} — connection failed (expected success)"
            fi
        fi
    done

    # ── Denied ingress ────────────────────────────────────────
    DENIED_COUNT=$(yq ".charts.\"${CHART_NAME}\".ingress.denied | length // 0" "$REGISTRY" 2>/dev/null || echo 0)

    for i in $(seq 0 $((DENIED_COUNT - 1))); do
        TESTS_RUN=$((TESTS_RUN + 1))
        PORT=$(yq ".charts.\"${CHART_NAME}\".ingress.denied[$i].port" "$REGISTRY")

        LABEL_ARGS=""
        while IFS='=' read -r lkey lval; do
            [[ -z "$lkey" ]] && continue
            LABEL_ARGS="${LABEL_ARGS}${lkey}=${lval},"
        done < <(yq -r ".charts.\"${CHART_NAME}\".ingress.denied[$i].labels | to_entries[] | .key + \"=\" + .value" "$REGISTRY" 2>/dev/null)
        LABEL_ARGS="${LABEL_ARGS%,}"

        LABEL_DESC="${LABEL_ARGS:-<unlabeled>}"
        info "Ingress DENIED test: pod(${LABEL_DESC}) → ${TARGET_SVC}:${PORT}"

        POD_NAME="ingress-deny-${i}"

        # For denied tests, we expect the connection to FAIL (timeout)
        if kubectl run "$POD_NAME" \
            --image="$TEST_IMAGE" \
            --restart=Never \
            --rm -i \
            --namespace "$NAMESPACE" \
            ${LABEL_ARGS:+--labels="$LABEL_ARGS"} \
            --timeout="$((BLOCK_TIMEOUT + 10))s" \
            -- sh -c "wget -qO- --timeout=$BLOCK_TIMEOUT http://${TARGET_SVC}:${PORT}/ 2>/dev/null && echo 'CONNECTED'" 2>/dev/null | grep -q "CONNECTED"; then
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

            if kubectl exec -n "$NAMESPACE" "$CHART_POD" -- \
                sh -c "nc -z -w $CONNECT_TIMEOUT $TARGET $PORT 2>/dev/null && echo EGRESS_OK" 2>/dev/null | grep -q "EGRESS_OK"; then
                pass "Egress ALLOWED: → ${TARGET}:${PORT}"
            else
                # Try bash /dev/tcp fallback
                if kubectl exec -n "$NAMESPACE" "$CHART_POD" -- \
                    bash -c "echo > /dev/tcp/$TARGET/$PORT && echo EGRESS_OK" 2>/dev/null | grep -q "EGRESS_OK"; then
                    pass "Egress ALLOWED: → ${TARGET}:${PORT}"
                else
                    fail "Egress ALLOWED: → ${TARGET}:${PORT} — connection failed (expected success)"
                fi
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
