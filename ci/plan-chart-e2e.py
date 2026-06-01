#!/usr/bin/env python3
"""Plan chart e2e targets from changed files and registry metadata."""

from __future__ import annotations

import sys

from chart_e2e.targets_cli import main


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv))
    except KeyboardInterrupt:
        sys.exit(130)
    except Exception as exc:  # pragma: no cover - defensive CLI guard
        print(str(exc), file=sys.stderr)
        sys.exit(1)
