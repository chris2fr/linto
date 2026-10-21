import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("urlcodec", ROOT / "groups" / "utils" / "lib" / "urlcodec.py")
urlcodec = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(urlcodec)


class UrlCodecTests(unittest.TestCase):
    def test_encode_reserved_and_non_ascii(self):
        self.assertEqual(urlcodec.encode("é a/b&c"), "%C3%A9%20a%2Fb%26c")

    def test_safe_and_plus(self):
        self.assertEqual(urlcodec.encode("a b/c", safe="/", plus=True), "a+b/c")

    def test_decode(self):
        self.assertEqual(urlcodec.decode("caf%C3%A9+x%20y"), "café+x y")
        self.assertEqual(urlcodec.decode("caf%C3%A9+x%20y", plus=True), "café x y")

    def test_round_trip(self):
        text = "100% sûr ? oui & non = #1"
        self.assertEqual(urlcodec.decode(urlcodec.encode(text)), text)

    def test_invalid_utf8_raises(self):
        with self.assertRaises(UnicodeDecodeError):
            urlcodec.decode("%FF")


if __name__ == "__main__":
    unittest.main()
