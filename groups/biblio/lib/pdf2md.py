#!/usr/bin/env python3
"""
pdf2md.py — Convertit des fichiers PDF en Markdown.

Pour chaque FICHIER.pdf, écrit CLÉ.md où CLÉ est le nom du fichier sans
« .pdf ». Le fichier commence par un frontmatter YAML (key, puis toutes les
métadonnées disponibles, comme pdf2json.py), suivi du texte en Markdown.

Le texte est mis en forme par paragraphes : les lignes coupées par la mise en
page sont rejointes (une ligne qui n'atteint pas la marge termine le
paragraphe) et les puces deviennent des listes. Les césures, les titres et les
tableaux ne sont pas détectés.
"""

import re
import sys

import yaml

import pdf2json

BULLET = re.compile(r"^[•●▪◦‣∙·–—-]\s+")
MARKDOWN_START = re.compile(r"^([#>+*]|\d+[.)]\s|-{3,}|={3,})")


def escape_start(line):
    """Keep a line that merely looks like Markdown syntax from becoming syntax."""
    return "\\" + line if MARKDOWN_START.match(line) else line


def line_width(lines):
    """Typical width of a full line: the 90th percentile, so that a few
    unusually long lines do not make every other line look short."""
    lengths = sorted(len(line) for line in lines)
    return lengths[int(0.9 * (len(lengths) - 1))] if lengths else 0


def to_markdown(text):
    lines = [line.strip() for line in text.replace("\r", "").splitlines()]
    threshold = 0.75 * line_width([line for line in lines if line])
    # Each block is ("p" or "ul", items); an item is the list of its lines.
    blocks = []
    for line in lines:
        bullet = bool(BULLET.match(line))
        if not line:
            blocks.append(None)
        elif not blocks or blocks[-1] is None:
            blocks.append(("ul" if bullet else "p", [[line]]))
        else:
            kind, items = blocks[-1]
            if bullet and kind == "ul":
                items.append([line])
            elif bullet:
                blocks.append(("ul", [[line]]))
            elif len(items[-1][-1]) < threshold:
                # The previous line stopped short of the margin: it ended a paragraph.
                blocks.append(("p", [[line]]))
            else:
                items[-1].append(line)

    rendered = []
    for block in blocks:
        if block is None:
            continue
        kind, items = block
        if kind == "ul":
            rendered.append("\n".join(
                "- " + BULLET.sub("", " ".join(item), count=1) for item in items))
        else:
            rendered.append(escape_start(" ".join(items[0])))
    return "\n\n".join(rendered)


def render_markdown(data):
    frontmatter = {"key": data["key"], **data["frontmatter"]}
    header = yaml.safe_dump(
        frontmatter, allow_unicode=True, sort_keys=False, width=1000, default_flow_style=False
    )
    return f"---\n{header}---\n\n{to_markdown(data['text'])}\n"


def main():
    return pdf2json.run_cli(
        "Convertit des fichiers PDF en Markdown (frontmatter YAML, puis texte).",
        ".md",
        render_markdown,
    )


if __name__ == "__main__":
    sys.exit(main())
