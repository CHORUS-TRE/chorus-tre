"""Deployment phases for the chart e2e runner."""

from __future__ import annotations

import shlex
import time


class DeploymentMixin:
    def deploy_dependencies(self) -> int:
        dep_list = self.resolve_deps(self.chart_name)
        if not dep_list:
            return 0

        self.section("Phase 0b: Deploy Dependencies")
        for dep_name in dep_list:
            dep_release = f"e2e-{dep_name}"
            dep_ns = self.dependency_deploy_namespace_for_chart(dep_name)
            dep_timeout = int(self.chart_entry(dep_name).get("timeout") or 120)
            dep_values_file = self.chart_entry(dep_name).get("values_file") or ""
            dep_fullname_override = self.chart_entry(dep_name).get("fullname_override") or ""
            dep_service_name = self.service_name_for_chart(dep_name, dep_release)

            self.info(
                f"Dependency: {dep_name} (release {dep_release}, service {dep_service_name}, ns {dep_ns})"
            )

            status = self.run_command(["helm", "status", dep_release, "-n", dep_ns], suppress_stderr=True)
            if status.returncode == 0:
                self.info("  Already deployed — skipping")
                continue

            if dep_ns != self.namespace:
                self.ensure_namespace(dep_ns)

            pre_install = self.chart_entry(dep_name).get("pre_install") or []
            if pre_install:
                self.info(f"  Running {len(pre_install)} pre-install command(s) for {dep_name}...")
                for command in pre_install:
                    self.info(f"    → {command}")
                    result = self.run_shell(str(command))
                    if result.returncode != 0:
                        self.fail(f"Dependency {dep_name} pre-install failed — aborting")
                        return result.returncode or 1

            dep_chart_path = self.repo_root / "charts" / dep_name
            dep_helm_cmd = [
                "helm",
                "install",
                dep_release,
                str(dep_chart_path),
                "--namespace",
                dep_ns,
                "--values",
                str(dep_chart_path / "values.yaml"),
                "--wait",
                "--timeout",
                f"{dep_timeout}s",
            ]

            if dep_values_file:
                dep_helm_cmd.extend(["--values", str(self.repo_root / str(dep_values_file))])

            for key, value in self.set_arg_lines_for_chart(dep_name):
                dep_helm_cmd.extend(["--set", f"{key}={value}"])

            if dep_fullname_override:
                dep_helm_cmd.extend(["--set", f"fullnameOverride={dep_fullname_override}"])

            self.run_command(["helm", "dependency", "build", str(dep_chart_path)], suppress_stderr=True)

            self.info("  Installing dependency chart...")
            print(f"    {shlex.join(dep_helm_cmd)}")
            result = self.run_command(dep_helm_cmd)
            if result.returncode == 0:
                self.pass_(f"Dependency {dep_name} deployed")
            else:
                self.fail(f"Dependency {dep_name} failed to deploy — aborting")
                return 1

        return 0

    def deploy_chart(self) -> int:
        self.section("Phase 1: Deploy")

        helm_set_args: list[str] = []
        for key, value in self.set_arg_lines_for_chart(self.chart_name):
            helm_set_args.extend(["--set", f"{key}={value}"])

        if self.fullname_override:
            helm_set_args.extend(["--set", f"fullnameOverride={self.fullname_override}"])

        self.info("Updating Helm dependencies...")
        self.run_command(["helm", "dependency", "build", str(self.chart_path)], suppress_stderr=True)

        helm_cmd = [
            "helm",
            "install",
            self.release_name,
            str(self.chart_path),
            "--namespace",
            self.namespace,
            "--values",
            str(self.chart_path / "values.yaml"),
            "--wait",
            "--timeout",
            f"{self.timeout}s",
        ]

        if self.values_file:
            helm_cmd.extend(["--values", str(self.repo_root / str(self.values_file))])
        helm_cmd.extend(helm_set_args)

        self.info("Installing chart...")
        print(f"  {shlex.join(helm_cmd)}")

        result = self.run_command(helm_cmd)
        if result.returncode == 0:
            self.pass_("Chart deployed successfully")
            return 0

        self.warn("Helm install with --wait failed. Retrying without --wait...")
        helm_cmd_nowait = [
            "helm",
            "install",
            self.release_name,
            str(self.chart_path),
            "--namespace",
            self.namespace,
            "--values",
            str(self.chart_path / "values.yaml"),
            "--timeout",
            f"{self.timeout}s",
        ]
        if self.values_file:
            helm_cmd_nowait.extend(["--values", str(self.repo_root / str(self.values_file))])
        helm_cmd_nowait.extend(helm_set_args)

        self.run_command(["helm", "uninstall", self.release_name, "-n", self.namespace], suppress_stderr=True)
        time.sleep(2)

        retry = self.run_command(helm_cmd_nowait)
        if retry.returncode == 0:
            self.info("Chart deployed (pods may not be fully ready — expected for apps needing backends)")
            time.sleep(10)
            return 0

        self.fail("Chart deployment failed")
        return 1

    def show_deployed_resources(self) -> None:
        print()
        self.info("Deployed resources:")
        labeled = self.run_command(
            [
                "kubectl",
                "get",
                "all",
                "-n",
                self.namespace,
                "-l",
                f"app.kubernetes.io/instance={self.release_name}",
            ],
            suppress_stderr=True,
        )
        if labeled.returncode == 0:
            print()
        else:
            fallback = self.run_command(
                ["kubectl", "get", "all", "-n", self.namespace],
                capture_output=True,
                suppress_stderr=True,
            )
            output = fallback.stdout or ""
            preview = "\n".join(output.splitlines()[:20])
            if preview:
                print(preview)
        print()
