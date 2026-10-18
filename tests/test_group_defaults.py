import importlib.util
from pathlib import Path
import tempfile
import textwrap
import unittest


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("linto_config", ROOT / "lib" / "config.py")
assert SPEC and SPEC.loader
config = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(config)


class ConfigdataTests(unittest.TestCase):
    def test_shipped_defaults_are_loaded_at_each_level(self):
        data = config.load(ROOT / "config.yml")
        self.assertEqual(config.quarto_extension(data), "chris2fr/quarto")
        self.assertEqual(config.markdown_viewers(data)[0], "md-tui")
        self.assertEqual(
            config.configdata(data, "linto")["aliases"],
            {"zz": "linto launch zed"},
        )

    def test_configdata_merge_and_command_enable(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "lib").mkdir()
            (root / "demo" / "lib").mkdir(parents=True)
            (root / "lib" / "default.yml").write_text(
                "configdata:\n  shared: default\n  nested:\n    root: default\n", encoding="utf-8"
            )
            (root / "demo" / "lib" / "default.yml").write_text(
                "configdata:\n  nested:\n    group: default\n", encoding="utf-8"
            )
            (root / "demo" / "lib" / "run.yml").write_text(
                "configdata:\n  nested:\n    command: default\n", encoding="utf-8"
            )
            config_path = root / "config.yml"
            config_path.write_text(
                textwrap.dedent(
                    """\
                    configdata:
                      shared: configured
                    groups:
                      demo:
                        configdata:
                          nested:
                            group: configured
                        commands:
                          run:
                            enable: false
                            configdata:
                              nested:
                                command: configured
                    """
                ),
                encoding="utf-8",
            )

            data = config.load(config_path)
            self.assertEqual(
                config.configdata(data, "demo", "run"),
                {
                    "shared": "configured",
                    "nested": {
                        "root": "default",
                        "group": "configured",
                        "command": "configured",
                    },
                },
            )
            self.assertFalse(config.command_options(data, "demo", "run")["enable"])
            self.assertTrue(config.command_options(data, "demo", "other")["enable"])
            self.assertEqual(config.configdata(data)["shared"], "configured")

    def test_alias_defaults_are_extended_and_overridden(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "lib").mkdir()
            (root / "linto" / "lib").mkdir(parents=True)
            (root / "lib" / "default.yml").write_text("{}\n", encoding="utf-8")
            (root / "linto" / "lib" / "default.yml").write_text(
                "configdata:\n  aliases:\n    zz: default\n    keep: default\n",
                encoding="utf-8",
            )
            config_path = root / "config.yml"
            config_path.write_text(
                "groups:\n  linto:\n    configdata:\n      aliases:\n"
                "        zz: custom\n        new: custom\n",
                encoding="utf-8",
            )
            data = config.load(config_path)
            self.assertEqual(
                config.configdata(data, "linto")["aliases"],
                {"zz": "custom", "keep": "default", "new": "custom"},
            )

    def test_legacy_configuration_locations_and_unaliases_are_rejected(self):
        for text in (
            "groups:\n  quarto: default\nquarto:\n  extension: old/repo\n",
            "groups:\n  quarto: default\nmarkdown-viewer: cat\n",
            "groups:\n  linto:\n    configdata:\n      aliases:\n        unaliases: [old]\n",
        ):
            with self.subTest(text=text), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                (root / "lib").mkdir()
                (root / "lib" / "default.yml").write_text("configdata: {}\n", encoding="utf-8")
                path = root / "config.yml"
                path.write_text(text, encoding="utf-8")
                with self.assertRaises(ValueError):
                    config.load(path)


if __name__ == "__main__":
    unittest.main()
