import os
from pathlib import Path
import pty
import re
import select
import shutil
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
LINTO = ROOT / "bin" / "linto"


def complete(*words):
    result = subprocess.run(
        [LINTO, "--complete", *words], capture_output=True, text=True, check=True
    )
    return result.stdout.splitlines()


class DispatcherCompletionTests(unittest.TestCase):
    def test_nothing_while_the_cursor_is_on_a_group_or_command_name(self):
        self.assertEqual(complete("quarto"), [])
        self.assertEqual(complete("quarto", "ren"), [])
        self.assertEqual(complete("nonexistent", ""), [])

    def test_positional_arguments_are_matched_by_glob(self):
        self.assertEqual(complete("quarto", "render", ""), ["files\t*.qmd,*.md"])
        self.assertEqual(complete("linto-quarto-render", ""), ["files\t*.qmd,*.md"])
        self.assertEqual(complete("bib", "bib2json", ""), ["files\t*.bib"])

    def test_each_positional_argument_has_its_own_kind(self):
        self.assertEqual(complete("bib", "bibyml2bib", ""), ["files\t*.bib"])
        self.assertEqual(
            complete("bib", "bibyml2bib", "refs.bib", ""), ["files\t*.yml,*.yaml"]
        )
        self.assertEqual(complete("bib", "bibyml2bib", "refs.bib", "r.yml", ""), ["none"])

    def test_option_values_use_the_kind_of_the_option(self):
        self.assertEqual(complete("bib", "bib2json", "-j", ""), ["files\t*.json"])
        self.assertEqual(complete("bib", "bib2json", "-j", "in.json", ""), ["files\t*.bib"])
        self.assertEqual(complete("utils", "stripaccents", "-d", ""), ["dirs"])
        self.assertEqual(
            complete("bib", "bib2awk", "-f", ""), ["words", "csv", "sed", "bibs"]
        )

    def test_shortcuts_resolve_to_their_command(self):
        self.assertEqual(complete("prettyprint", "-f", ""), ["words", "classic", "outlined"])

    def test_dash_lists_the_options_of_the_command(self):
        reply = complete("bib", "bib2json", "-")
        self.assertEqual(reply[0], "words")
        names = [line.split("\t")[0] for line in reply[1:]]
        for option in ("-j", "--json", "-o", "--output", "-i", "-i.bak", "-h", "--help"):
            self.assertIn(option, names)
        self.assertIn("--json\tInput JSON to complete", reply)

    def test_commands_without_arguments_complete_nothing(self):
        self.assertEqual(complete("linto", "addman", ""), ["none"])

    def test_undeclared_commands_complete_any_file(self):
        with tempfile.TemporaryDirectory() as directory:
            script = Path(directory) / "tool.sh"
            script.write_text("#!/bin/sh\n", encoding="utf-8")
            result = subprocess.run(
                ["python3", ROOT / "lib" / "complete.py", script, ""],
                capture_output=True, text=True, check=True,
            )
            self.assertEqual(result.stdout.splitlines(), ["files"])


