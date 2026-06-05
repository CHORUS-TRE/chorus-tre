"""Repo-level chart e2e orchestration for Argo workflows."""

from __future__ import annotations

import argparse
import re
import shlex
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

from .runner import ChartE2ERunner
from .targets import PlannedTarget, TargetPlanner


KIND_CLUSTER_NAME = "chart-e2e"
KIND_CONFIG_PATH = Path("ci/kind-config.yaml")


class RepoChartE2EWorkflow:
    def __init__(self, repo_root: Path, base_sha: str, head_sha: str, base_ref: str = "") -> None:
        self.repo_root = repo_root
        self.base_sha = base_sha
        self.head_sha = head_sha
        self.base_ref = base_ref
        self.registry_file: Path | None = None
        self.planner: TargetPlanner | None = None
        self.cluster_created = False

    def run(self) -> int:
        status = 0
        try:
            changed_files = self.changed_files()
            self.registry_file = self.render_registry_file()
            self.planner = TargetPlanner(self.registry_file)
            targets = self.planner.plan(" ".join(changed_files))

            if not targets:
                print("No charts to test.")
                return 0

            print("Chart test target reasons:")
            for target in targets:
                print(f"  - {target.chart_name}: {target.reason_text}")
            print(f"Charts to test: {' '.join(target.chart_path for target in targets)}")

            self.create_kind_cluster()
            self.install_cilium()
            self.install_cluster_baseline()
            self.add_helm_repositories()
            status = self.run_targets(targets)
        except Exception as exc:  # pragma: no cover - defensive orchestration guard
            print(str(exc), file=sys.stderr)
            status = 1
        finally:
            if status != 0 and self.cluster_created:
                self.dump_debug_info()
            if self.registry_file and self.registry_file.exists():
                self.registry_file.unlink(missing_ok=True)
        return status

    def changed_files(self) -> list[str]:
        self.ensure_base_commit_available()
        diff_range = f"{self.base_sha}...{self.head_sha}"
        diff = self.run_command(
            ["git", "diff", "--name-only", diff_range],
            capture_output=True,
            merge_stderr=True,
        )
        if diff.returncode != 0:
            raise RuntimeError(diff.stdout.strip() or "Failed to compute changed files")

        changed_files = [line.strip() for line in (diff.stdout or "").splitlines() if line.strip()]
        print(f"Comparing changed files: {diff_range}")
        if self.base_ref:
            print(f"Base ref: {self.base_ref}")
        if not changed_files:
            print("Changed files: <none>")
            return []

        print("Changed files:")
        for changed_file in changed_files:
            print(f"  - {changed_file}")
        return changed_files

    def ensure_base_commit_available(self) -> None:
        if self.has_commit(self.base_sha):
            print(f"Verified base commit is present: {self.base_sha}")
            return

        print(f"Base commit {self.base_sha} is not present in the checkout.")
        if not self.base_ref:
            raise RuntimeError(
                f"Base commit {self.base_sha} is not present in the checkout and no base ref was provided"
            )

        print(f"Fetching origin/{self.base_ref} to resolve base commit {self.base_sha}")
        fetch = self.run_command(
            ["git", "fetch", "--no-tags", "origin", self.base_ref],
            capture_output=True,
            merge_stderr=True,
        )
        fetch_output = (fetch.stdout or "").strip()
        if fetch_output:
            print(fetch_output)
        if fetch.returncode != 0:
            raise RuntimeError(
                fetch_output or f"Failed to fetch origin/{self.base_ref} while resolving base commit {self.base_sha}"
            )

        if not self.has_commit(self.base_sha):
            raise RuntimeError(
                f"Base commit {self.base_sha} is not present in the checkout after fetching origin/{self.base_ref}"
            )

        print(f"Verified base commit is present after fetch: {self.base_sha}")

    def has_commit(self, sha: str) -> bool:
        result = self.run_command(
            ["git", "cat-file", "-e", f"{sha}^{{commit}}"],
            capture_output=True,
            suppress_stderr=True,
        )
        return result.returncode == 0

    def render_registry_file(self) -> Path:
        registry_index = self.repo_root / "ci/chart-tests.yaml"
        registry_chart_dir = self.repo_root / "ci/chart-tests/charts"
        registry_files = [registry_index, *sorted(registry_chart_dir.glob("*.yaml"))]

        merged = self.run_command(
            ["yq", "eval-all", ". as $item ireduce ({}; . * $item)", *[str(path) for path in registry_files]],
            capture_output=True,
            merge_stderr=True,
        )
        if merged.returncode != 0:
            raise RuntimeError(merged.stdout.strip() or "Failed to render chart test registry")

        temp_handle = tempfile.NamedTemporaryFile(prefix="chart-tests.merged.", suffix=".yaml", delete=False)
        temp_handle.close()
        registry_file = Path(temp_handle.name)
        registry_file.write_text(merged.stdout or "{}\n", encoding="utf-8")
        print(f"Rendered chart test registry to {registry_file}")
        return registry_file

    def create_kind_cluster(self) -> None:
        kind_config = self.repo_root / KIND_CONFIG_PATH
        if not kind_config.exists():
            raise RuntimeError(f"Missing Kind config: {kind_config}")

        print(f"Using Kind config: {kind_config.relative_to(self.repo_root)}")
        self.run_command(
            ["kind", "delete", "cluster", "--name", KIND_CLUSTER_NAME],
            capture_output=True,
            suppress_stderr=True,
        )
        self.run_command(
            ["docker", "system", "prune", "-af"],
            capture_output=True,
            suppress_stderr=True,
        )

        create = self.run_command(
            [
                "kind",
                "create",
                "cluster",
                "--config",
                str(kind_config),
                "--name",
                KIND_CLUSTER_NAME,
                "--wait",
                "300s",
            ]
        )
        if create.returncode != 0:
            self.dump_kind_logs()
            raise RuntimeError("Kind cluster creation failed")
        self.cluster_created = True

    def install_cilium(self) -> None:
        self.run_checked(["helm", "repo", "add", "cilium", "https://helm.cilium.io"])
        self.run_checked(["helm", "repo", "update", "cilium"])
        self.run_checked(
            [
                "helm",
                "upgrade",
                "--install",
                "cilium",
                "cilium/cilium",
                "--namespace",
                "kube-system",
                "--create-namespace",
                "--set",
                "kubeProxyReplacement=true",
                "--set",
                f"k8sServiceHost={KIND_CLUSTER_NAME}-control-plane",
                "--set",
                "k8sServicePort=6443",
                "--wait",
            ]
        )
        self.run_checked(["kubectl", "-n", "kube-system", "rollout", "status", "daemonset/cilium", "--timeout=300s"])
        self.run_checked(
            ["kubectl", "-n", "kube-system", "rollout", "status", "deployment/cilium-operator", "--timeout=300s"]
        )

    def install_cluster_baseline(self) -> None:
        priority_class_chart = self.repo_root / "charts" / "chorus-priority-class"
        self.run_checked(
            [
                "helm",
                "install",
                "e2e-chorus-priority-class",
                str(priority_class_chart),
                "--namespace",
                "kube-system",
                "--create-namespace",
                "--wait",
            ]
        )

    def add_helm_repositories(self) -> None:
        repos: set[str] = set()
        repo_pattern = re.compile(r"^\s*repository:\s*(\S+)")

        for chart_yaml in sorted((self.repo_root / "charts").glob("*/Chart.yaml")):
            for line in chart_yaml.read_text(encoding="utf-8").splitlines():
                match = repo_pattern.match(line)
                if not match:
                    continue
                repo = match.group(1).strip()
                if repo and not repo.startswith("oci://"):
                    repos.add(repo)

        for repo in sorted(repos):
            repo_name = re.sub(r"^https?://", "", repo)
            repo_name = repo_name.replace("/", "-")
            add = self.run_command(["helm", "repo", "add", repo_name, repo], capture_output=True, merge_stderr=True)
            if add.returncode == 0:
                output = (add.stdout or "").strip()
                if output:
                    print(output)
            elif "already exists" not in (add.stdout or ""):
                print((add.stdout or "").strip(), file=sys.stderr)

        self.run_checked(["helm", "repo", "update"])

    def run_targets(self, targets: list[PlannedTarget]) -> int:
        overall_exit = 0
        warning_targets = [target for target in targets if target.failure_mode == "warning"]
        warning_count = 0

        if warning_targets:
            print()
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("Impact Checks")
            print("These charts are being tested as reverse dependents. Failures here warn but do not fail the workflow.")
            for target in warning_targets:
                print(f"  - {target.chart_name}: {target.reason_text}")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print()

        for target in targets:
            print()
            print("╔══════════════════════════════════════════════════════════╗")
            print(f"║  Testing: {target.chart_name}")
            print("╚══════════════════════════════════════════════════════════╝")
            print(f"Reason: {target.reason_text}")
            if any("reverse dependent" in reason for reason in target.reasons):
                print("Impact check: dependency changes can break this service even when this chart did not change directly.")
            if target.failure_mode == "warning":
                print("Failure mode: warning-only impacted-service check.")
            print()

            exit_code = 1
            try:
                exit_code = ChartE2ERunner(target.chart_path, target.chart_name).run()
            except Exception as exc:  # pragma: no cover - defensive runner guard
                print(str(exc), file=sys.stderr)
                exit_code = 1
            finally:
                self.cleanup_chart(target.chart_name)
                print()

            if exit_code != 0:
                if target.failure_mode == "warning":
                    print(f"WARNING: impacted-service check failed for {target.chart_name} ({target.reason_text})")
                    warning_count += 1
                else:
                    print(f"Error: E2E tests failed for chart: {target.chart_name}")
                    overall_exit = 1

        if warning_count > 0:
            print(f"WARNING: {warning_count} reverse-dependent impacted-service warning(s) detected")

        return overall_exit

    def cleanup_chart(self, chart_name: str) -> None:
        chart_namespace = self.chart_namespace(chart_name)
        cleanup_namespaces = [chart_namespace]
        self.print_optional_output(
            self.run_command(["helm", "uninstall", f"e2e-{chart_name}", "-n", chart_namespace], capture_output=True, suppress_stderr=True)
        )

        for dependency_name in self.resolve_deps(chart_name):
            dependency_namespace = self.dependency_namespace(dependency_name, chart_namespace)
            if dependency_namespace not in cleanup_namespaces:
                cleanup_namespaces.append(dependency_namespace)
            print(f"  Cleaning up dependency: {dependency_name}")
            self.print_optional_output(
                self.run_command(
                    ["helm", "uninstall", f"e2e-{dependency_name}", "-n", dependency_namespace],
                    capture_output=True,
                    suppress_stderr=True,
                )
            )

        for namespace in cleanup_namespaces:
            self.run_command(
                ["kubectl", "delete", "pods", "--field-selector=status.phase!=Running", "-n", namespace],
                capture_output=True,
                suppress_stderr=True,
            )

    def chart_namespace(self, chart_name: str) -> str:
        planner = self.require_planner()
        chart_config = planner.charts.get(chart_name, {}) or {}
        namespace = chart_config.get("namespace")
        if namespace not in (None, ""):
            return str(namespace)
        defaults = planner.registry.get("defaults", {}) or {}
        return str(defaults.get("namespace") or "test")

    def dependency_namespace(self, dependency_name: str, chart_namespace: str) -> str:
        planner = self.require_planner()
        chart_config = planner.charts.get(dependency_name, {}) or {}
        namespace = chart_config.get("namespace")
        if namespace not in (None, ""):
            return str(namespace)
        return chart_namespace

    def resolve_deps(self, chart_name: str) -> list[str]:
        planner = self.require_planner()
        resolved: list[str] = []
        queue: list[str] = [chart_name]

        while queue:
            current = queue.pop(0)
            depends_on = planner.charts.get(current, {}).get("depends_on") or []
            for dependency in depends_on:
                dependency_name = str(dependency)
                resolved.append(dependency_name)
                queue.append(dependency_name)

        ordered: list[str] = []
        seen: set[str] = set()
        for dependency_name in reversed(resolved):
            if dependency_name and dependency_name not in seen:
                seen.add(dependency_name)
                ordered.append(dependency_name)
        return ordered

    def dump_kind_logs(self) -> None:
        for service in ("kubelet", "containerd"):
            print(f"=== Kind {service} logs ===")
            result = self.run_command(
                [
                    "docker",
                    "exec",
                    f"{KIND_CLUSTER_NAME}-control-plane",
                    "journalctl",
                    "-u",
                    service,
                    "--no-pager",
                    "-n",
                    "80" if service == "kubelet" else "40",
                ],
                capture_output=True,
                suppress_stderr=True,
            )
            output = (result.stdout or "").strip()
            if output:
                print(output)
            print()

    def dump_debug_info(self) -> None:
        self.print_debug_section("Node status", ["kubectl", "get", "nodes", "-o", "wide"])
        self.print_debug_section("All pods", ["kubectl", "get", "pods", "-A", "-o", "wide"])
        self.print_debug_section(
            "Events",
            ["/bin/bash", "-lc", "kubectl get events -A --sort-by=.lastTimestamp | tail -50"],
        )

    def print_debug_section(self, title: str, args: list[str]) -> None:
        print(f"=== {title} ===")
        result = self.run_command(args, capture_output=True, merge_stderr=True)
        output = (result.stdout or "").strip()
        if output:
            print(output)
        print()

    def require_planner(self) -> TargetPlanner:
        if self.planner is None:
            raise RuntimeError("Target planner is not initialized")
        return self.planner

    def print_optional_output(self, result: subprocess.CompletedProcess[str]) -> None:
        output = (result.stdout or "").strip()
        if output:
            print(output)

    def run_checked(self, args: list[str], *, cwd: Path | None = None, env: dict[str, str] | None = None) -> None:
        result = self.run_command(args, cwd=cwd, env=env)
        if result.returncode != 0:
            raise RuntimeError(f"Command failed ({result.returncode}): {shlex.join(args)}")

    def run_command(
        self,
        args: list[str],
        *,
        cwd: Path | None = None,
        env: dict[str, str] | None = None,
        capture_output: bool = False,
        input_text: str | None = None,
        merge_stderr: bool = False,
        suppress_stderr: bool = False,
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

        print(f"$ {shlex.join(args)}")
        return subprocess.run(
            args,
            cwd=str(cwd or self.repo_root),
            env=env,
            input=input_text,
            text=True,
            stdout=stdout,
            stderr=stderr,
            check=False,
        )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Run repo-level chart e2e workflow logic")
    parser.add_argument("--base-sha", required=True)
    parser.add_argument("--head-sha", required=True)
    parser.add_argument("--base-ref", default="")
    parser.add_argument("--repo-root", default=str(Path(__file__).resolve().parents[2]))
    return parser


def main(argv: list[str]) -> int:
    parser = build_parser()
    args = parser.parse_args(argv[1:])

    workflow = RepoChartE2EWorkflow(
        repo_root=Path(args.repo_root).resolve(),
        base_sha=args.base_sha,
        head_sha=args.head_sha,
        base_ref=args.base_ref,
    )
    return workflow.run()
