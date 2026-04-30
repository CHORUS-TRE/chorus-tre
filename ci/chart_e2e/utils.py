"""Utility helpers for the chart e2e runner."""

from __future__ import annotations

import re
from typing import Any


TRUTHY_STRINGS = {"1", "true", "yes", "on"}
FALSY_STRINGS = {"0", "false", "no", "off", ""}


def nested_get(mapping: dict[str, Any], dotted_key: str, default: Any = None) -> Any:
    value: Any = mapping
    for part in dotted_key.split("."):
        if not isinstance(value, dict) or part not in value:
            return default
        value = value[part]
    return value if value is not None else default


def helm_value_string(value: Any) -> str:
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    return str(value)


def config_bool(value: Any, *, default: bool = False) -> bool:
    if value is None:
        return default
    if isinstance(value, bool):
        return value
    if isinstance(value, int):
        if value in (0, 1):
            return bool(value)
        raise ValueError(f"Unsupported integer boolean value: {value!r}")
    if isinstance(value, str):
        normalized = value.strip().lower()
        if normalized in TRUTHY_STRINGS:
            return True
        if normalized in FALSY_STRINGS:
            return False
        raise ValueError(f"Unsupported string boolean value: {value!r}")
    raise ValueError(f"Unsupported boolean value type: {type(value).__name__}")


def lines_preview(text: str, limit: int = 20) -> str:
    preview = " ".join(text.splitlines()[:limit])
    return re.sub(r"\s+", " ", preview).strip()


def extract_block(text: str, start_marker: str, end_marker: str) -> str:
    start = text.find(start_marker)
    if start == -1:
        return ""
    start += len(start_marker)
    end = text.find(end_marker, start)
    if end == -1:
        return text[start:].strip()
    return text[start:end].strip()
