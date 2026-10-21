#!/usr/bin/env python3
"""Generate placeholder text in Latin, French or English."""

import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "lib"))
from clibase import Parser, _  # noqa: E402

WORDS = {
    "la": (
        "lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod "
        "tempor incididunt ut labore et dolore magna aliqua enim ad minim veniam "
        "quis nostrud exercitation ullamco laboris nisi aliquip ex ea commodo "
        "consequat duis aute irure in reprehenderit voluptate velit esse cillum "
        "fugiat nulla pariatur excepteur sint occaecat cupidatat non proident "
        "sunt culpa qui officia deserunt mollit anim id est laborum"
    ).split(),
    "fr": (
        "le la les de des du un une et ou mais donc car ni que qui quoi dont où "
        "dans sur sous avec sans pour par vers chez entre contre pendant depuis "
        "lettre document texte phrase mot page ligne paragraphe titre section "
        "livre auteur lecteur bibliothèque référence note citation exemple "
        "projet travail idée forme sens usage temps lieu monde jour année "
        "petit grand ancien nouveau simple clair long court premier dernier "
        "écrire lire dire voir faire trouver montrer garder rendre suivre "
        "toujours souvent parfois jamais ici ailleurs aussi encore déjà"
    ).split(),
    "en": (
        "the a an and or but so because that which who whom whose where in on "
        "under with without for by to from at between against during since "
        "letter document text sentence word page line paragraph title section "
        "book author reader library reference note quotation example project "
        "work idea shape meaning use time place world day year small large old "
        "new simple clear long short first last write read say see make find "
        "show keep give follow always often sometimes never here elsewhere also "
        "still already"
    ).split(),
}

OPENING = {
    "la": "Lorem ipsum dolor sit amet, consectetur adipiscing elit",
    "fr": "Lorem ipsum, dit le texte, sert à remplir la page",
    "en": "Lorem ipsum is placeholder text that fills the page",
}


def sentence(rng: random.Random, words: list[str]) -> str:
    count = rng.randint(6, 14)
    chosen = [rng.choice(words) for _ in range(count)]
    for pos in (count // 3, 2 * count // 3):
        if 2 < pos < count - 2 and rng.random() < 0.5:
            chosen[pos] += ","
    text = " ".join(chosen)
    return text[0].upper() + text[1:] + "."


def paragraph(rng: random.Random, words: list[str], first: str | None) -> str:
    sentences = [sentence(rng, words) for _ in range(rng.randint(3, 6))]
    if first:
        sentences[0] = first + "."
    return " ".join(sentences)


def generate(
    unit: str, count: int, lang: str, seed: int | None = None, classic: bool = True
) -> str:
    """Return COUNT paragraphs, sentences or words of placeholder text."""
    rng = random.Random(seed)
    words = WORDS[lang]
    opening = OPENING[lang] if classic else None
    if unit == "words":
        out = [rng.choice(words) for _ in range(count)]
        if opening:
            lead = opening.lower().replace(",", "").split()[:count]
            out[: len(lead)] = lead
        return " ".join(out)
    if unit == "sentences":
        out = [sentence(rng, words) for _ in range(count)]
        if opening:
            out[0] = opening + "."
        return " ".join(out)
    return "\n\n".join(
        paragraph(rng, words, opening if i == 0 else None) for i in range(count)
    )


def main() -> int:
    parser = Parser("utils", "lorem", description=_("Generate placeholder text."))
    parser.add_argument(
        "count", nargs="?", type=int, default=3,
        help=_("how many units to produce (default: 3)"),
    )
    group = parser.add_mutually_exclusive_group()
    group.add_argument("-p", "--paragraphs", dest="unit", action="store_const",
                       const="paragraphs", help=_("produce paragraphs (default)"))
    group.add_argument("-s", "--sentences", dest="unit", action="store_const",
                       const="sentences", help=_("produce sentences"))
    group.add_argument("-w", "--words", dest="unit", action="store_const",
                       const="words", help=_("produce words"))
    parser.add_argument("-l", "--lang", choices=sorted(WORDS), default="la",
                        help=_("language of the text (default: la)"))
    parser.add_argument("--seed", type=int,
                        help=_("seed the generator for reproducible output"))
    parser.add_argument("--no-classic-opening", action="store_true",
                        help=_('do not start with "Lorem ipsum"'))
    args = parser.parse_args()
    if args.count < 1:
        parser.error(_("count must be at least 1"))
    print(generate(args.unit or "paragraphs", args.count, args.lang, args.seed,
                   not args.no_classic_opening))
    return 0


if __name__ == "__main__":
    sys.exit(main())
