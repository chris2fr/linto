import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "lib" / "config.py"
sys.path.insert(0, str(ROOT / "lib"))
import config


class ShortcutConfigTests(unittest.TestCase):
    def load_config(self, groups: str) -> dict:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "config.yml"
            path.write_text(f"groups:\n{groups}", encoding="utf-8")
            return config.load(path)

    def test_shortcuts_default_to_true(self):
        data = self.load_config("  tools: default\n  mapped: {}\n")
        self.assertTrue(config.group_options(data, "tools")["shortcuts"])
        self.assertTrue(config.group_options(data, "mapped")["shortcuts"])

    def test_shortcuts_list_selects_named_commands(self):
        data = self.load_config(
            "  tools:\n    shortcuts:\n      - first-command\n      - second_command\n"
        )
        self.assertEqual(
            config.group_options(data, "tools")["shortcuts"],
            ["first-command", "second_command"],
        )

    def test_shortcuts_accept_boolean_values(self):
        data = self.load_config(
            "  enabled:\n    shortcuts: true\n  disabled:\n    shortcuts: false\n"
        )
        self.assertTrue(config.group_options(data, "enabled")["shortcuts"])
        self.assertFalse(config.group_options(data, "disabled")["shortcuts"])

    def test_shortcut_list_rejects_invalid_or_duplicate_names(self):
        for shortcuts in ("[42]", "[bad/name]", "[same, same]"):
            with self.subTest(shortcuts=shortcuts), self.assertRaises(ValueError):
                self.load_config(f"  tools:\n    shortcuts: {shortcuts}\n")

    def test_dispatcher_obeys_selected_shortcuts_and_uniqueness(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "bin").mkdir()
            (root / "lib").mkdir()
            shutil.copy2(ROOT / "bin" / "linto", root / "bin" / "linto")
            shutil.copy2(MODULE_PATH, root / "lib" / "config.py")
            (root / "config.yml").write_text(
                "groups:\n"
                "  alpha:\n"
                "    shortcuts: [listed, collision]\n"
                "  beta:\n"
                "    shortcuts: false\n",
                encoding="utf-8",
            )

            for group, command, output in (
                ("alpha", "listed", "alpha-listed"),
                ("alpha", "collision", "alpha-collision"),
                ("alpha", "hidden", "alpha-hidden"),
                ("beta", "collision", "beta-collision"),
                ("beta", "disabled", "beta-disabled"),
            ):
                group_dir = root / group
                group_dir.mkdir(exist_ok=True)
                tool = group_dir / f"{command}.sh"
                tool.write_text(f"#!/bin/sh\nprintf '%s\\n' '{output}'\n", encoding="utf-8")
                tool.chmod(0o755)

            dispatcher = root / "bin" / "linto"
            shortcuts = subprocess.run(
                [dispatcher, "--list-shortcuts"], capture_output=True, text=True, check=True
            )
            self.assertEqual(shortcuts.stdout.strip(), "listed")
            self.assertEqual(
                subprocess.run([dispatcher, "listed"], capture_output=True, text=True, check=True).stdout.strip(),
                "alpha-listed",
            )
            self.assertEqual(
                subprocess.run([dispatcher, "alpha", "collision"], capture_output=True, text=True, check=True).stdout.strip(),
                "alpha-collision",
            )
            for command in ("collision", "hidden", "disabled"):
                with self.subTest(command=command):
                    result = subprocess.run(
                        [dispatcher, command], capture_output=True, text=True, check=False
                    )
                    self.assertEqual(result.returncode, 2)


if __name__ == "__main__":
    unittest.main()
