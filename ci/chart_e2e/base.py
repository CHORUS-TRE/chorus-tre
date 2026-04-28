"""Base helpers for the chart e2e runner."""

from __future__ import annotations

import json
import random
import subprocess
from pathlib import Path
from typing import Any

from .constants import CONNECT_TIMEOUT, CYAN, GREEN, NC, RED, TEST_IMAGE, YELLOW
from .utils import helm_value_string, nested_get


class RunnerBase:
    def __init__(self, chart_path: str, chart_name: str) -> None:
        self.chart_path_arg = chart_path
        self.chart_name = chart_name
        self.script_dir = Path(__file__).resolve().parent.parent
        self.repo_root = self.script_dir.parent
        self.chart_path = self.repo_root / chart_path
        self.registry_path = self.repo_root / "ci" / "chart-tests.yaml"
        self.registry = self.load_registry()
        self.failures = 0
        self.tests_run = 0

        self.namespace = self.chart_config("namespace", self.defaults_config("namespace", "test"))
        self.timeout = int(self.chart_config("timeout", self.defaults_config("timeout", 120)))
        self.skip_deploy = str(self.chart_config("skip_deploy", False)).lower() == "true"
        self.values_file = self.chart_config("values_file", "")
        self.release_name = f"e2e-{self.chart_name}"
        self.fullname_override = self.chart_config("fullname_override", "")
        self.service_name = self.service_name_for_chart(self.chart_name, self.release_name)
        self.probe_namespace = self.chart_config("probe.namespace", self.namespace)
        self.probe_labels = self.probe_labels_for_chart(self.chart_name)

    def load_registry(self) -> dict[str, Any]:
        result = self.run_command(
            ["yq", "-o=json", ".", str(self.registry_path)],
            capture_output=True,
            merge_stderr=True,
        )
        if result.returncode != 0:
            raise RuntimeError(result.stdout.strip() or "Failed to load ci/chart-tests.yaml with yq")
        return json.loads(result.stdout or "{}")

    def defaults_config(self, key: str, default: Any = "") -> Any:
        return nested_get(self.registry.get("defaults", {}), key, default)

    def chart_entry(self, chart: str) -> dict[str, Any]:
        charts = self.registry.get("charts", {})
        entry = charts.get(chart, {})
        return entry if isinstance(entry, dict) else {}

    def chart_config(self, key: str, default: Any = "") -> Any:
        return nested_get(self.chart_entry(self.chart_name), key, default)

    def service_name_for_chart(self, chart: str, release: str) -> str:
        override = self.chart_entry(chart).get("fullname_override")
        if override:
            return str(override)
        return release

    def namespace_for_chart(self, chart: str) -> str:
        entry = self.chart_entry(chart)
        if "namespace" in entry and entry["namespace"] is not None:
            return str(entry["namespace"])
        return str(self.defaults_config("namespace", "test"))

    def dependency_deploy_namespace_for_chart(self, chart: str) -> str:
        entry = self.chart_entry(chart)
        if "namespace" in entry and entry["namespace"] is not None:
            return str(entry["namespace"])
        return self.namespace

    def service_port_for_chart(self, chart: str) -> str:
        entry = self.chart_entry(chart)
        services = entry.get("services") or []
        if services:
            first = services[0] or {}
            port = first.get("port")
            if port is not None:
                return str(port)
        port = nested_get(entry, "health_check.port", "")
        return "" if port in (None, "") else str(port)

    def probe_labels_for_chart(self, chart: str) -> str:
        labels = nested_get(self.chart_entry(chart), "probe.labels", {}) or {}
        if not isinstance(labels, dict):
            return ""
        return ",".join(f"{key}={helm_value_string(value)}" for key, value in labels.items())

    def set_arg_lines_for_chart(self, chart: str) -> list[tuple[str, str]]:
        entry = self.chart_entry(chart)
        args: list[tuple[str, str]] = []

        values = entry.get("values") or {}
        if isinstance(values, dict):
            for key, value in values.items():
                args.append((str(key), helm_value_string(value)))

        dependency_values = entry.get("dependency_values") or {}
        if not isinstance(dependency_values, dict):
            return args

        for dep_key, config in dependency_values.items():
            if not isinstance(config, dict):
                continue

            dep_chart = config.get("chart")
            if not dep_key or not dep_chart:
                continue

            dep_release = f"e2e-{dep_chart}"
            dep_attr = config.get("attribute") or "serviceName"
            dep_path = str(config.get("path") or "")

            if dep_attr == "serviceName":
                dep_value = self.service_name_for_chart(str(dep_chart), dep_release)
            elif dep_attr == "releaseName":
                dep_value = dep_release
            elif dep_attr == "namespace":
                dep_value = self.namespace_for_chart(str(dep_chart))
            elif dep_attr == "servicePort":
                dep_value = self.service_port_for_chart(str(dep_chart))
            elif dep_attr in {"httpBaseUrl", "httpUrl"}:
                dep_service_name = self.service_name_for_chart(str(dep_chart), dep_release)
                dep_service_port = self.service_port_for_chart(str(dep_chart))
                if not dep_service_port:
                    self.warn(
                        f"No service port found for dependency chart '{dep_chart}' referenced by {chart}.{dep_key} — skipping"
                    )
                    continue
                dep_value = f"http://{dep_service_name}:{dep_service_port}"
                if dep_attr == "httpUrl":
                    dep_value = f"{dep_value}{dep_path}"
            else:
                self.warn(
                    f"Unknown dependency_values attribute '{dep_attr}' for {chart}.{dep_key} — skipping"
                )
                continue

            args.append((str(dep_key), dep_value))

        return args

    def resolve_deps(self, chart: str) -> list[str]:
        resolved: list[str] = []
        queue: list[str] = [chart]

        while queue:
            current = queue.pop(0)
            deps = self.chart_entry(current).get("depends_on") or []
            for dep in deps:
                dep_name = str(dep)
                resolved.append(dep_name)
                queue.append(dep_name)

        ordered: list[str] = []
        seen: set[str] = set()
        for dep in reversed(resolved):
            if dep and dep not in seen:
                seen.add(dep)
                ordered.append(dep)
        return ordered

    def run_command(
        self,
        args: list[str],
        *,
        input_text: str | None = None,
        capture_output: bool = False,
        merge_stderr: bool = False,
        suppress_stderr: bool = False,
        cwd: Path | None = None,
    ) -> subprocess.CompletedProcess[str]:
        stdout = subprocess.PIPE if capture_output else None
        if suppress_stderr:
            stderr: Any = subprocess.DEVNULL
        elif merge_stderr:
            stderr = subprocess.STDOUT
        elif capture_output:
            stderr = subprocess.PIPE
        else:
            stderr = None

        return subprocess.run(
            args,
            cwd=str(cwd) if cwd else None,
            input=input_text,
            text=True,
            stdout=stdout,
            stderr=stderr,
            check=False,
        )

    def run_shell(self, command: str) -> subprocess.CompletedProcess[str]:
        return self.run_command(["/bin/bash", "-c", command])

    def ensure_namespace(self, namespace: str, *, quiet: bool = False) -> None:
        create = self.run_command(
            ["kubectl", "create", "namespace", namespace, "--dry-run=client", "-o", "yaml"],
            capture_output=True,
            merge_stderr=True,
        )
        if create.returncode != 0:
            raise RuntimeError(create.stdout.strip() or f"Failed to render namespace {namespace}")

        apply = self.run_command(
            ["kubectl", "apply", "-f", "-"],
            input_text=create.stdout,
            capture_output=quiet,
            merge_stderr=quiet,
        )
        if apply.returncode != 0:
            detail = (apply.stdout or "").strip() if quiet else ""
            raise RuntimeError(detail or f"Failed to apply namespace {namespace}")

    def run_probe_command(
        self,
        pod_prefix: str,
        probe_namespace: str,
        probe_labels: str,
        timeout_secs: int,
        command: list[str],
        *,
        capture_output: bool = False,
        suppress_stderr: bool = False,
        merge_stderr: bool = False,
    ) -> subprocess.CompletedProcess[str]:
        self.ensure_namespace(probe_namespace, quiet=True)

        pod_name = f"{pod_prefix}-{random.randint(0, 65535)}"
        probe_cmd = [
            "kubectl",
            "run",
            pod_name,
            f"--image={TEST_IMAGE}",
            "--restart=Never",
            "--rm",
            "-i",
            "--namespace",
            probe_namespace,
            f"--timeout={timeout_secs}s",
        ]

        if probe_labels:
            probe_cmd.extend(["--labels", probe_labels])

        probe_cmd.append("--")
        probe_cmd.extend(command)

        return self.run_command(
            probe_cmd,
            capture_output=capture_output,
            suppress_stderr=suppress_stderr,
            merge_stderr=merge_stderr,
        )

    def pass_(self, message: str) -> None:
        print(f"{GREEN}  ✅ PASS: {message}{NC}")

    def fail(self, message: str) -> None:
        print(f"{RED}  ❌ FAIL: {message}{NC}")
        self.failures += 1

    def info(self, message: str) -> None:
        print(f"{CYAN}  ℹ️  {message}{NC}")

    def warn(self, message: str) -> None:
        print(f"{YELLOW}  ⚠️  {message}{NC}")

    def section(self, title: str) -> None:
        print(f"\n{CYAN}━━━ {title} ━━━{NC}")

    def print_indented(self, text: str) -> None:
        for line in text.splitlines():
            print(f"    {line}")
