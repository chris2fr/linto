import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "groups" / "bib" / "lib"
sys.path.insert(0, str(LIB))
sys.path.insert(0, str(ROOT / "tests"))
import pdfguess  # noqa: E402
from pdfguess import Line  # noqa: E402
from test_pdf2json import minimal_pdf  # noqa: E402


def lines(*texts):
    return [Line(text) for text in texts]


class FieldTests(unittest.TestCase):
    def test_title_is_the_largest_text_at_the_top(self):
        page = [Line("Running header", 8), Line("Le grand", 24), Line("titre du texte", 24),
                Line("Marie Dupont", 12), Line("Body text goes here", 11)]
        self.assertEqual(pdfguess.guess_title(page), "Le grand titre du texte")

    def test_title_skips_page_numbers_urls_and_dates(self):
        page = lines("12", "https://example.org", "12 mars 2026", "Le vrai titre")
        self.assertEqual(pdfguess.guess_title(page), "Le vrai titre")

    def test_author_after_a_label(self):
        self.assertEqual(pdfguess.guess_author(lines("Titre", "Par Marie Dupont"), "Titre"), "Marie Dupont")
        self.assertEqual(
            pdfguess.guess_author(lines("Title", "Authors: Ada Lovelace, Alan Turing"), "Title"),
            "Ada Lovelace, Alan Turing",
        )

    def test_author_as_names_after_the_title(self):
        page = lines("Rapport sur la lecture", "Marie Dupont et Jean-Luc Martin", "Texte du corps du rapport.")
        self.assertEqual(pdfguess.guess_author(page, "Rapport sur la lecture"), "Marie Dupont et Jean-Luc Martin")
        self.assertIsNone(pdfguess.guess_author(lines("Titre", "Rapport Annuel"), "Titre"))

    def test_dates(self):
        cases = {
            "Paris, le 12 mars 2026": "2026-03-12",
            "1er janvier 2024": "2024-01-01",
            "March 3, 2025": "2025-03-03",
            "3 March 2025": "2025-03-03",
            "03/04/2024": "2024-04-03",
            "2023-05-17": "2023-05-17",
            "mai 2023": "2023-05",
            "© 2022 Les Amis": "2022",
        }
        for text, expected in cases.items():
            with self.subTest(text=text):
                self.assertEqual(pdfguess.guess_date(lines(text)), expected)
        self.assertIsNone(pdfguess.guess_date(lines("31/02/2024", "version 1.2.3")))

    def test_a_labelled_date_wins_over_an_earlier_one(self):
        page = lines("Étude de 1999 à mai 2001", "Publié le 4 juin 2024")
        self.assertEqual(pdfguess.guess_date(page), "2024-06-04")

    def test_organization_url_and_note(self):
        page = lines("Titre", "Université de Lyon", "Note : version provisoire")
        self.assertEqual(pdfguess.guess_organization(page, "Titre"), "Université de Lyon")
        self.assertEqual(pdfguess.guess_url("voir www.exemple.org/a, puis"), "https://www.exemple.org/a")
        self.assertEqual(pdfguess.guess_url("http://x.org/y)."), "http://x.org/y")
        self.assertIsNone(pdfguess.guess_url("aucune adresse"))
        self.assertEqual(pdfguess.guess_note(page), "version provisoire")
        self.assertEqual(pdfguess.guess_note(lines("Brouillon - ne pas diffuser")), "Brouillon - ne pas diffuser")


class FillTests(unittest.TestCase):
    def test_metadata_wins_except_for_the_creation_date(self):
        frontmatter = {"title": "Vrai titre", "author": "Ada", "date": "2026-10-18T10:00:00+02"}
        text = "Autre titre\nPar Bob Martin\nParis, le 12 mars 2020"
        guessed = pdfguess.fill_frontmatter(frontmatter, text)
        self.assertEqual(frontmatter["title"], "Vrai titre")
        self.assertEqual(frontmatter["author"], "Ada")
        self.assertEqual(frontmatter["date"], "2020-03-12")
        self.assertEqual(frontmatter["created"], "2026-10-18T10:00:00+02")
        self.assertEqual(guessed, ["date"])

    def test_junk_metadata_is_replaced_and_kept(self):
        frontmatter = {"title": "Microsoft Word - brouillon.docx", "author": "admin"}
        text = "Le titre réel\nPar Marie Dupont"
        guessed = pdfguess.fill_frontmatter(frontmatter, text)
        self.assertEqual(frontmatter["title"], "Le titre réel")
        self.assertEqual(frontmatter["title_metadata"], "Microsoft Word - brouillon.docx")
        self.assertEqual(frontmatter["author"], "Marie Dupont")
        self.assertEqual(frontmatter["author_metadata"], "admin")
        self.assertEqual(guessed, ["title", "author"])

    def test_metadata_under_other_names_is_adopted(self):
        frontmatter = {"company": "ACME", "comments": "à relire", "source": "https://acme.example"}
        pdfguess.fill_frontmatter(frontmatter, "")
        self.assertEqual(
            (frontmatter["organization"], frontmatter["note"], frontmatter["url"]),
            ("ACME", "à relire", "https://acme.example"),
        )


@unittest.skipUnless(shutil.which("pdfinfo") and shutil.which("pdftotext"), "poppler is required")
class EndToEndTests(unittest.TestCase):
    def test_fields_are_found_on_the_first_page_and_can_be_disabled(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            minimal_pdf(directory / "doc.pdf", {}, lines=[
                (24, "Etude sur la lecture"), (11, "Marie Dupont et Jean Martin"),
                (11, "Universite de Lyon"), (11, "Paris, le 12 mars 2026"),
                (11, "Note : version provisoire"), (11, "Voir www.exemple.org"),
            ])
            script = ROOT / "groups" / "bib" / "pdf2json.sh"
            run = lambda *arguments: json.loads(subprocess.run(
                [script, "-o", "-", *arguments, "doc.pdf"], capture_output=True, text=True, cwd=directory, check=True
            ).stdout)["frontmatter"]
            found = run()
            self.assertEqual(found["title"], "Etude sur la lecture")
            self.assertEqual(found["author"], "Marie Dupont et Jean Martin")
            self.assertEqual(found["date"], "2026-03-12")
            self.assertEqual(found["organization"], "Universite de Lyon")
            self.assertEqual(found["url"], "https://www.exemple.org")
            self.assertEqual(found["note"], "version provisoire")
            self.assertEqual(
                found["guessed"], ["title", "author", "date", "organization", "url", "note"]
            )
            self.assertEqual(list(found)[:6], ["title", "author", "date", "organization", "url", "note"])
            plain = run("--no-guess")
            self.assertNotIn("guessed", plain)
            self.assertNotIn("title", plain)


if __name__ == "__main__":
    unittest.main()
