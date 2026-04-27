#!/usr/bin/env bash
# ci/run-chart-e2e.sh — Generic chart e2e test runner
#
# Deploys a chart into a Kind cluster and runs service reachability checks
# based on the central test registry (ci/chart-tests.yaml).
#
# Usage: ./ci/run-chart-e2e.sh <chart_path> <chart_name>
#   e.g.: ./ci/run-chart-e2e.sh charts/i2b2-wildfly i2b2-wildfly
#
# Requires: helm, kubectl, yq (v4+)
# Expects: a running Kind cluster

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REGISTRY="${REPO_ROOT}/ci/chart-tests.yaml"
TEST_IMAGE="busybox:1.36"
CONNECT_TIMEOUT=5  # seconds for positive tests

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

service_name_for_chart() {
    local chart="$1"
    local release="$2"
    local override
    override=$(yq -r ".charts.\"${chart}\".fullname_override // \"\"" "$REGISTRY" 2>/dev/null)
    if [[ -n "$override" && "$override" != "null" ]]; then
        echo "$override"
    else
        echo "$release"
    fi
}

namespace_for_chart() {
    local chart="$1"
    yq -r ".charts.\"${chart}\".namespace // .defaults.namespace // \"test\"" "$REGISTRY" 2>/dev/null
}

service_port_for_chart() {
    local chart="$1"
    local port
    port=$(yq -r ".charts.\"${chart}\".services[0].port // .charts.\"${chart}\".health_check.port // \"\"" "$REGISTRY" 2>/dev/null)
    if [[ -z "$port" || "$port" == "null" ]]; then
        echo ""
    else
        echo "$port"
    fi
}

set_arg_lines_for_chart() {
    local chart="$1"
    local dep_key dep_chart dep_attr dep_path dep_release dep_service_name dep_service_port dep_value

    yq -r ".charts.\"${chart}\".values // {} | to_entries[]? | .key + \"=\" + (.value | tostring)" "$REGISTRY" 2>/dev/null || true

    while IFS=$'\t' read -r dep_key dep_chart dep_attr dep_path; do
        [[ -z "$dep_key" || -z "$dep_chart" || "$dep_chart" == "null" ]] && continue

        dep_release="e2e-${dep_chart}"
        case "$dep_attr" in
            ""|"serviceName")
                dep_value=$(service_name_for_chart "$dep_chart" "$dep_release")
                ;;
            "releaseName")
                dep_value="$dep_release"
                ;;
            "namespace")
                dep_value=$(namespace_for_chart "$dep_chart")
                ;;
            "servicePort")
                dep_value=$(service_port_for_chart "$dep_chart")
                ;;
            "httpBaseUrl"|"httpUrl")
                dep_service_name=$(service_name_for_chart "$dep_chart" "$dep_release")
                dep_service_port=$(service_port_for_chart "$dep_chart")
                if [[ -z "$dep_service_port" ]]; then
                    warn "No service port found for dependency chart '${dep_chart}' referenced by ${chart}.${dep_key} — skipping"
                    continue
                fi
                dep_value="http://${dep_service_name}:${dep_service_port}"
                if [[ "$dep_attr" == "httpUrl" ]]; then
                    dep_value="${dep_value}${dep_path}"
                fi
                ;;
            *)
                warn "Unknown dependency_values attribute '${dep_attr}' for ${chart}.${dep_key} — skipping"
                continue
                ;;
        esac

        echo "${dep_key}=${dep_value}"
    done < <(yq -r ".charts.\"${chart}\".dependency_values // {} | to_entries[]? | [.key, .value.chart, (.value.attribute // \"serviceName\"), (.value.path // \"\")] | @tsv" "$REGISTRY" 2>/dev/null || true)
}

