import importlib.util
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "groups" / "utils" / "lib" / "lorem.py"
SPEC = importlib.util.spec_from_file_location("lorem", MODULE_PATH)
lorem = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(lorem)


class LoremTests(unittest.TestCase):
    def test_word_count(self):
        self.assertEqual(len(lorem.generate("words", 7, "fr", 1).split()), 7)

    def test_paragraph_count(self):
        text = lorem.generate("paragraphs", 4, "en", 1)
        self.assertEqual(len(text.split("\n\n")), 4)

    def test_sentence_count(self):
        text = lorem.generate("sentences", 3, "la", 1)
        self.assertEqual(text.count("."), 3)

    def test_seed_is_reproducible(self):
        self.assertEqual(
            lorem.generate("paragraphs", 2, "la", 5),
            lorem.generate("paragraphs", 2, "la", 5),
        )

    def test_classic_opening_can_be_disabled(self):
        self.assertTrue(lorem.generate("paragraphs", 1, "la", 1).startswith("Lorem ipsum"))
        self.assertFalse(
            lorem.generate("paragraphs", 1, "la", 1, classic=False).startswith("Lorem ipsum dolor")
        )


if __name__ == "__main__":
    unittest.main()
