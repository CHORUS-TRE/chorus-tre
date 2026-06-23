from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "ci"))

from chart_e2e.utils import config_bool, extract_block, helm_value_string, nested_get


class NestedGetTests(unittest.TestCase):
    def test_returns_nested_value(self) -> None:
        mapping = {"chart": {"health_check": {"port": 5432}}}
        self.assertEqual(nested_get(mapping, "chart.health_check.port"), 5432)

    def test_returns_default_for_missing_key(self) -> None:
        mapping = {"chart": {"health_check": {}}}
        self.assertEqual(nested_get(mapping, "chart.health_check.path", "/"), "/")


class HelmValueStringTests(unittest.TestCase):
    def test_formats_boolean_and_null_values(self) -> None:
        self.assertEqual(helm_value_string(True), "true")
        self.assertEqual(helm_value_string(False), "false")
        self.assertEqual(helm_value_string(None), "null")

    def test_formats_other_values_as_strings(self) -> None:
        self.assertEqual(helm_value_string(5432), "5432")
        self.assertEqual(helm_value_string("postgres"), "postgres")


class ConfigBoolTests(unittest.TestCase):
    def test_accepts_bool_string_and_int_values(self) -> None:
        self.assertTrue(config_bool(True))
        self.assertTrue(config_bool("TRUE"))
        self.assertTrue(config_bool(1))
        self.assertFalse(config_bool(False))
        self.assertFalse(config_bool("false"))
        self.assertFalse(config_bool(0))

    def test_rejects_unsupported_strings(self) -> None:
        with self.assertRaises(ValueError):
            config_bool("sometimes")


class ExtractBlockTests(unittest.TestCase):
    def test_extracts_text_between_markers(self) -> None:
        text = "prefix\n__START__\nhello\nworld\n__END__\nsuffix"
        self.assertEqual(extract_block(text, "__START__\n", "__END__"), "hello\nworld")

    def test_returns_empty_string_when_marker_missing(self) -> None:
        self.assertEqual(extract_block("no markers here", "__START__", "__END__"), "")


if __name__ == "__main__":
    unittest.main()
