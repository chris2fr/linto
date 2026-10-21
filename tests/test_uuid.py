import importlib.util
import unittest
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("uuid_cmd", ROOT / "groups" / "utils" / "lib" / "uuid_cmd.py")
uuid_cmd = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(uuid_cmd)


class UuidTests(unittest.TestCase):
    def test_versions(self):
        for version in (1, 4, 7):
            value = uuid_cmd.generate(version)
            self.assertEqual(value.version, version)
            self.assertEqual(value.variant, uuid.RFC_4122)

    def test_version_7_is_time_ordered(self):
        values = [uuid_cmd.uuid7() for _ in range(5)]
        self.assertEqual([v.int >> 80 for v in values], sorted(v.int >> 80 for v in values))


if __name__ == "__main__":
    unittest.main()
