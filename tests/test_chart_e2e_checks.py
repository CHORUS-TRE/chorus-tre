from __future__ import annotations

import importlib
import sys
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "ci"))

ChecksMixin = importlib.import_module("chart_e2e.checks").ChecksMixin


class SmokeRetryHarness(ChecksMixin):
    def __init__(self, probe_results: list[SimpleNamespace], *, timeout: int = 10) -> None:
        self.chart_name = "i2b2-postgres"
        self.namespace = "i2b2"
        self.service_name = "e2e-i2b2-postgres"
        self.probe_namespace = "i2b2"
        self.probe_labels = ""
        self.tests_run = 0
        self.timeout = timeout
        self._probe_results = list(probe_results)
        self.fail_messages: list[str] = []
        self.pass_messages: list[str] = []

    def section(self, _title: str) -> None:
        return None

    def info(self, _message: str) -> None:
        return None

    def fail(self, message: str) -> None:
        self.fail_messages.append(message)

    def pass_(self, message: str) -> None:
        self.pass_messages.append(message)

    def chart_entry(self, _chart: str) -> dict:
        return {"services": [{"port": 5432}]}

    def run_probe_command(self, *args, **kwargs):  # type: ignore[no-untyped-def]
        return self._probe_results.pop(0)


class SmokeRetryTests(unittest.TestCase):
    def test_retries_until_tcp_becomes_ready(self) -> None:
        harness = SmokeRetryHarness(
            [
                SimpleNamespace(returncode=1, stdout=""),
                SimpleNamespace(returncode=1, stdout=""),
                SimpleNamespace(returncode=1, stdout=""),
                SimpleNamespace(returncode=0, stdout="TCP_OK"),
            ]
        )

        with patch("chart_e2e.checks.time.sleep") as sleep_mock:
            harness.run_smoke_tests()

        self.assertEqual(harness.tests_run, 1)
        self.assertEqual(harness.fail_messages, [])
        self.assertEqual(harness.pass_messages, ["Service e2e-i2b2-postgres:5432 is reachable (TCP)"])
        sleep_mock.assert_called_once_with(5)


if __name__ == "__main__":
    unittest.main()
