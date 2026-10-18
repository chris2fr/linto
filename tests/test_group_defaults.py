import importlib.util
from pathlib import Path
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("linto_config", ROOT / "lib" / "config.py")
assert SPEC and SPEC.loader
config = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(config)


class GroupDefaultsTests(unittest.TestCase):
    def load_config(self, text: str) -> dict:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "config.yml"
            path.write_text(text, encoding="utf-8")
            return config.load(path)

    def test_quarto_extension_comes_from_defaults(self):
        data = self.load_config(
            "groups:\n  quarto: default\n  linto: default\n"
        )
        self.assertEqual(config.quarto_extension(data), "chris2fr/quarto")
        self.assertEqual(
            config.group_options(data, "linto")["aliases"],
            {
                "aliases": {"zz": "linto launch zed"},
                "unaliases": ["something-to-delete-from-aliases"],
            },
        )

    def test_group_values_override_defaults(self):
        data = self.load_config(
            "groups:\n"
            "  quarto:\n"
            "    extension: example.org/custom\n"
            "  linto:\n"
            "    aliases:\n"
            "      aliases:\n"
            "        zz: custom command\n"
            "        extra: linto launch zed\n"
        )
        self.assertEqual(config.quarto_extension(data), "example.org/custom")
        self.assertEqual(
            config.group_options(data, "linto")["aliases"],
            {
                "aliases": {"zz": "custom command", "extra": "linto launch zed"},
                "unaliases": ["something-to-delete-from-aliases"],
            },
        )

    def test_legacy_top_level_quarto_setting_is_rejected(self):
        with self.assertRaises(ValueError):
            self.load_config(
                "groups:\n  quarto: default\n"
                "quarto:\n  extension: example.org/legacy\n"
            )


if __name__ == "__main__":
    unittest.main()
