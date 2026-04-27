"""Smoke and health checks for the chart e2e runner."""

from __future__ import annotations

import re
import time

from .constants import CONNECT_TIMEOUT
from .utils import extract_block, lines_preview, nested_get


class ChecksMixin:
    def run_smoke_tests(self) -> None:
        self.section("Phase 2: Smoke Test")
        services = self.chart_entry(self.chart_name).get("services") or []
        if not services:
            self.info("No services defined in registry — skipping smoke test")
            return

        for index, service in enumerate(services):
            svc_port = str((service or {}).get("port"))
            svc_name = self.service_name
            svc_host = f"{svc_name}.{self.namespace}.svc.cluster.local"
            smoke_passed = False

            self.tests_run += 1
            self.info(f"Smoke test: {svc_host}:{svc_port} from {self.probe_namespace}")
            if self.probe_labels:
                self.info(f"  probe labels: {self.probe_labels}")

            result = self.run_probe_command(
                f"smoke-test-{index}",
                self.probe_namespace,
                self.probe_labels,
                CONNECT_TIMEOUT,
                ["wget", "-qO", "/dev/null", f"--timeout={CONNECT_TIMEOUT}", f"http://{svc_host}:{svc_port}/"],
                suppress_stderr=True,
            )
            if result.returncode == 0:
                self.pass_(f"Service {svc_name}:{svc_port} is reachable")
                smoke_passed = True
            else:
                tcp_check = self.run_probe_command(
                    f"smoke-tcp-{index}",
                    self.probe_namespace,
                    self.probe_labels,
                    CONNECT_TIMEOUT,
                    [
                        "sh",
                        "-c",
                        f"echo | nc -w {CONNECT_TIMEOUT} {svc_host} {svc_port} 2>/dev/null && echo 'TCP_OK'",
                    ],
                    capture_output=True,
                    suppress_stderr=True,
                )
                if "TCP_OK" in (tcp_check.stdout or ""):
                    self.pass_(f"Service {svc_name}:{svc_port} is reachable (TCP)")
                    smoke_passed = True

            if not smoke_passed:
                self.fail(f"Service {svc_name}:{svc_port} is not reachable")

    def run_pg_health_check(self, health_port: str) -> None:
        pg_user = str(nested_get(self.chart_entry(self.chart_name), "health_check.pg_user", "postgres"))
        pg_db = str(nested_get(self.chart_entry(self.chart_name), "health_check.pg_db", "postgres"))
        pg_pass = nested_get(self.chart_entry(self.chart_name), "health_check.pg_password", "") or ""
        pg_query = str(nested_get(self.chart_entry(self.chart_name), "health_check.query", "SELECT 1"))
        pg_wait = 180

        self.info(f"Health check (PG): {self.release_name}:{health_port}")
        self.info(f"  user={pg_user}, db={pg_db}, query={pg_query}")
        self.info(f"  pg_isready wait: up to {pg_wait}s (via kubectl exec)")

        pod_result = self.run_command(
            [
                "kubectl",
                "get",
                "pods",
                "-n",
                self.namespace,
                "-l",
                f"app.kubernetes.io/name={self.chart_name}",
                "-o",
                "jsonpath={.items[0].metadata.name}",
            ],
            capture_output=True,
            suppress_stderr=True,
        )
        pg_pod = (pod_result.stdout or "").strip()
        if not pg_pod:
            self.fail(f"Health check (PG): no pod found for {self.chart_name} in {self.namespace}")
            return

        self.info(f"Pod: {pg_pod}")
        pod_info = self.run_command(
            ["kubectl", "get", "pod", pg_pod, "-n", self.namespace, "-o", "wide"],
            capture_output=True,
            merge_stderr=True,
        )
        self.print_indented(pod_info.stdout or "")

        self.info(f"Step 1: pg_isready (waiting up to {pg_wait}s)...")
        elapsed = 0
        pg_ready = False
        while elapsed < pg_wait:
            pg_isready = self.run_command(
                [
                    "kubectl",
                    "exec",
                    pg_pod,
                    "-n",
                    self.namespace,
                    "-c",
                    self.chart_name,
                    "--",
                    "pg_isready",
                    "-h",
                    "127.0.0.1",
                    "-p",
                    health_port,
                    "-U",
                    pg_user,
                    "-d",
                    pg_db,
                ],
                capture_output=True,
                merge_stderr=True,
            )
            pg_output = (pg_isready.stdout or "").strip()
            self.info(f"  [{elapsed}s] {pg_output} (exit {pg_isready.returncode})")
            if "accepting connections" in pg_output:
                pg_ready = True
                break
            time.sleep(5)
            elapsed += 5

        if not pg_ready:
            self.fail(f"Health check (PG): pg_isready gave up after {elapsed}s")
            return

        self.info("Step 2: Running SQL query...")
        pg_exec_cmd = f'psql -h 127.0.0.1 -p {health_port} -U {pg_user} -d {pg_db} -c "{pg_query}"'
        if pg_pass:
            pg_exec_cmd = f"PGPASSWORD={pg_pass} {pg_exec_cmd}"

        query = self.run_command(
            [
                "kubectl",
                "exec",
                pg_pod,
                "-n",
                self.namespace,
                "-c",
                self.chart_name,
                "--",
                "sh",
                "-c",
                pg_exec_cmd,
            ],
            capture_output=True,
            merge_stderr=True,
        )
        self.print_indented(query.stdout or "")

        output = query.stdout or ""
        if query.returncode == 0 and not re.search(r"ERROR|FATAL|does not exist", output, re.IGNORECASE):
            self.pass_(f"Health check (PG): {self.release_name}:{health_port} — pg_isready OK + query succeeded")
        else:
            self.fail(f"Health check (PG): {self.release_name}:{health_port} — SQL query failed (exit {query.returncode})")

    def run_mariadb_health_check(self, health_port: str) -> None:
        mdb_user = str(nested_get(self.chart_entry(self.chart_name), "health_check.mariadb_user", "root"))
        mdb_db = str(nested_get(self.chart_entry(self.chart_name), "health_check.mariadb_db", "mysql"))
        mdb_pass = nested_get(self.chart_entry(self.chart_name), "health_check.mariadb_password", "") or ""
        mdb_query = str(nested_get(self.chart_entry(self.chart_name), "health_check.query", "SELECT 1"))
        mdb_wait = 180

        self.info(f"Health check (MariaDB): {self.release_name}:{health_port}")
        self.info(f"  user={mdb_user}, db={mdb_db}, query={mdb_query}")
        self.info(f"  mysqladmin ping wait: up to {mdb_wait}s (via kubectl exec)")

        pod_result = self.run_command(
            [
                "kubectl",
                "get",
                "pods",
                "-n",
                self.namespace,
                "-l",
                "app.kubernetes.io/name=mariadb",
                "-o",
                "jsonpath={.items[0].metadata.name}",
            ],
            capture_output=True,
            suppress_stderr=True,
        )
        mdb_pod = (pod_result.stdout or "").strip()
        if not mdb_pod:
            self.fail(f"Health check (MariaDB): no pod found for mariadb in {self.namespace}")
            return

        self.info(f"Pod: {mdb_pod}")
        pod_info = self.run_command(
            ["kubectl", "get", "pod", mdb_pod, "-n", self.namespace, "-o", "wide"],
            capture_output=True,
            merge_stderr=True,
        )
        self.print_indented(pod_info.stdout or "")

        self.info(f"Step 1: mysqladmin ping (waiting up to {mdb_wait}s)...")
        elapsed = 0
        mdb_ready = False
        mdb_pass_flag = f"-p{mdb_pass}" if mdb_pass else ""
        while elapsed < mdb_wait:
            command = [
                "kubectl",
                "exec",
                mdb_pod,
                "-n",
                self.namespace,
                "-c",
                "mariadb",
                "--",
                "mysqladmin",
                "ping",
                "-h",
                "127.0.0.1",
                "-P",
                health_port,
                "-u",
                mdb_user,
            ]
            if mdb_pass_flag:
                command.append(mdb_pass_flag)
            ping = self.run_command(command, capture_output=True, merge_stderr=True)
            ping_output = (ping.stdout or "").strip()
            self.info(f"  [{elapsed}s] {ping_output}")
            if re.search(r"alive", ping_output, re.IGNORECASE):
                mdb_ready = True
                break
            time.sleep(5)
            elapsed += 5

        if not mdb_ready:
            self.fail(f"Health check (MariaDB): mysqladmin ping gave up after {elapsed}s")
            return

        self.info("Step 2: Running SQL query...")
        mdb_exec_cmd = f'mysql -h 127.0.0.1 -P {health_port} -u {mdb_user} {mdb_pass_flag} -D {mdb_db} -e "{mdb_query}"'
        query = self.run_command(
            [
                "kubectl",
                "exec",
                mdb_pod,
                "-n",
                self.namespace,
                "-c",
                "mariadb",
                "--",
                "sh",
                "-c",
                mdb_exec_cmd,
            ],
            capture_output=True,
            merge_stderr=True,
        )
        self.print_indented(query.stdout or "")

        output = query.stdout or ""
        if query.returncode == 0 and not re.search(r"ERROR", output, re.IGNORECASE):
            self.pass_(f"Health check (MariaDB): {self.release_name}:{health_port} — mysqladmin ping OK + query succeeded")
        else:
            self.fail(
                f"Health check (MariaDB): {self.release_name}:{health_port} — SQL query failed (exit {query.returncode})"
            )

    def run_http_health_check(self, health_port: str) -> None:
        health_path = str(nested_get(self.chart_entry(self.chart_name), "health_check.path", "/"))
        health_status = str(nested_get(self.chart_entry(self.chart_name), "health_check.expect_status", 200))
        content_type_regex = nested_get(self.chart_entry(self.chart_name), "health_check.expect_content_type_regex", "") or ""
        body_must_match = nested_get(self.chart_entry(self.chart_name), "health_check.body_must_match", "") or ""
        body_must_not_match = nested_get(self.chart_entry(self.chart_name), "health_check.body_must_not_match", "") or ""
        health_url = f"http://{self.service_name}.{self.namespace}.svc.cluster.local:{health_port}{health_path}"

        self.info(f"Health check (HTTP): {health_url} (expect {health_status})")
        self.info(f"  probe namespace: {self.probe_namespace}")

        shell_script = (
            'health_url="$1"; connect_timeout="$2"; '
            'headers_file=$(mktemp); body_file=$(mktemp); '
            'wget -S -O "$body_file" --timeout="$connect_timeout" "$health_url" >/dev/null 2>"$headers_file"; '
            'wget_rc=$?; '
            'printf "__WGET_RC__:%s\\n" "$wget_rc"; '
            'printf "__HEADERS_BEGIN__\\n"; cat "$headers_file"; '
            'printf "\\n__HEADERS_END__\\n"; '
            'printf "__BODY_BEGIN__\\n"; cat "$body_file"; '
            'printf "\\n__BODY_END__\\n"; '
            'rm -f "$headers_file" "$body_file"'
        )

        health = self.run_probe_command(
            "health-check",
            self.probe_namespace,
            self.probe_labels,
            CONNECT_TIMEOUT + 10,
            ["sh", "-c", shell_script, "sh", health_url, str(CONNECT_TIMEOUT)],
            capture_output=True,
            merge_stderr=True,
        )
        health_output = health.stdout or ""

        wget_rc_match = re.findall(r"^__WGET_RC__:(.*)$", health_output, re.MULTILINE)
        http_wget_rc = wget_rc_match[-1].strip() if wget_rc_match else ""
        http_headers = extract_block(health_output, "__HEADERS_BEGIN__\n", "__HEADERS_END__")
        http_body = extract_block(health_output, "__BODY_BEGIN__\n", "__BODY_END__")

        header_lines = [line for line in http_headers.splitlines() if line.strip()]
        http_line = ""
        for line in header_lines:
            if "HTTP/" in line.upper():
                http_line = line
        content_type_line = ""
        for line in header_lines:
            if re.match(r"^\s*Content-Type:", line, re.IGNORECASE):
                content_type_line = line

        if http_wget_rc and http_wget_rc != "0":
            self.fail(
                f"Health check (HTTP): wget failed for {self.release_name}:{health_port}{health_path} (exit {http_wget_rc})"
            )
            self.info(f"  headers: {lines_preview(http_headers, limit=5)}")
        elif not http_line:
            self.fail(f"Health check (HTTP): no HTTP response from {self.release_name}:{health_port}{health_path}")
            self.info(f"  output: {lines_preview(health_output, limit=5)}")
        elif health_status not in http_line:
            self.fail(f"Health check (HTTP): expected HTTP {health_status}, got: {http_line}")
        elif content_type_regex and not re.search(content_type_regex, content_type_line, re.IGNORECASE):
            self.fail(f"Health check (HTTP): content type did not match {content_type_regex}")
            self.info(f"  content type: {content_type_line or '<missing>'}")
        elif body_must_match and not re.search(body_must_match, http_body, re.IGNORECASE):
            self.fail(f"Health check (HTTP): response body did not match required pattern {body_must_match}")
            self.info(f"  body preview: {lines_preview(http_body)}")
        elif body_must_not_match and re.search(body_must_not_match, http_body, re.IGNORECASE):
            self.fail(f"Health check (HTTP): response body matched forbidden pattern {body_must_not_match}")
            self.info(f"  body preview: {lines_preview(http_body)}")
        else:
            self.pass_(
                f"Health check (HTTP): {self.release_name}:{health_port}{health_path} returned HTTP {health_status} with expected content"
            )

    def run_health_check(self) -> None:
        self.section("Phase 3: Health Check")
        health_port = nested_get(self.chart_entry(self.chart_name), "health_check.port", "")
        health_proto = nested_get(self.chart_entry(self.chart_name), "health_check.protocol", "http")
        if health_port in (None, ""):
            self.info("No health check defined — skipping")
            return

        self.tests_run += 1
        port = str(health_port)
        proto = str(health_proto or "http")

        if proto == "pg":
            self.run_pg_health_check(port)
        elif proto == "mariadb":
            self.run_mariadb_health_check(port)
        else:
            self.run_http_health_check(port)