run_probe_command() {
    local pod_prefix="$1"
    local probe_namespace="$2"
    local probe_labels="$3"
    local timeout_secs="$4"
    shift 4

    kubectl create namespace "$probe_namespace" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

    local pod_name="${pod_prefix}-${RANDOM}"
    local probe_cmd=(kubectl run "$pod_name"
        --image="$TEST_IMAGE"
        --restart=Never
        --rm -i
        --namespace "$probe_namespace"
        --timeout="${timeout_secs}s"
    )

    if [[ -n "$probe_labels" ]]; then
        probe_cmd+=(--labels "$probe_labels")
    fi

    probe_cmd+=(-- "$@")
    "${probe_cmd[@]}"
}

NAMESPACE=$(chart_config "namespace" "$(defaults_config "namespace" "test")")
TIMEOUT=$(chart_config "timeout" "$(defaults_config "timeout" "120")")
SKIP_DEPLOY=$(chart_config "skip_deploy" "false")
VALUES_FILE=$(chart_config "values_file" "")
RELEASE_NAME="e2e-${CHART_NAME}"
FULLNAME_OVERRIDE=$(chart_config "fullname_override" "")
SERVICE_NAME=$(service_name_for_chart "$CHART_NAME" "$RELEASE_NAME")
PROBE_NAMESPACE=$(chart_config "probe.namespace" "$NAMESPACE")
PROBE_LABELS=$(yq -r ".charts.\"${CHART_NAME}\".probe.labels // {} | to_entries | map(.key + \"=\" + (.value | tostring)) | join(\",\")" "$REGISTRY" 2>/dev/null || true)
[[ "$PROBE_LABELS" == "null" ]] && PROBE_LABELS=""

section "Chart E2E: ${CHART_NAME}"
echo "  Chart path:   ${CHART_PATH}"
echo "  Namespace:    ${NAMESPACE}"
echo "  Release:      ${RELEASE_NAME}"
echo "  Service:      ${SERVICE_NAME}"
echo "  Probe ns:     ${PROBE_NAMESPACE}"
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

# ── Phase 0b: Deploy dependency charts (depends_on) ──────────
# Resolves transitive dependencies via BFS, deploys leaves first.

resolve_deps() {
    # Flatten the dependency tree for a given chart into deployment order.
    # Output: newline-separated list of chart names, leaves first.
    local chart="$1"
    local resolved=""
    local queue="$chart"

    # BFS to collect all deps
    while [[ -n "$queue" ]]; do
        local current="${queue%% *}"
        queue="${queue#* }"
        [[ "$queue" == "$current" ]] && queue=""

        local count
        count=$(yq ".charts.\"${current}\".depends_on | length // 0" "$REGISTRY" 2>/dev/null || echo 0)
        for j in $(seq 0 $((count - 1))); do
            local dep
            dep=$(yq -r ".charts.\"${current}\".depends_on[$j]" "$REGISTRY")
            # Add to resolved (will dedupe later) and queue for further resolution
            resolved="${resolved} ${dep}"
            queue="${queue} ${dep}"
        done
    done

    # Reverse + dedupe: dependencies of dependencies come first
    echo "$resolved" | tr ' ' '\n' | tac | awk '!seen[$0]++ && NF' 
}

DEP_LIST=$(resolve_deps "$CHART_NAME")

