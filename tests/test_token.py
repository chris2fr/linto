import importlib.util
import string
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("token_cmd", ROOT / "groups" / "utils" / "lib" / "tokencmd.py")
token = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(token)


class TokenTests(unittest.TestCase):
    def test_length_and_each_enabled_class_present(self):
        chosen = token.classes(True, True, True, True)
        for _ in range(50):
            value = token.generate(8, chosen)
            self.assertEqual(len(value), 8)
            for cls in chosen:
                self.assertTrue(any(c in cls for c in value), value)

    def test_disabled_classes_are_absent(self):
        chosen = token.classes(False, True, True, False)
        value = token.generate(200, chosen)
        self.assertTrue(set(value) <= set(string.ascii_lowercase + string.digits))

    def test_symbols_are_off_by_default(self):
        chosen = token.classes(True, True, True, False)
        self.assertFalse(set("".join(chosen)) & set(token.SYMBOLS))


if __name__ == "__main__":
    unittest.main()
