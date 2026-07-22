"""Deny-path assertions via netassert (controlplaneio/netassert v2).

The positive path (probe/services/health_check) proves the policy admits
legitimate traffic; this phase proves the policy DENIES everything else.
netassert injects an unprivileged ephemeral scanner container into the
SOURCE pod, so tests run with the pod's real labels and Cilium identity —
the exact thing the NetworkPolicy peers match.

A denied connection and a dead backend both yield scanner exit code 1, so
this phase must only run after the positive checks proved the service is
alive — the runner gates on zero failures before calling it.
"""

from __future__ import annotations

import json
import tempfile
from pathlib import Path
from typing import Any

from .constants import (
    NETASSERT_BINARY,
    NETASSERT_DECOY_MANIFEST,
    NETASSERT_DENY_ATTEMPTS,
    NETASSERT_DENY_TIMEOUT_SECONDS,
    NETASSERT_SCANNER_IMAGE,
)


class NetassertMixin:
    def _netassert_config(self) -> dict[str, Any]:
        return self.chart_entry(self.chart_name).get("netassert") or {}

    def _netassert_workload(self) -> dict[str, str]:
        """The chart's own workload — dst for denied_ingress, src for denied_egress."""
        config = self._netassert_config()
        workload = config.get("workload") or {}
        return {
            "kind": str(workload.get("kind", "deployment")),
            "name": str(workload.get("name", self.release_name)),
            "namespace": str(workload.get("namespace", self.namespace)),
        }

    def _ensure_decoy(self) -> bool:
        """Apply the decoy workload (idempotent) — the standard wrong-identity source."""
        manifest = self.repo_root / NETASSERT_DECOY_MANIFEST
        apply = self.run_command(["kubectl", "apply", "-f", str(manifest)], capture_output=True, merge_stderr=True)
        if apply.returncode != 0:
            self.fail(f"netassert: failed to apply decoy manifest: {(apply.stdout or '').strip()}")
            return False
        rollout = self.run_command(
            ["kubectl", "-n", "decoy", "rollout", "status", "deployment/netassert-decoy", "--timeout=120s"],
            capture_output=True,
            merge_stderr=True,
        )
        if rollout.returncode != 0:
            self.fail("netassert: decoy deployment did not become ready")
            return False
        return True

    def _build_tests(self) -> list[dict[str, Any]]:
        config = self._netassert_config()
        workload = self._netassert_workload()
        tests: list[dict[str, Any]] = []

        def base_test(name: str, item: dict[str, Any]) -> dict[str, Any]:
            return {
                "name": name,
                "type": "k8s",
                "protocol": str(item.get("protocol", "tcp")),
                "targetPort": int(item["port"]),
                "timeoutSeconds": int(item.get("timeoutSeconds", NETASSERT_DENY_TIMEOUT_SECONDS)),
                "attempts": int(item.get("attempts", NETASSERT_DENY_ATTEMPTS)),
                "exitCode": 1,
            }

        for item in config.get("denied_ingress") or []:
            test = base_test(f"{self.chart_name}-deny-ingress-{item['port']}", item)
            test["src"] = {"k8sResource": {"kind": "deployment", "name": "netassert-decoy", "namespace": "decoy"}}
            test["dst"] = {"k8sResource": dict(workload)}
            tests.append(test)

        for item in config.get("denied_egress") or []:
            if "host" in item:
                dst: dict[str, Any] = {"host": {"name": str(item["host"])}}
                label = str(item["host"]).replace(".", "-")
            else:
                dst = {"k8sResource": dict(item["k8sResource"])}
                label = str(item["k8sResource"].get("name", "resource"))
            test = base_test(f"{self.chart_name}-deny-egress-{label}-{item['port']}", item)
            test["src"] = {"k8sResource": dict(workload)}
            test["dst"] = dst
            tests.append(test)

        return tests

    def run_netassert_tests(self) -> None:
        tests = self._build_tests()
        if not tests:
            return

        self.section("Phase 4: Deny assertions (netassert)")

        if not self._ensure_decoy():
            return

        with tempfile.TemporaryDirectory(prefix="netassert.") as tmp:
            spec_file = Path(tmp) / "tests.yaml"
            tap_file = Path(tmp) / "results.tap"
            # JSON is valid YAML — the runner has no YAML emitter (stdlib only).
            spec_file.write_text(json.dumps(tests, indent=2), encoding="utf-8")

            self.info(f"Running {len(tests)} deny assertion(s) via {NETASSERT_BINARY}")
            run = self.run_command(
                [
                    NETASSERT_BINARY,
                    "run",
                    "--input-file",
                    str(spec_file),
                    "--tap",
                    str(tap_file),
                    "--scanner-image",
                    NETASSERT_SCANNER_IMAGE,
                ],
                capture_output=True,
                merge_stderr=True,
            )

            if not tap_file.is_file():
                self.fail(f"netassert produced no TAP output (exit {run.returncode})")
                self.info(f"  output: {(run.stdout or '').strip()[-800:]}")
                return

            results = self._parse_tap(tap_file.read_text(encoding="utf-8"))
            reported = set()
            for passed, name in results:
                reported.add(name)
                self.tests_run += 1
                if passed:
                    self.pass_(f"Denied as expected: {name}")
                else:
                    self.fail(f"NOT denied (connection succeeded or test error): {name}")
            for test in tests:
                if test["name"] not in reported:
                    self.tests_run += 1
                    self.fail(f"netassert reported no result for: {test['name']}")

    @staticmethod
    def _parse_tap(tap: str) -> list[tuple[bool, str]]:
        results: list[tuple[bool, str]] = []
        for line in tap.splitlines():
            line = line.strip()
            if line.startswith("ok ") and " - " in line:
                results.append((True, line.split(" - ", 1)[1].strip()))
            elif line.startswith("not ok ") and " - " in line:
                results.append((False, line.split(" - ", 1)[1].strip()))
        return results
