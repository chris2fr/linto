from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "lib" / "config.py"


class ShortcutConfigTests(unittest.TestCase):
    def run_options(self, groups: str, group: str) -> subprocess.CompletedProcess:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "config.yml"
            path.write_text(f"groups:\n{groups}", encoding="utf-8")
            return subprocess.run(
                [sys.executable, MODULE_PATH, path, "options", group],
                capture_output=True,
                text=True,
                check=False,
            )

    def test_shortcuts_default_to_true(self):
        for group in ("tools", "mapped"):
            with self.subTest(group=group):
                result = self.run_options("  tools: default\n  mapped: {}\n", group)
                self.assertEqual(result.returncode, 0)
                self.assertEqual(result.stdout.strip(), "true\ntrue")

    def test_shortcuts_list_selects_named_commands(self):
        result = self.run_options(
            "  tools:\n    shortcuts:\n      - first-command\n      - second_command\n",
            "tools",
        )
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), "true\nlist\nfirst-command\nsecond_command")

    def test_shortcuts_accept_boolean_values(self):
        enabled = self.run_options("  enabled:\n    shortcuts: true\n", "enabled")
        disabled = self.run_options("  disabled:\n    shortcuts: false\n", "disabled")
        self.assertEqual(enabled.stdout.strip(), "true\ntrue")
        self.assertEqual(disabled.stdout.strip(), "true\nfalse")

    def test_shortcut_list_rejects_invalid_or_duplicate_names(self):
        for shortcuts in ("[42]", "[bad/name]", "[same, same]"):
            with self.subTest(shortcuts=shortcuts):
                result = self.run_options(
                    f"  tools:\n    shortcuts: {shortcuts}\n", "tools"
                )
                self.assertEqual(result.returncode, 2)

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
                "    shortcuts: [other]\n"
                "  gamma:\n"
                "    shortcuts: false\n",
                encoding="utf-8",
            )

            for group, command, output in (
                ("alpha", "listed", "alpha-listed"),
                ("alpha", "collision", "alpha-collision"),
                ("alpha", "hidden", "alpha-hidden"),
                ("beta", "collision", "beta-collision"),
                ("beta", "other", "beta-other"),
                ("beta", "unselected", "beta-unselected"),
                ("gamma", "disabled", "gamma-disabled"),
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
            self.assertEqual(shortcuts.stdout.splitlines(), ["listed", "other"])
            self.assertEqual(
                subprocess.run([dispatcher, "listed"], capture_output=True, text=True, check=True).stdout.strip(),
                "alpha-listed",
            )
            self.assertEqual(
                subprocess.run([dispatcher, "alpha", "collision"], capture_output=True, text=True, check=True).stdout.strip(),
                "alpha-collision",
            )
            for group, command, expected in (
                ("alpha", "collision", "alpha-collision"),
                ("beta", "collision", "beta-collision"),
                ("beta", "unselected", "beta-unselected"),
                ("gamma", "disabled", "gamma-disabled"),
            ):
                with self.subTest(group=group, command=command):
                    result = subprocess.run(
                        [dispatcher, group, command], capture_output=True, text=True, check=True
                    )
                    self.assertEqual(result.stdout.strip(), expected)
            for command in ("collision", "hidden", "unselected", "disabled"):
                with self.subTest(command=command):
                    result = subprocess.run(
                        [dispatcher, command], capture_output=True, text=True, check=False
                    )
                    self.assertEqual(result.returncode, 2)


if __name__ == "__main__":
    unittest.main()
