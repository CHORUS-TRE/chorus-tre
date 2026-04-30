from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "ci"))

from chart_e2e.targets import CHART_TEST_CONFIG_REASON, PlannedTarget


class PlannedTargetFailureModeTests(unittest.TestCase):
    def test_chart_test_config_change_remains_blocking(self) -> None:
        target = PlannedTarget(
            chart_path="charts/i2b2-wildfly",
            reasons=[CHART_TEST_CONFIG_REASON, "reverse dependent of modified i2b2-postgres"],
        )

        self.assertEqual(target.failure_mode, "error")

    def test_reverse_dependent_only_target_warns(self) -> None:
        target = PlannedTarget(
            chart_path="charts/i2b2-frontend",
            reasons=["reverse dependent of modified i2b2-postgres via i2b2-wildfly"],
        )

        self.assertEqual(target.failure_mode, "warning")


if __name__ == "__main__":
    unittest.main()