if [[ -n "$DEP_LIST" ]]; then
    section "Phase 0b: Deploy Dependencies"
    while IFS= read -r DEP_NAME; do
        [[ -z "$DEP_NAME" ]] && continue
        DEP_RELEASE="e2e-${DEP_NAME}"
        DEP_NS=$(yq ".charts.\"${DEP_NAME}\".namespace // \"${NAMESPACE}\"" "$REGISTRY")
        DEP_TIMEOUT=$(yq ".charts.\"${DEP_NAME}\".timeout // 120" "$REGISTRY")
        DEP_VALUES_FILE=$(yq ".charts.\"${DEP_NAME}\".values_file // \"\"" "$REGISTRY")
        DEP_FULLNAME_OVERRIDE=$(yq -r ".charts.\"${DEP_NAME}\".fullname_override // \"\"" "$REGISTRY" 2>/dev/null)
        DEP_SERVICE_NAME=$(service_name_for_chart "$DEP_NAME" "$DEP_RELEASE")

        info "Dependency: ${DEP_NAME} (release ${DEP_RELEASE}, service ${DEP_SERVICE_NAME}, ns ${DEP_NS})"

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
            --wait --timeout "${DEP_TIMEOUT}s"
        )
        if [[ -n "$DEP_VALUES_FILE" && "$DEP_VALUES_FILE" != "null" ]]; then
            DEP_HELM_CMD+=(--values "${REPO_ROOT}/${DEP_VALUES_FILE}")
        fi
        while IFS='=' read -r key val; do
            [[ -z "$key" ]] && continue
            DEP_HELM_CMD+=(--set "$key=$val")
        done < <(set_arg_lines_for_chart "$DEP_NAME")
        if [[ -n "$DEP_FULLNAME_OVERRIDE" && "$DEP_FULLNAME_OVERRIDE" != "null" ]]; then
            DEP_HELM_CMD+=(--set "fullnameOverride=${DEP_FULLNAME_OVERRIDE}")
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
    done <<< "$DEP_LIST"
fi

# ── Phase 1: Deploy chart ─────────────────────────────────────
section "Phase 1: Deploy"

# Build --set flags from registry
HELM_SET_ARGS=()
while IFS='=' read -r key val; do
    [[ -z "$key" ]] && continue
    HELM_SET_ARGS+=(--set "$key=$val")
done < <(set_arg_lines_for_chart "$CHART_NAME")

# Keep the chart's default naming unless a stable fullname override is configured.
if [[ -n "$FULLNAME_OVERRIDE" ]]; then
    HELM_SET_ARGS+=(--set "fullnameOverride=${FULLNAME_OVERRIDE}")
fi

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
    # Try without --wait so we can still run reachability and health checks.
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

# ── Phase 2: Smoke test — verify services respond ────────────
section "Phase 2: Smoke Test"

SERVICE_COUNT=$(yq ".charts.\"${CHART_NAME}\".services | length // 0" "$REGISTRY" 2>/dev/null || echo 0)

if [[ "$SERVICE_COUNT" -gt 0 ]]; then
    for i in $(seq 0 $((SERVICE_COUNT - 1))); do
        SVC_PORT=$(yq ".charts.\"${CHART_NAME}\".services[$i].port" "$REGISTRY")
        SVC_NAME="${SERVICE_NAME}"
        SVC_HOST="${SVC_NAME}.${NAMESPACE}.svc.cluster.local"
        SMOKE_PASSED=false

        TESTS_RUN=$((TESTS_RUN + 1))
        info "Smoke test: ${SVC_HOST}:${SVC_PORT} from ${PROBE_NAMESPACE}"
        if [[ -n "$PROBE_LABELS" ]]; then
            info "  probe labels: ${PROBE_LABELS}"
        fi

        if run_probe_command "smoke-test-${i}" "$PROBE_NAMESPACE" "$PROBE_LABELS" "$CONNECT_TIMEOUT" \
            wget -qO /dev/null --timeout="$CONNECT_TIMEOUT" "http://${SVC_HOST}:${SVC_PORT}/" 2>/dev/null; then
            pass "Service ${SVC_NAME}:${SVC_PORT} is reachable"
            SMOKE_PASSED=true
        else
            # Service might return non-200 but still be "up" (e.g., 404, 500)
            # Try with just a TCP check
            if run_probe_command "smoke-tcp-${i}" "$PROBE_NAMESPACE" "$PROBE_LABELS" "$CONNECT_TIMEOUT" \
                sh -c "echo | nc -w $CONNECT_TIMEOUT ${SVC_HOST} ${SVC_PORT} 2>/dev/null && echo 'TCP_OK'" 2>/dev/null | grep -q "TCP_OK"; then
                pass "Service ${SVC_NAME}:${SVC_PORT} is reachable (TCP)"
                SMOKE_PASSED=true
            fi
        fi

        if [[ "$SMOKE_PASSED" != "true" ]]; then
            fail "Service ${SVC_NAME}:${SVC_PORT} is not reachable"
        fi
    done
