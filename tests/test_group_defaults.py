import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import textwrap
import unittest
from unittest.mock import patch


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
        self.assertEqual(config.configdata(data, "linto")["aliases"]["zz"], "linto launch zed")

    def test_cli_defaults_are_anchored_to_install_when_config_is_elsewhere(self):
        with tempfile.TemporaryDirectory() as directory:
            config_path = Path(directory) / "project" / "config.yml"
            config_path.parent.mkdir()
            config_path.write_text("groups:\n  quarto: default\n", encoding="utf-8")
            environment = os.environ.copy()
            environment["HOME"] = directory
            result = subprocess.run(
                [sys.executable, ROOT / "lib" / "config.py", config_path, "quarto-extension"],
                capture_output=True,
                text=True,
                check=False,
                env=environment,
                cwd=directory,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue(result.stdout.strip())

    def test_configdata_merge_and_command_enable(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "lib").mkdir()
            (root / "groups" / "demo" / "lib").mkdir(parents=True)
            (root / "lib" / "default.yml").write_text(
                "configdata:\n  shared: default\n  nested:\n    root: default\n", encoding="utf-8"
            )
            (root / "groups" / "demo" / "lib" / "default.yml").write_text(
                "configdata:\n  nested:\n    group: default\n", encoding="utf-8"
            )
            (root / "groups" / "demo" / "lib" / "run.yml").write_text(
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
            effective = config.effective_config(data)
            self.assertEqual(effective["configdata"]["shared"], "configured")
            self.assertEqual(
                effective["groups"]["demo"]["configdata"],
                {"nested": {"group": "configured"}},
            )
            self.assertEqual(
                effective["groups"]["demo"]["commands"]["run"]["configdata"],
                {"nested": {"command": "configured"}},
            )

    def test_external_system_and_user_configs_override_installation_settings(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            install = root / "install"
            project = root / "project"
            project_config = project / "config.yml"
            system_config = root / "etc-linto.yml"
            user_config = root / "home" / ".linto.yml"
            (install / "lib").mkdir(parents=True)
            project.mkdir()
            user_config.parent.mkdir()
            (install / "lib" / "default.yml").write_text(
                "configdata:\n  viewer: default\n", encoding="utf-8"
            )
            project_config.write_text(
                "groups:\n  demo:\n    configdata:\n      setting: installation\n",
                encoding="utf-8",
            )
            system_config.write_text(
                "configdata:\n  system-only: true\n"
                "groups:\n  demo:\n    configdata:\n      setting: system\n",
                encoding="utf-8",
            )
            user_config.write_text(
                "groups:\n  demo:\n    configdata:\n      setting: user\n",
                encoding="utf-8",
            )

            data = config.load(
                project_config,
                defaults_root=install,
                overlays=[system_config, user_config],
            )
            self.assertEqual(config.configdata(data)["viewer"], "default")
            self.assertTrue(config.configdata(data)["system-only"])
            self.assertEqual(config.configdata(data, "demo")["setting"], "user")

    def test_alias_defaults_are_extended_and_overridden(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "lib").mkdir()
            (root / "groups" / "linto" / "lib").mkdir(parents=True)
            (root / "lib" / "default.yml").write_text("{}\n", encoding="utf-8")
            (root / "groups" / "linto" / "lib" / "default.yml").write_text(
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

    def test_user_data_group_defaults_and_commands_are_loaded(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            install = root / "install"
            data_root = root / "data"
            custom_group = data_root / "groups" / "custom"
            (install / "lib").mkdir(parents=True)
            (custom_group / "lib").mkdir(parents=True)
            (install / "lib" / "default.yml").write_text("configdata: {}\n", encoding="utf-8")
            (custom_group / "lib" / "default.yml").write_text(
                "configdata:\n  setting: group-default\n", encoding="utf-8"
            )
            (custom_group / "lib" / "run.yml").write_text(
                "configdata:\n  command-setting: command-default\n", encoding="utf-8"
            )
            tool = custom_group / "run.sh"
            tool.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
            tool.chmod(0o755)
            config_path = root / "config.yml"
            config_path.write_text("groups:\n  custom: default\n", encoding="utf-8")

            data = config.load(config_path, defaults_root=install, data_root=data_root)
            self.assertEqual(
                config.configdata(data, "custom", "run"),
                {"setting": "group-default", "command-setting": "command-default"},
            )
            self.assertEqual(config.enabled_groups(data, install, data_root), ["custom"])

    def test_group_enablement_writes_only_to_xdg_user_config(self):
        with tempfile.TemporaryDirectory() as directory:
            config_home = Path(directory) / "config"
            config_home.mkdir()
            user_config = config_home / "linto" / "config.yml"
            with patch.dict(os.environ, {"XDG_CONFIG_HOME": str(config_home)}):
                config.set_user_group_enabled("custom", False)
                saved = config.read_yaml_mapping(user_config, "test user configuration")
                self.assertEqual(saved, {"groups": {"custom": {"enable": False}}})
                config.set_user_group_enabled("custom", True)
                saved = config.read_yaml_mapping(user_config, "test user configuration")
                self.assertEqual(saved, {"groups": {"custom": {"enable": True}}})


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
