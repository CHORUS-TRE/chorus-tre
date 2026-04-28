"""Main chart e2e runner composition."""

from __future__ import annotations

from .base import RunnerBase
from .checks import ChecksMixin
from .constants import GREEN, NC, RED
from .deploy import DeploymentMixin


class ChartE2ERunner(ChecksMixin, DeploymentMixin, RunnerBase):
    def print_summary(self) -> int:
        self.section(f"Summary: {self.chart_name}")
        print()
        print(f"  Tests run:  {self.tests_run}")
        print(f"  Failures:   {self.failures}")
        print()

        if self.failures > 0:
            print(f"{RED}  ❌ {self.failures} test(s) FAILED{NC}")
            return 1

        print(f"{GREEN}  ✅ All tests passed{NC}")
        return 0

    def run(self) -> int:
        self.section(f"Chart E2E: {self.chart_name}")
        print(f"  Chart path:   {self.chart_path_arg}")
        print(f"  Namespace:    {self.namespace}")
        print(f"  Release:      {self.release_name}")
        print(f"  Service:      {self.service_name}")
        print(f"  Probe ns:     {self.probe_namespace}")
        print(f"  Timeout:      {self.timeout}s")

        if self.skip_deploy:
            self.info("Chart marked as skip_deploy (CRD/infra only). Skipping.")
            return 0

        self.section("Phase 0: Setup")
        self.ensure_namespace(self.namespace)
        self.info(f"Namespace '{self.namespace}' ready")

        pre_install = self.chart_entry(self.chart_name).get("pre_install") or []
        if pre_install:
            self.info(f"Running {len(pre_install)} pre-install command(s)...")
            for command in pre_install:
                self.info(f"  → {command}")
                result = self.run_shell(str(command))
                if result.returncode != 0:
                    return result.returncode or 1

        if self.deploy_dependencies() != 0:
            return 1

        if self.deploy_chart() != 0:
            return 1

        self.show_deployed_resources()
        self.run_smoke_tests()
        self.run_health_check()
        return self.print_summary()
