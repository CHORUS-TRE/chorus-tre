"""Target planning for chart e2e workflow selection and warning semantics."""

from __future__ import annotations

import json
import re
import subprocess
from collections import deque
from dataclasses import dataclass, field
from pathlib import Path, PurePosixPath


DIRECTLY_MODIFIED_REASON = "directly modified"
CHART_TEST_CONFIG_REASON = "chart test config modified"
CI_INFRA_CHANGED_REASON = "CI infrastructure changed - full registered chart sweep"
WORKFLOW_PATH = ".github/workflows/e2e-chart-testing.yml"


@dataclass
class PlannedTarget:
    chart_path: str
    reasons: list[str] = field(default_factory=list)

    @property
    def chart_name(self) -> str:
        return PurePosixPath(self.chart_path).name

    @property
    def reason_text(self) -> str:
        return "; ".join(self.reasons)

    @property
    def failure_mode(self) -> str:
        has_reverse_reason = any("reverse dependent" in reason for reason in self.reasons)
        is_direct = DIRECTLY_MODIFIED_REASON in self.reasons
        is_ci_sweep = CI_INFRA_CHANGED_REASON in self.reasons
        return "warning" if has_reverse_reason and not is_direct and not is_ci_sweep else "error"


class TargetPlanner:
    def __init__(self, registry_file: Path) -> None:
        self.registry_file = registry_file
        self.registry = self._load_registry()
        self.charts = self.registry.get("charts", {})

    def _load_registry(self) -> dict:
        result = subprocess.run(
            ["yq", "-o=json", ".", str(self.registry_file)],
            check=False,
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            raise RuntimeError(result.stderr.strip() or result.stdout.strip() or "Failed to load registry")
        return json.loads(result.stdout or "{}")

    def is_registered(self, chart_name: str) -> bool:
        return chart_name in self.charts

    def is_skipped(self, chart_name: str) -> bool:
        value = self.charts.get(chart_name, {}).get("skip_deploy", False)
        if isinstance(value, bool):
            return value
        return str(value).lower() == "true"

    def reverse_dependents_of(self, dependency_chart: str) -> list[str]:
        dependents: list[str] = []
        for chart_name, chart_config in self.charts.items():
            depends_on = chart_config.get("depends_on") or []
            if dependency_chart in depends_on:
                dependents.append(chart_name)
        return sorted(dependents)

    def registered_non_skipped_chart_paths(self) -> list[str]:
        return sorted(f"charts/{chart_name}" for chart_name in self.charts if not self.is_skipped(chart_name))

    def plan(self, changed_files_raw: str) -> list[PlannedTarget]:
        changed_files = self._parse_changed_files(changed_files_raw)
        direct_chart_paths = self._extract_direct_chart_paths(changed_files)
        chart_test_paths = self._extract_chart_test_paths(changed_files)
        modified_chart_paths = sorted(set(direct_chart_paths + chart_test_paths))

        targets: dict[str, PlannedTarget] = {}

        if not modified_chart_paths:
            if self._has_ci_infra_changes(changed_files):
                for chart_path in self.registered_non_skipped_chart_paths():
                    self._add_reason(targets, chart_path, CI_INFRA_CHANGED_REASON)
            return self._sorted_targets(targets)

        for chart_path in direct_chart_paths:
            self._add_reason(targets, chart_path, DIRECTLY_MODIFIED_REASON)

        for chart_path in chart_test_paths:
            self._add_reason(targets, chart_path, CHART_TEST_CONFIG_REASON)

        for chart_path in modified_chart_paths:
            self._collect_reverse_dependents(targets, chart_path)

        return self._sorted_targets(targets)

    def _collect_reverse_dependents(self, targets: dict[str, PlannedTarget], modified_chart_path: str) -> None:
        modified_chart_name = PurePosixPath(modified_chart_path).name
        if not self.is_registered(modified_chart_name):
            return

        queue: deque[tuple[str, str]] = deque([(modified_chart_name, "")])
        seen = {modified_chart_name}

        while queue:
            current_chart, current_chain = queue.popleft()
            for dependent_chart in self.reverse_dependents_of(current_chart):
                if dependent_chart in seen:
                    continue
                seen.add(dependent_chart)

                dependent_path = f"charts/{dependent_chart}"
                if current_chain:
                    reason = f"reverse dependent of modified {modified_chart_name} via {current_chain}"
                    next_chain = f"{current_chain} -> {dependent_chart}"
                else:
                    reason = f"reverse dependent of modified {modified_chart_name}"
                    next_chain = dependent_chart

                if not self.is_skipped(dependent_chart):
                    self._add_reason(targets, dependent_path, reason)

                queue.append((dependent_chart, next_chain))

    @staticmethod
    def _sorted_targets(targets: dict[str, PlannedTarget]) -> list[PlannedTarget]:
        return [targets[chart_path] for chart_path in sorted(targets)]

    @staticmethod
    def _add_reason(targets: dict[str, PlannedTarget], chart_path: str, reason: str) -> None:
        target = targets.setdefault(chart_path, PlannedTarget(chart_path=chart_path))
        if reason not in target.reasons:
            target.reasons.append(reason)

    @staticmethod
    def _parse_changed_files(changed_files_raw: str) -> list[str]:
        return [part for part in re.split(r"[\s,]+", changed_files_raw.strip()) if part]

    @staticmethod
    def _extract_direct_chart_paths(changed_files: list[str]) -> list[str]:
        chart_paths = set()
        for changed_file in changed_files:
            path = PurePosixPath(changed_file)
            if len(path.parts) >= 3 and path.parts[0] == "charts":
                chart_paths.add(f"charts/{path.parts[1]}")
        return sorted(chart_paths)

    @staticmethod
    def _extract_chart_test_paths(changed_files: list[str]) -> list[str]:
        chart_paths = set()
        for changed_file in changed_files:
            path = PurePosixPath(changed_file)
            if path.parts[:3] == ("ci", "chart-tests", "charts") and path.suffix in {".yaml", ".yml"}:
                chart_paths.add(f"charts/{path.stem}")
        return sorted(chart_paths)

    @staticmethod
    def _has_ci_infra_changes(changed_files: list[str]) -> bool:
        for changed_file in changed_files:
            if changed_file.startswith("ci/") or changed_file == WORKFLOW_PATH:
                return True
        return False


def write_targets_file(targets: list[PlannedTarget], target_file: Path) -> None:
    lines = [f"{target.chart_path}\t{target.failure_mode}\t{target.reason_text}" for target in targets]
    target_file.write_text("\n".join(lines) + ("\n" if lines else ""), encoding="utf-8")


def write_step_summary(targets: list[PlannedTarget], summary_file: Path) -> None:
    if not targets:
        return
    with summary_file.open("a", encoding="utf-8") as handle:
        handle.write("### Chart E2E Targets\n\n")
        handle.write(
            "Reverse dependents are included so dependency updates show which services could break; reverse-only impacted checks warn instead of failing the job.\n\n"
        )
        for target in targets:
            handle.write(f"- {target.chart_name}: {target.reason_text}\n")


def write_github_outputs(targets: list[PlannedTarget], target_file: Path, github_output: Path) -> None:
    charts_value = " ".join(target.chart_path for target in targets)
    with github_output.open("a", encoding="utf-8") as handle:
        handle.write(f"charts={charts_value}\n")
        if targets:
            handle.write(f"targets_file={target_file}\n")
