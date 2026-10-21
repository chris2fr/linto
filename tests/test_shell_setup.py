import importlib.util
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import ANY, call, patch
from contextlib import redirect_stdout
from io import StringIO


ROOT = Path(__file__).resolve().parents[1]
ALIASES_PATH = ROOT / "groups" / "linto" / "lib" / "aliases.py"
SPEC = importlib.util.spec_from_file_location("linto_aliases", ALIASES_PATH)
assert SPEC and SPEC.loader
aliases = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(aliases)


class AliasShellTests(unittest.TestCase):
    def test_current_shell_detection_skips_linto_shell_wrappers(self):
        process_info = [
            ("sh", ["sh", str(ROOT / "groups" / "linto" / "aliases.sh")], 101),
            ("fish", ["fish"], 1),
        ]
        with patch.dict(os.environ, {"SHELL": "/usr/bin/bash"}), \
             patch.object(aliases.os, "getppid", return_value=100), \
             patch.object(aliases, "_process_info", side_effect=process_info):
            self.assertEqual(aliases.detect_current_shell(), "fish")

    def test_all_targets_every_supported_shell(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            environment = {
                "HOME": str(home),
                "XDG_CONFIG_HOME": str(home / "config"),
                "XDG_DATA_HOME": str(home / "data"),
                "SHELL": "/usr/bin/bash",
            }
            with patch.dict(os.environ, environment), \
                 patch.object(sys, "argv", [str(ALIASES_PATH), "--shell", "all"]), \
                 patch.object(aliases, "update_fish_aliases") as fish_update, \
                 patch.object(aliases, "update_sh_aliases") as sh_update, \
                 patch.object(aliases, "update_ksh_profile") as ksh_profile, \
                 redirect_stdout(StringIO()):
                self.assertEqual(aliases.main(), 0)

            fish_update.assert_called_once()
            self.assertEqual(
                sh_update.call_args_list,
                [
                    call(home / ".bashrc", ANY),
                    call(home / ".profile", ANY),
                    call(home / ".kshrc", ANY),
                    call(home / ".zshrc", ANY),
                ],
            )
            ksh_profile.assert_called_once_with(home / ".profile")

    def test_sh_aliases_replace_the_managed_block_and_quote_values(self):
        with tempfile.TemporaryDirectory() as directory:
            rc = Path(directory) / ".bashrc"
            rc.write_text(
                "# keep this line\n"
                "# >>> linto aliases begin >>>\n"
                "alias old='stale'\n"
                "# >>> linto aliases end >>>\n",
                encoding="utf-8",
            )
            aliases.update_sh_aliases(rc, {"quoted": "say 'hello'"})
            aliases.update_sh_aliases(rc, {"quoted": "say 'hello'"})
            content = rc.read_text(encoding="utf-8")
            self.assertIn("# keep this line", content)
            expected = "alias quoted=" + aliases._shell_quote("say 'hello'") + "\n"
            self.assertIn(expected, content)
            self.assertEqual(content.count("# >>> linto aliases begin >>>"), 1)
            self.assertNotIn("alias old=", content)


class ShellSetupTests(unittest.TestCase):
    def test_bash_and_zsh_setup_install_completion_correctly(self):
        bash = shutil.which("bash")
        zsh = shutil.which("zsh")
        if not bash or not zsh:
            self.skipTest("bash and zsh are required for this integration test")

        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            zdotdir = home / "zsh"
            zdotdir.mkdir()
            zshrc = zdotdir / ".zshrc"
            zshrc.write_text("autoload -Uz compinit && compinit\n", encoding="utf-8")
            environment = os.environ.copy()
            environment.update(
                HOME=str(home),
                ZDOTDIR=str(zdotdir),
                SHELL="/usr/bin/fish",
                XDG_CONFIG_HOME=str(home / "config"),
                XDG_DATA_HOME=str(home / "data"),
            )

            for target in ("zsh", "bash"):
                result = subprocess.run(
                    [bash, ROOT / "groups" / "linto" / "setup.sh", "--shell", target],
                    capture_output=True,
                    text=True,
                    env=environment,
                )
                self.assertEqual(result.returncode, 0, result.stderr)

            zsh_lines = zshrc.read_text(encoding="utf-8").splitlines()
            fpath_line = next(i for i, line in enumerate(zsh_lines) if "fpath=(" in line)
            compinit_line = next(i for i, line in enumerate(zsh_lines) if "compinit" in line)
            self.assertLess(fpath_line, compinit_line)

            bashrc = home / ".bashrc"
            bash_result = subprocess.run(
                [bash, "--noprofile", "--rcfile", bashrc, "-ic", "complete -p linto"],
                capture_output=True,
                text=True,
                env=environment,
            )
            self.assertEqual(bash_result.returncode, 0, bash_result.stderr)
            self.assertIn("complete -F _linto_complete linto", bash_result.stdout)

            zsh_result = subprocess.run(
                [zsh, "-ic", "autoload -Uz _linto; whence -w _linto"],
                capture_output=True,
                text=True,
                env=environment,
            )
            self.assertEqual(zsh_result.returncode, 0, zsh_result.stderr)
            self.assertIn("_linto", zsh_result.stdout)

    def test_setup_detects_invoking_shell_before_shell_environment(self):
        startup_files = {"bash": ".bashrc", "zsh": ".zshrc", "ksh": ".kshrc", "sh": ".profile"}
        for shell in startup_files:
            if shutil.which(shell) is None:
                continue
            with self.subTest(shell=shell), tempfile.TemporaryDirectory() as directory:
                home = Path(directory)
                environment = os.environ.copy()
                environment.update(
                    HOME=str(home),
                    SHELL="/usr/bin/fish",
                    XDG_CONFIG_HOME=str(home / "config"),
                    XDG_DATA_HOME=str(home / "data"),
                )
                result = subprocess.run(
                    [shell, "-c", f"{ROOT / 'groups' / 'linto' / 'setup.sh'}; true"],
                    capture_output=True,
                    text=True,
                    env=environment,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(f"Configured Linto for {shell} ", result.stdout)
                startup_file = home / startup_files[shell]
                self.assertIn("linto", startup_file.read_text(encoding="utf-8"))

    def test_ksh_and_sh_setup_add_path_without_completion(self):
        bash = shutil.which("bash")
        if not bash:
            self.skipTest("bash is required to run setup.sh")

        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            environment = os.environ.copy()
            environment.update(
                HOME=str(home),
                SHELL="/usr/bin/fish",
                XDG_CONFIG_HOME=str(home / "config"),
                XDG_DATA_HOME=str(home / "data"),
            )
            for target in ("ksh", "sh", "ksh"):
                result = subprocess.run(
                    [bash, ROOT / "groups" / "linto" / "setup.sh", "--shell", target],
                    capture_output=True,
                    text=True,
                    env=environment,
                )
                self.assertEqual(result.returncode, 0, result.stderr)

            kshrc = (home / ".kshrc").read_text(encoding="utf-8")
            profile = (home / ".profile").read_text(encoding="utf-8")
            self.assertEqual(kshrc.count("export PATH="), 1)
            self.assertNotIn("completion", kshrc)
            self.assertEqual(profile.count("export PATH="), 1)
            self.assertEqual(profile.count("export ENV="), 1)


if __name__ == "__main__":
    unittest.main()
