"""Shared constants for the chart e2e runner."""

TEST_IMAGE = "busybox:1.36.1@sha256:73aaf090f3d85aa34ee199857f03fa3a95c8ede2ffd4cc2cdb5b94e566b11662"

# Deny-assertion phase (netassert). The binary comes from the workflow tool
# bootstrap in CI; local runs need it on PATH.
NETASSERT_BINARY = "netassert"
NETASSERT_SCANNER_IMAGE = (
    "docker.io/controlplane/netassertv2-l4-client:v1.1.1"
    "@sha256:9b040bbe53cf0ffc6a9dd46570d463b0603aa90c69ad2d5f52836d2cea1464ff"
)
NETASSERT_DECOY_MANIFEST = "ci/test-manifests/netassert-decoy.yaml"
# A Cilium DROP consumes the full timeout — keep deny tests short and single-shot.
NETASSERT_DENY_TIMEOUT_SECONDS = 20
NETASSERT_DENY_ATTEMPTS = 1
CONNECT_TIMEOUT = 5
SMOKE_RETRY_MAX_WAIT = 30
SMOKE_RETRY_INTERVAL = 5

RED = "\033[0;31m"
GREEN = "\033[0;32m"
YELLOW = "\033[0;33m"
CYAN = "\033[0;36m"
NC = "\033[0m"