else
    info "No services defined in registry — skipping smoke test"
fi

# ── Phase 3: Application health check ─────────────────────────
# Verifies the application is healthy (e.g. wildfly returns 200
# only when all DB datasources are connected).
section "Phase 3: Health Check"

HEALTH_PORT=$(yq ".charts.\"${CHART_NAME}\".health_check.port // \"\"" "$REGISTRY" 2>/dev/null)
HEALTH_PROTO=$(yq ".charts.\"${CHART_NAME}\".health_check.protocol // \"http\"" "$REGISTRY" 2>/dev/null)

if [[ -n "$HEALTH_PORT" && "$HEALTH_PORT" != "null" ]]; then
    TESTS_RUN=$((TESTS_RUN + 1))

    HC_TARGET="${SERVICE_NAME}.${NAMESPACE}.svc.cluster.local"

    if [[ "$HEALTH_PROTO" == "pg" ]]; then
        # ── PostgreSQL health check ───────────────────────────
        # kubectl exec into the postgres container (pg_isready + psql).
        # We exec rather than spawn a separate pod because the sidecar
        # may crash-loop, leaving the Service with no endpoints.
        PG_USER=$(yq ".charts.\"${CHART_NAME}\".health_check.pg_user // \"postgres\"" "$REGISTRY" 2>/dev/null)
        PG_DB=$(yq ".charts.\"${CHART_NAME}\".health_check.pg_db // \"postgres\"" "$REGISTRY" 2>/dev/null)
        PG_PASS=$(yq ".charts.\"${CHART_NAME}\".health_check.pg_password // \"\"" "$REGISTRY" 2>/dev/null)
        PG_QUERY=$(yq ".charts.\"${CHART_NAME}\".health_check.query // \"SELECT 1\"" "$REGISTRY" 2>/dev/null)
        [[ "$PG_PASS" == "null" ]] && PG_PASS=""

        PG_WAIT=180  # max seconds to wait for pg_isready

        info "Health check (PG): ${RELEASE_NAME}:${HEALTH_PORT}"
        info "  user=${PG_USER}, db=${PG_DB}, query=${PG_QUERY}"
        info "  pg_isready wait: up to ${PG_WAIT}s (via kubectl exec)"

        # Find the postgres pod
        PG_POD=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=${CHART_NAME}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
        if [[ -z "$PG_POD" ]]; then
            fail "Health check (PG): no pod found for ${CHART_NAME} in ${NAMESPACE}"
        else
            info "Pod: ${PG_POD}"
            kubectl get pod "$PG_POD" -n "$NAMESPACE" -o wide 2>&1 | while IFS= read -r line; do echo "    $line"; done

            # Step 1: Wait for pg_isready (retry loop via exec)
            info "Step 1: pg_isready (waiting up to ${PG_WAIT}s)..."
            ELAPSED=0
            PG_READY=false
            while [[ $ELAPSED -lt $PG_WAIT ]]; do
                PG_ISREADY_OUT=$(kubectl exec "$PG_POD" -n "$NAMESPACE" -c "${CHART_NAME}" -- \
                    pg_isready -h 127.0.0.1 -p "${HEALTH_PORT}" -U "${PG_USER}" -d "${PG_DB}" 2>&1 || true)
                PG_RC=$?
                info "  [${ELAPSED}s] ${PG_ISREADY_OUT} (exit ${PG_RC})"
                if echo "$PG_ISREADY_OUT" | grep -q "accepting connections"; then
                    PG_READY=true
                    break
                fi
                sleep 5
                ELAPSED=$((ELAPSED + 5))
            done

            if [[ "$PG_READY" != "true" ]]; then
                fail "Health check (PG): pg_isready gave up after ${ELAPSED}s"
            else
                # Step 2: Run actual SQL query
                info "Step 2: Running SQL query..."

                # Build env prefix for PGPASSWORD
                PG_EXEC_CMD="psql -h 127.0.0.1 -p ${HEALTH_PORT} -U ${PG_USER} -d ${PG_DB} -c \"${PG_QUERY}\""
                if [[ -n "$PG_PASS" ]]; then
                    PG_EXEC_CMD="PGPASSWORD=${PG_PASS} ${PG_EXEC_CMD}"
                fi

                QUERY_OUTPUT=$(kubectl exec "$PG_POD" -n "$NAMESPACE" -c "${CHART_NAME}" -- \
                    sh -c "$PG_EXEC_CMD" 2>&1) && QUERY_RC=0 || QUERY_RC=$?

                # Display query output
                echo "$QUERY_OUTPUT" | while IFS= read -r line; do echo "    $line"; done

                if [[ $QUERY_RC -eq 0 ]] && ! echo "$QUERY_OUTPUT" | grep -qi "ERROR\|FATAL\|does not exist"; then
                    pass "Health check (PG): ${RELEASE_NAME}:${HEALTH_PORT} — pg_isready OK + query succeeded"
                else
                    fail "Health check (PG): ${RELEASE_NAME}:${HEALTH_PORT} — SQL query failed (exit ${QUERY_RC})"
                fi
            fi
        fi
    elif [[ "$HEALTH_PROTO" == "mariadb" ]]; then
        # ── MariaDB health check ──────────────────────────────
        # kubectl exec into the mariadb container (mysqladmin ping + mysql).
        # Same exec approach as PG to avoid Service endpoint issues.
        MDB_USER=$(yq ".charts.\"${CHART_NAME}\".health_check.mariadb_user // \"root\"" "$REGISTRY" 2>/dev/null)
        MDB_DB=$(yq ".charts.\"${CHART_NAME}\".health_check.mariadb_db // \"mysql\"" "$REGISTRY" 2>/dev/null)
        MDB_PASS=$(yq ".charts.\"${CHART_NAME}\".health_check.mariadb_password // \"\"" "$REGISTRY" 2>/dev/null)
        MDB_QUERY=$(yq ".charts.\"${CHART_NAME}\".health_check.query // \"SELECT 1\"" "$REGISTRY" 2>/dev/null)
        [[ "$MDB_PASS" == "null" ]] && MDB_PASS=""

        MDB_WAIT=180  # max seconds to wait for mysqladmin ping

        info "Health check (MariaDB): ${RELEASE_NAME}:${HEALTH_PORT}"
        info "  user=${MDB_USER}, db=${MDB_DB}, query=${MDB_QUERY}"
        info "  mysqladmin ping wait: up to ${MDB_WAIT}s (via kubectl exec)"

        # Find the mariadb pod — bitnami subchart labels use app.kubernetes.io/name=mariadb
        MDB_POD=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=mariadb" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
        if [[ -z "$MDB_POD" ]]; then
            fail "Health check (MariaDB): no pod found for mariadb in ${NAMESPACE}"
        else
            info "Pod: ${MDB_POD}"
            kubectl get pod "$MDB_POD" -n "$NAMESPACE" -o wide 2>&1 | while IFS= read -r line; do echo "    $line"; done

            # Step 1: Wait for mysqladmin ping (retry loop via exec)
            info "Step 1: mysqladmin ping (waiting up to ${MDB_WAIT}s)..."
            ELAPSED=0
            MDB_READY=false
            MDB_PASS_FLAG=""
            if [[ -n "$MDB_PASS" ]]; then
                MDB_PASS_FLAG="-p${MDB_PASS}"
            fi
            while [[ $ELAPSED -lt $MDB_WAIT ]]; do
                PING_OUT=$(kubectl exec "$MDB_POD" -n "$NAMESPACE" -c mariadb -- \
                    mysqladmin ping -h 127.0.0.1 -P "${HEALTH_PORT}" -u "${MDB_USER}" ${MDB_PASS_FLAG} 2>&1 || true)
                info "  [${ELAPSED}s] ${PING_OUT}"
                if echo "$PING_OUT" | grep -qi "alive"; then
                    MDB_READY=true
                    break
                fi
                sleep 5
                ELAPSED=$((ELAPSED + 5))
            done

            if [[ "$MDB_READY" != "true" ]]; then
                fail "Health check (MariaDB): mysqladmin ping gave up after ${ELAPSED}s"
            else
                # Step 2: Run actual SQL query
                info "Step 2: Running SQL query..."

                MDB_EXEC_CMD="mysql -h 127.0.0.1 -P ${HEALTH_PORT} -u ${MDB_USER} ${MDB_PASS_FLAG} -D ${MDB_DB} -e \"${MDB_QUERY}\""

                QUERY_OUTPUT=$(kubectl exec "$MDB_POD" -n "$NAMESPACE" -c mariadb -- \
                    sh -c "$MDB_EXEC_CMD" 2>&1) && QUERY_RC=0 || QUERY_RC=$?

                # Display query output
                echo "$QUERY_OUTPUT" | while IFS= read -r line; do echo "    $line"; done

                if [[ $QUERY_RC -eq 0 ]] && ! echo "$QUERY_OUTPUT" | grep -qi "ERROR"; then
                    pass "Health check (MariaDB): ${RELEASE_NAME}:${HEALTH_PORT} — mysqladmin ping OK + query succeeded"
                else
                    fail "Health check (MariaDB): ${RELEASE_NAME}:${HEALTH_PORT} — SQL query failed (exit ${QUERY_RC})"
                fi
            fi
        fi
    else
        # ── HTTP health check ─────────────────────────────────
        HEALTH_PATH=$(yq ".charts.\"${CHART_NAME}\".health_check.path // \"/\"" "$REGISTRY" 2>/dev/null)
        HEALTH_STATUS=$(yq ".charts.\"${CHART_NAME}\".health_check.expect_status // 200" "$REGISTRY" 2>/dev/null)
        HEALTH_CONTENT_TYPE_REGEX=$(yq -r ".charts.\"${CHART_NAME}\".health_check.expect_content_type_regex // \"\"" "$REGISTRY" 2>/dev/null)
        HEALTH_BODY_MUST_MATCH=$(yq -r ".charts.\"${CHART_NAME}\".health_check.body_must_match // \"\"" "$REGISTRY" 2>/dev/null)
        HEALTH_BODY_MUST_NOT_MATCH=$(yq -r ".charts.\"${CHART_NAME}\".health_check.body_must_not_match // \"\"" "$REGISTRY" 2>/dev/null)
        HEALTH_URL="http://${HC_TARGET}:${HEALTH_PORT}${HEALTH_PATH}"

        info "Health check (HTTP): ${HEALTH_URL} (expect ${HEALTH_STATUS})"
        info "  probe namespace: ${PROBE_NAMESPACE}"

        HEALTH_OUTPUT=$(
            run_probe_command "health-check" "$PROBE_NAMESPACE" "$PROBE_LABELS" "$((CONNECT_TIMEOUT + 10))" \
                sh -c 'health_url="$1"; connect_timeout="$2"; headers_file=$(mktemp); body_file=$(mktemp); wget -S -O "$body_file" --timeout="$connect_timeout" "$health_url" >/dev/null 2>"$headers_file"; wget_rc=$?; printf "__WGET_RC__:%s\n" "$wget_rc"; printf "__HEADERS_BEGIN__\n"; cat "$headers_file"; printf "\n__HEADERS_END__\n"; printf "__BODY_BEGIN__\n"; cat "$body_file"; printf "\n__BODY_END__\n"; rm -f "$headers_file" "$body_file"' sh "$HEALTH_URL" "$CONNECT_TIMEOUT" 2>&1 || true
        )

        HTTP_WGET_RC=$(echo "$HEALTH_OUTPUT" | sed -n 's/^__WGET_RC__://p' | tail -1)
        HTTP_HEADERS=$(echo "$HEALTH_OUTPUT" | awk '/__HEADERS_BEGIN__/{flag=1; next} /__HEADERS_END__/{flag=0} flag')
        HTTP_BODY=$(echo "$HEALTH_OUTPUT" | awk '/__BODY_BEGIN__/{flag=1; next} /__BODY_END__/{flag=0} flag')
        HTTP_LINE=$(echo "$HTTP_HEADERS" | grep -i 'HTTP/' | tail -1 || true)
        CONTENT_TYPE_LINE=$(echo "$HTTP_HEADERS" | grep -i '^ *Content-Type:' | tail -1 || true)

        if [[ -n "$HTTP_WGET_RC" && "$HTTP_WGET_RC" != "0" ]]; then
            fail "Health check (HTTP): wget failed for ${RELEASE_NAME}:${HEALTH_PORT}${HEALTH_PATH} (exit ${HTTP_WGET_RC})"
            info "  headers: $(echo "$HTTP_HEADERS" | tail -5 | tr '\n' ' ' | sed 's/  */ /g')"
        elif [[ -z "$HTTP_LINE" ]]; then
            fail "Health check (HTTP): no HTTP response from ${RELEASE_NAME}:${HEALTH_PORT}${HEALTH_PATH}"
            info "  output: $(echo "$HEALTH_OUTPUT" | tail -5)"
        elif ! echo "$HTTP_LINE" | grep -q "${HEALTH_STATUS}"; then
            fail "Health check (HTTP): expected HTTP ${HEALTH_STATUS}, got: ${HTTP_LINE}"
        elif [[ -n "$HEALTH_CONTENT_TYPE_REGEX" && "$HEALTH_CONTENT_TYPE_REGEX" != "null" ]] && ! echo "$CONTENT_TYPE_LINE" | grep -Eiq "$HEALTH_CONTENT_TYPE_REGEX"; then
            fail "Health check (HTTP): content type did not match ${HEALTH_CONTENT_TYPE_REGEX}"
            info "  content type: ${CONTENT_TYPE_LINE:-<missing>}"
        elif [[ -n "$HEALTH_BODY_MUST_MATCH" && "$HEALTH_BODY_MUST_MATCH" != "null" ]] && ! echo "$HTTP_BODY" | grep -Eiq "$HEALTH_BODY_MUST_MATCH"; then
            fail "Health check (HTTP): response body did not match required pattern ${HEALTH_BODY_MUST_MATCH}"
            info "  body preview: $(echo "$HTTP_BODY" | head -20 | tr '\n' ' ' | sed 's/  */ /g')"
        elif [[ -n "$HEALTH_BODY_MUST_NOT_MATCH" && "$HEALTH_BODY_MUST_NOT_MATCH" != "null" ]] && echo "$HTTP_BODY" | grep -Eiq "$HEALTH_BODY_MUST_NOT_MATCH"; then
            fail "Health check (HTTP): response body matched forbidden pattern ${HEALTH_BODY_MUST_NOT_MATCH}"
            info "  body preview: $(echo "$HTTP_BODY" | head -20 | tr '\n' ' ' | sed 's/  */ /g')"
        else
            pass "Health check (HTTP): ${RELEASE_NAME}:${HEALTH_PORT}${HEALTH_PATH} returned HTTP ${HEALTH_STATUS} with expected content"
        fi
    fi
else
    info "No health check defined — skipping"
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
