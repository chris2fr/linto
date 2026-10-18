from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "lib" / "config.py"


class ShortcutConfigTests(unittest.TestCase):
    def run_config(self, config: str, action: str, *args: str) -> subprocess.CompletedProcess:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "lib").mkdir()
            (root / "lib" / "default.yml").write_text("{}\n", encoding="utf-8")
            path = root / "config.yml"
            path.write_text(config, encoding="utf-8")
            return subprocess.run(
                [sys.executable, MODULE_PATH, path, action, *args],
                capture_output=True,
                text=True,
                check=False,
            )

    def test_shortcut_aliases_resolve_to_group_commands(self):
        result = self.run_config(
            "groups:\n  tools: default\n"
            "shortcuts:\n  pretty: tools prettyprint\n",
            "aliases",
        )
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), "pretty\ttools\tprettyprint")

    def test_shortcut_aliases_reject_invalid_targets_or_names(self):
        for shortcuts in (
            "bad/name: tools print",
            "pretty: tools",
            "pretty: unknown print",
            "pretty: tools bad/name",
            "pretty: [tools, print]",
        ):
            with self.subTest(shortcuts=shortcuts):
                result = self.run_config(
                    f"groups:\n  tools: default\nshortcuts:\n  {shortcuts}\n",
                    "aliases",
                )
                self.assertEqual(result.returncode, 2)

    def test_group_mappings_no_longer_accept_shortcuts(self):
        result = self.run_config(
            "groups:\n  tools:\n    shortcuts: false\n", "aliases"
        )
        self.assertEqual(result.returncode, 2)

    def test_dispatcher_uses_only_explicit_shortcut_aliases(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "bin").mkdir()
            (root / "lib").mkdir()
            shutil.copy2(ROOT / "bin" / "linto", root / "bin" / "linto")
            shutil.copy2(MODULE_PATH, root / "lib" / "config.py")
            shutil.copy2(ROOT / "lib" / "default.yml", root / "lib" / "default.yml")
            (root / "config.yml").write_text(
                "groups:\n"
                "  alpha:\n"
                "    commands:\n"
                "      hidden:\n"
                "        enable: false\n"
                "  beta: default\n"
                "  gamma:\n"
                "    enable: false\n"
                "shortcuts:\n"
                "  selected: alpha listed\n"
                "  collision_alias: alpha collision\n"
                "  hyphen-name: alpha listed\n"
                "  beta_alias: beta other\n"
                "  disabled_alias: gamma disabled\n"
                "  hidden_alias: alpha hidden\n",
                encoding="utf-8",
            )

            for group, command, output in (
                ("alpha", "listed", "alpha-listed"),
                ("alpha", "collision", "alpha-collision"),
                ("alpha", "hidden", "alpha-hidden"),
                ("beta", "collision", "beta-collision"),
                ("beta", "other", "beta-other"),
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
            self.assertEqual(
                shortcuts.stdout.splitlines(),
                ["beta_alias", "collision_alias", "hyphen-name", "selected"],
            )
            for alias, expected in (
                ("selected", "alpha-listed"),
                ("collision_alias", "alpha-collision"),
                ("beta_alias", "beta-other"),
                ("linto-hyphen-name", "alpha-listed"),
            ):
                with self.subTest(alias=alias):
                    result = subprocess.run(
                        [dispatcher, alias], capture_output=True, text=True, check=True
                    )
                    self.assertEqual(result.stdout.strip(), expected)

            qualified = subprocess.run(
                [dispatcher, "beta", "collision"],
                capture_output=True,
                text=True,
                check=True,
            )
            self.assertEqual(qualified.stdout.strip(), "beta-collision")
            listed_commands = subprocess.run(
                [dispatcher, "--list-commands", "alpha"],
                capture_output=True,
                text=True,
                check=True,
            )
            self.assertNotIn("hidden", listed_commands.stdout.splitlines())
            hidden = subprocess.run(
                [dispatcher, "alpha", "hidden"],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(hidden.returncode, 2)
            for command in ("listed", "collision", "other", "disabled_alias", "hidden_alias"):
                with self.subTest(command=command):
                    result = subprocess.run(
                        [dispatcher, command], capture_output=True, text=True, check=False
                    )
                    self.assertEqual(result.returncode, 2)


if __name__ == "__main__":
    unittest.main()
