import importlib.util
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "groups" / "biblio" / "lib"
SCRIPT = ROOT / "groups" / "biblio" / "pdf2md.sh"
sys.path.insert(0, str(LIB))
sys.path.insert(0, str(ROOT / "tests"))
SPEC = importlib.util.spec_from_file_location("pdf2md", LIB / "pdf2md.py")
assert SPEC and SPEC.loader
pdf2md = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(pdf2md)
from test_pdf2json import minimal_pdf  # noqa: E402

LONG = "x" * 60


class MarkdownTests(unittest.TestCase):
    def test_wrapped_lines_are_joined_and_short_lines_end_a_paragraph(self):
        text = f"{LONG}\n{LONG}\nend of it.\nNext paragraph starts here\n\n{LONG}\ntail"
        self.assertEqual(
            pdf2md.to_markdown(text),
            f"{LONG} {LONG} end of it.\n\nNext paragraph starts here\n\n{LONG} tail",
        )

    def test_bullets_become_a_list(self):
        text = "Intro\n\n• one\n• two\n\nAfter"
        self.assertEqual(pdf2md.to_markdown(text), "Intro\n\n- one\n- two\n\nAfter")

    def test_lines_that_look_like_markdown_are_escaped(self):
        self.assertEqual(pdf2md.to_markdown("# not a heading"), "\\# not a heading")
        self.assertEqual(pdf2md.to_markdown("1. not a list"), "\\1. not a list")


@unittest.skipUnless(shutil.which("pdfinfo") and shutil.which("pdftotext"), "poppler is required")
class ConversionTests(unittest.TestCase):
    def test_frontmatter_then_markdown_text(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            minimal_pdf(directory / "mon article.pdf", {"Title": "Un titre: avec deux-points", "Author": "Ada"})
            result = subprocess.run(
                [SCRIPT, "mon article.pdf"], capture_output=True, text=True, cwd=directory
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            content = (directory / "mon article.md").read_text(encoding="utf-8")
            self.assertTrue(content.startswith("---\nkey: mon article\n"))
            _, header, body = content.split("---\n", 2)
            frontmatter = yaml.safe_load(header)
            self.assertEqual(frontmatter["key"], "mon article")
            self.assertEqual(frontmatter["title"], "Un titre: avec deux-points")
            self.assertEqual(frontmatter["author"], "Ada")
            self.assertEqual(frontmatter["pages"], 1)
            self.assertEqual(body.strip(), "Bonjour PDF")


if __name__ == "__main__":
    unittest.main()
