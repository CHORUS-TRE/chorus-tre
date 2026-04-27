"""CLI entry helpers for the chart e2e runner."""

from __future__ import annotations

from .runner import ChartE2ERunner


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print(f"Usage: {argv[0]} <chart_path> <chart_name>")
        print(f"  e.g.: {argv[0]} charts/i2b2-wildfly i2b2-wildfly")
        return 1

    runner = ChartE2ERunner(argv[1], argv[2])
    return runner.run()
