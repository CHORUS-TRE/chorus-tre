from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "ci"))

from chart_e2e.base import RunnerBase


class ResolveDepsHarness:
    def __init__(self, dependency_map: dict[str, list[str]]) -> None:
        self.dependency_map = dependency_map

    def chart_entry(self, chart: str) -> dict[str, list[str]]:
        return {"depends_on": self.dependency_map.get(chart, [])}


class ResolveDepsTests(unittest.TestCase):
    def test_resolve_deps_preserves_deploy_order_without_duplicates(self) -> None:
        harness = ResolveDepsHarness(
            {
                "i2b2-frontend": ["i2b2-wildfly"],
                "i2b2-wildfly": ["i2b2-postgres"],
                "i2b2-postgres": [],
            }
        )

        deps = RunnerBase.resolve_deps(harness, "i2b2-frontend")

        self.assertEqual(deps, ["i2b2-postgres", "i2b2-wildfly"])

    def test_resolve_deps_deduplicates_shared_dependencies(self) -> None:
        harness = ResolveDepsHarness(
            {
                "app": ["backend", "database"],
                "backend": ["database"],
                "database": [],
            }
        )

        deps = RunnerBase.resolve_deps(harness, "app")

        self.assertEqual(deps, ["database", "backend"])


if __name__ == "__main__":
    unittest.main()