"""CLI entry helpers for chart e2e target planning."""

from __future__ import annotations

import argparse
from pathlib import Path

from .targets import TargetPlanner, write_github_outputs, write_step_summary, write_targets_file


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Plan chart e2e targets from changed files")
    parser.add_argument("--registry-file", required=True)
    parser.add_argument("--changed-files", default="")
    parser.add_argument("--targets-file")
    parser.add_argument("--github-output")
    parser.add_argument("--step-summary")
    return parser


def main(argv: list[str]) -> int:
    parser = build_parser()
    args = parser.parse_args(argv[1:])

    planner = TargetPlanner(Path(args.registry_file))
    targets = planner.plan(args.changed_files)
    target_file = Path(args.targets_file) if args.targets_file else None

    if target_file is not None:
        write_targets_file(targets, target_file)
    if args.github_output and target_file is not None:
        write_github_outputs(targets, target_file, Path(args.github_output))
    if args.step_summary:
        write_step_summary(targets, Path(args.step_summary))

    if not targets:
        print("No charts to test.")
        return 0

    print("Chart test target reasons:")
    for target in targets:
        print(f"  - {target.chart_name}: {target.reason_text}")
    print(f"Charts to test: {' '.join(target.chart_path for target in targets)}")
    return 0
