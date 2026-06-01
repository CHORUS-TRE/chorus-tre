"""Shared constants for the chart e2e runner."""

TEST_IMAGE = "busybox:1.36.1@sha256:73aaf090f3d85aa34ee199857f03fa3a95c8ede2ffd4cc2cdb5b94e566b11662"
CONNECT_TIMEOUT = 5
SMOKE_RETRY_MAX_WAIT = 30
SMOKE_RETRY_INTERVAL = 5

RED = "\033[0;31m"
GREEN = "\033[0;32m"
YELLOW = "\033[0;33m"
CYAN = "\033[0;36m"
NC = "\033[0m"
