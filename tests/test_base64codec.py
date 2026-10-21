import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("base64codec", ROOT / "groups" / "utils" / "lib" / "base64codec.py")
b64 = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(b64)


class Base64Tests(unittest.TestCase):
    def test_encode(self):
        self.assertEqual(b64.encode("héllo?>".encode()), "aMOpbGxvPz4=")

    def test_urlsafe_and_no_padding(self):
        self.assertEqual(b64.encode(b"\xfb\xff", urlsafe=True, padding=False), "-_8")
        self.assertEqual(b64.encode(b"\xfb\xff"), "+/8=")

    def test_decode_accepts_missing_padding_and_whitespace(self):
        self.assertEqual(b64.decode("aMOp\nbGxv Pz4"), "héllo?>".encode())
        self.assertEqual(b64.decode("-_8", urlsafe=True), b"\xfb\xff")

    def test_invalid_input_raises(self):
        with self.assertRaises(ValueError):
            b64.decode("!!!")


if __name__ == "__main__":
    unittest.main()