@unittest.skipUnless(shutil.which("bash"), "bash is required")
class BashCompletionTests(unittest.TestCase):
    def candidates(self, directory, *words):
        quoted = " ".join(f"'{word}'" for word in words)
        script = (
            f"source '{ROOT / 'completions' / 'linto.bash'}'\n"
            f"COMP_WORDS=(linto {quoted}); COMP_CWORD=$(( ${{#COMP_WORDS[@]}} - 1 ))\n"
            "COMPREPLY=(); _linto_complete; printf '%s\\n' \"${COMPREPLY[@]}\"\n"
        )
        result = subprocess.run(
            ["bash", "-c", script], capture_output=True, text=True, cwd=directory
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        return sorted(result.stdout.split())

    def test_files_are_filtered_and_directories_kept(self):
        with tempfile.TemporaryDirectory() as directory:
            for name in ("a.qmd", "b.md", "c.txt", "d.bib"):
                (Path(directory) / name).touch()
            (Path(directory) / "sub").mkdir()
            self.assertEqual(
                self.candidates(directory, "quarto", "render", ""), ["a.qmd", "b.md", "sub"]
            )
            self.assertEqual(
                self.candidates(directory, "bib", "bib2json", ""), ["d.bib", "sub"]
            )

    def test_option_values_and_option_names(self):
        with tempfile.TemporaryDirectory() as directory:
            (Path(directory) / "e.json").touch()
            (Path(directory) / "d.bib").touch()
            self.assertEqual(
                self.candidates(directory, "bib", "bib2json", "-j", ""), ["e.json"]
            )
            self.assertEqual(
                self.candidates(directory, "bib", "bib2awk", "-f", ""), ["bibs", "csv", "sed"]
            )
            self.assertIn("--output", self.candidates(directory, "bib", "bib2json", "--o"))

    def test_command_names_still_complete_after_a_partial_word(self):
        with tempfile.TemporaryDirectory() as directory:
            self.assertEqual(self.candidates(directory, "quarto", "ren"), ["render"])


@unittest.skipUnless(shutil.which("fish"), "fish is required")
class FishCompletionTests(unittest.TestCase):
    def candidates(self, directory, line):
        result = subprocess.run(
            ["fish", "--no-config", "-c",
             f"source '{ROOT / 'completions' / 'linto.fish'}'; complete -C '{line}'"],
            capture_output=True, text=True, cwd=directory,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        return sorted(line.split("\t")[0] for line in result.stdout.splitlines())

    def test_files_are_filtered_and_directories_kept(self):
        with tempfile.TemporaryDirectory() as directory:
            for name in ("a.qmd", "b.md", "c.txt"):
                (Path(directory) / name).touch()
            (Path(directory) / "sub").mkdir()
            self.assertEqual(
                self.candidates(directory, "linto quarto render "), ["a.qmd", "b.md", "sub/"]
            )
            self.assertEqual(self.candidates(directory, "linto utils stripaccents -d "), ["sub/"])

    def test_choices_and_no_command_names_after_the_command(self):
        with tempfile.TemporaryDirectory() as directory:
            self.assertEqual(
                self.candidates(directory, "linto prettyprint -f "), ["classic", "outlined"]
            )
            self.assertNotIn("render", self.candidates(directory, "linto quarto render "))
            self.assertIn("render", self.candidates(directory, "linto quarto "))


@unittest.skipUnless(shutil.which("zsh"), "zsh is required")
class ZshCompletionTests(unittest.TestCase):
    def listing(self, directory, line):
        """Press Tab after `line` in an interactive zsh and return what it printed."""
        pid, descriptor = pty.fork()
        if pid == 0:
            os.chdir(directory)
            os.environ.update(TERM="xterm", HOME=directory, ZDOTDIR=directory)
            os.execvp("zsh", ["zsh", "-f", "-i"])

        output = b""

        def drain(seconds):
            nonlocal output
            end = time.monotonic() + seconds
            while time.monotonic() < end:
                ready, _, _ = select.select([descriptor], [], [], 0.05)
                if ready:
                    try:
                        output += os.read(descriptor, 65536)
                    except OSError:
                        return

        drain(0.5)
        setup = [
            f"fpath=('{ROOT / 'completions'}' $fpath)",
            "autoload -Uz compinit; compinit -u",
            f"export PATH='{ROOT / 'bin'}':$PATH",
            "PS1='% '; setopt noautomenu nobeep",
        ]
        for command in setup:
            os.write(descriptor, command.encode() + b"\r")
            drain(0.4)
        output = b""
        os.write(descriptor, line.encode() + b"\t")
        drain(1.5)
        os.write(descriptor, b"\x03exit\r")
        drain(0.3)
        os.close(descriptor)
        os.waitpid(pid, 0)
        text = re.sub(rb"\x1b\[[0-9;?]*[A-Za-z]", b"", output).decode(errors="replace")
        return text.split()

    def test_files_are_filtered_and_directories_kept(self):
        with tempfile.TemporaryDirectory() as directory:
            for name in ("a.qmd", "b.md", "c.txt"):
                (Path(directory) / name).touch()
            (Path(directory) / "sub").mkdir()
            words = self.listing(directory, "linto quarto render ")
            self.assertIn("a.qmd", words)
            self.assertIn("b.md", words)
            self.assertIn("sub/", words)
            self.assertNotIn("c.txt", words)


if __name__ == "__main__":
    unittest.main()
