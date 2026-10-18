import importlib.util
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "groups" / "utils" / "lib" / "timezone.py"
SPEC = importlib.util.spec_from_file_location("timezone", MODULE_PATH)
timezone = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(timezone)


class TimezoneTests(unittest.TestCase):
    def test_convert_named_zones_and_keep_minutes_precision(self):
        self.assertEqual(
            timezone.generate_biblatex_date(
                "2027-12-28T12:30", "UTC", "Europe/Paris"
            ),
            "2027-12-28T11:30Z",
        )

    def test_keep_seconds_and_fractional_precision(self):
        self.assertEqual(
            timezone.generate_biblatex_date(
                "2027-12-28T12:30:45.120", "UTC", "Europe/Paris"
            ),
            "2027-12-28T11:30:45.12Z",
        )

    def test_explicit_input_offset_overrides_source_zone(self):
        self.assertEqual(
            timezone.generate_biblatex_date(
                "2027-12-28T12:30-02:00", "UTC", "Europe/Paris"
            ),
            "2027-12-28T14:30Z",
        )

    def test_non_utc_zero_offset_uses_numeric_offset(self):
        self.assertEqual(
            timezone.generate_biblatex_date(
                "2027-12-28T12:30Z", "Etc/GMT", "Europe/Paris"
            ),
            "2027-12-28T12:30+00:00",
        )

    def test_unknown_zone_is_reported(self):
        with self.assertRaisesRegex(ValueError, "unknown .* time zone"):
            timezone.generate_biblatex_date("2027-12-28", "Not/AZone")


if __name__ == "__main__":
    unittest.main()
