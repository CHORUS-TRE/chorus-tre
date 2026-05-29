from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "ci"))

from chart_e2e.targets import CHART_TEST_CONFIG_REASON, CI_INFRA_CHANGED_REASON, PlannedTarget, TargetPlanner


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


class CiInfraPathTests(unittest.TestCase):
    def test_chart_e2e_sensor_path_counts_as_ci_infra(self) -> None:
        self.assertTrue(TargetPlanner._has_ci_infra_changes(["charts/chorus-ci/templates/chart-e2e-sensor.yaml"]))

    def test_chorus_ci_values_path_counts_as_ci_infra(self) -> None:
        self.assertTrue(TargetPlanner._has_ci_infra_changes(["charts/chorus-ci/values.yaml"]))

    def test_chorus_ci_chart_path_does_not_count_as_ci_infra(self) -> None:
        self.assertFalse(TargetPlanner._has_ci_infra_changes(["charts/chorus-ci/Chart.yaml"]))

    def test_unrelated_chorus_ci_template_does_not_count_as_ci_infra(self) -> None:
        self.assertFalse(TargetPlanner._has_ci_infra_changes(["charts/chorus-ci/templates/build-images-sensor.yaml"]))

    def test_chorus_ci_values_change_triggers_ci_sweep_not_direct_chorus_ci_target(self) -> None:
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as handle:
            json.dump(
                {
                    "charts": {
                        "chorus-ci": {"skip_deploy": True},
                        "i2b2-postgres": {},
                        "i2b2-wildfly": {"depends_on": ["i2b2-postgres"]},
                    }
                },
                handle,
            )
            registry_path = Path(handle.name)

        self.addCleanup(registry_path.unlink, missing_ok=True)

        planner = TargetPlanner(registry_path)
        targets = planner.plan("charts/chorus-ci/values.yaml")

        self.assertEqual([target.chart_path for target in targets], ["charts/i2b2-postgres", "charts/i2b2-wildfly"])
        self.assertTrue(all(target.reasons == [CI_INFRA_CHANGED_REASON] for target in targets))

    def test_chorus_ci_chart_version_bump_alone_does_not_schedule_chart_tests(self) -> None:
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as handle:
            json.dump(
                {
                    "charts": {
                        "chorus-ci": {"skip_deploy": True},
                        "i2b2-postgres": {},
                        "i2b2-wildfly": {"depends_on": ["i2b2-postgres"]},
                    }
                },
                handle,
            )
            registry_path = Path(handle.name)

        self.addCleanup(registry_path.unlink, missing_ok=True)

        planner = TargetPlanner(registry_path)
        targets = planner.plan("charts/chorus-ci/Chart.yaml")

        self.assertEqual(targets, [])

    def test_unrelated_chorus_ci_template_change_does_not_schedule_chart_tests(self) -> None:
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as handle:
            json.dump(
                {
                    "charts": {
                        "chorus-ci": {"skip_deploy": True},
                        "i2b2-postgres": {},
                        "i2b2-wildfly": {"depends_on": ["i2b2-postgres"]},
                    }
                },
                handle,
            )
            registry_path = Path(handle.name)

        self.addCleanup(registry_path.unlink, missing_ok=True)

        planner = TargetPlanner(registry_path)
        targets = planner.plan("charts/chorus-ci/templates/build-images-sensor.yaml")

        self.assertEqual(targets, [])


if __name__ == "__main__":
    unittest.main()