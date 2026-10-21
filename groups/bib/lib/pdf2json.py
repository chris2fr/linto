#!/usr/bin/env python3
"""
pdf2json.py — Convertit des fichiers PDF en JSON.

Pour chaque FICHIER.pdf, écrit CLÉ.json où CLÉ est le nom du fichier sans
« .pdf » :

    {
      "key": "CLÉ",
      "frontmatter": { "title": ..., "author": ..., "date": ..., ... },
      "text": "texte extrait"
    }

Les champs title, author, date, organization, url et note qui manquent aux
métadonnées sont cherchés dans le texte (voir pdfguess.py) et listés dans
`guessed`; --no-guess désactive cette recherche.

Le texte vient de pdftotext (ou de pdf2txt, de pdfminer.six, avec
--engine pdf2txt) et les métadonnées de pdfinfo (champs standards),
de qpdf (autres entrées du dictionnaire Info, si qpdf est installé) et du flux
XMP du document.
"""

import json
import re
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

# Allow importing the sibling module however this file was loaded.
sys.path.insert(0, str(Path(__file__).resolve().parent))
import cli  # noqa: E402
from cli import _  # noqa: E402
import pdfguess  # noqa: E402

RDF = "http://www.w3.org/1999/02/22-rdf-syntax-ns#"
XML = "http://www.w3.org/XML/1998/namespace"

# Noms pdfinfo -> noms du frontmatter.
RENAMED = {"creationdate": "date", "moddate": "modified"}
INTEGERS = {"pages", "file_size", "page_rot"}
BOOLEANS = {
    "encrypted", "tagged", "form_is_xfa", "userproperties", "suspects",
    "javascript", "optimized", "custom_metadata", "metadata_stream",
}
FIRST = ("title", "author", "date", "organization", "url", "note")


def run(command):
    result = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or _("{} failed").format(command[0]))
    return result.stdout


def normalize_name(name):
    name = re.sub(r"[^0-9a-z]+", "_", name.strip().lower()).strip("_")
    return RENAMED.get(name, name)


def convert(name, value):
    if name in INTEGERS:
        match = re.match(r"\d+", value)
        return int(match.group()) if match else value
    if name in BOOLEANS and value in ("yes", "no"):
        return value == "yes"
    return value


def pdfinfo_fields(path):
    fields = {}
    for line in run(["pdfinfo", "-isodates", "-enc", "UTF-8", str(path)]).splitlines():
        label, separator, value = line.partition(":")
        if separator and value.strip():
            name = normalize_name(label)
            fields[name] = convert(name, value.strip())
    return fields


def qpdf_info(path):
    """Every entry of the Info dictionary, including non-standard ones."""
    if shutil.which("qpdf") is None:
        return {}
    try:
        document = json.loads(run(["qpdf", "--json=2", "--json-key=qpdf", str(path)]))
        objects = document["qpdf"][1]
        reference = objects["trailer"]["value"]["/Info"]
        info = objects[f"obj:{reference}"]["value"]
    except (RuntimeError, KeyError, IndexError, ValueError, TypeError):
        return {}
    entries = {}
    for key, value in info.items():
        if isinstance(value, str) and value.startswith("u:") and value[2:].strip():
            entries[normalize_name(key.lstrip("/"))] = value[2:]
    return entries


def local(tag):
    return tag.rsplit("}", 1)[-1]


def xmp_value(element):
    container = next((child for child in element if child.tag.startswith(f"{{{RDF}}}")), None)
    if container is None:
        return (element.text or "").strip() or None
    items = [(item.get(f"{{{XML}}}lang"), (item.text or "").strip()) for item in container]
    items = [(lang, text) for lang, text in items if text]
    if local(container.tag) == "Alt":
        preferred = [text for lang, text in items if lang == "x-default"]
        return (preferred or [text for _, text in items] or [None])[0]
    return [text for _, text in items] or None


def xmp_fields(path):
    try:
        packet = run(["pdfinfo", "-meta", "-enc", "UTF-8", str(path)])
        root = ET.fromstring(packet[packet.index("<"):])
    except (RuntimeError, ValueError, ET.ParseError):
        return {}
    fields = {}
    for description in root.iter(f"{{{RDF}}}Description"):
        for attribute, value in description.attrib.items():
            if not attribute.startswith(f"{{{RDF}}}") and value.strip():
                fields[normalize_name(local(attribute))] = value.strip()
        for child in description:
            value = xmp_value(child)
            if value:
                fields[normalize_name(local(child.tag))] = value
    return fields


def build_frontmatter(path):
    frontmatter = pdfinfo_fields(path)
    for name, value in qpdf_info(path).items():
        frontmatter.setdefault(name, value)
    for name, value in xmp_fields(path).items():
        if name not in frontmatter:
            frontmatter[name] = value
        elif frontmatter[name] != value:
            frontmatter.setdefault(f"xmp_{name}", value)
    return frontmatter


def order_frontmatter(frontmatter):
    ordered = {name: frontmatter[name] for name in FIRST if name in frontmatter}
    ordered.update({name: value for name, value in frontmatter.items() if name not in ordered})
    return ordered


PDF2TXT_NAMES = ("pdf2txt.py", "pdf2txt")


def find_pdf2txt():
    return next((name for name in PDF2TXT_NAMES if shutil.which(name)), None)


def choose_engine(requested):
    """Return the text extraction engine to use, or raise if none is installed."""
    available = {
        "pdftotext": shutil.which("pdftotext") is not None,
        "pdf2txt": find_pdf2txt() is not None,
    }
    if requested != "auto":
        if not available[requested]:
            raise RuntimeError(_("{} is required for --engine {}").format(requested, requested))
        return requested
    for engine in ("pdftotext", "pdf2txt"):
        if available[engine]:
            return engine
    raise RuntimeError(_("pdftotext (poppler) or pdf2txt (pdfminer.six) is required"))


def extract_text(path, layout, engine="pdftotext"):
    if engine == "pdf2txt":
        text = run([find_pdf2txt(), str(path)]).replace("\f", "\n")
        return re.sub(r"\n{3,}", "\n\n", text).strip()
    command = ["pdftotext", "-enc", "UTF-8", "-nopgbrk"]
    if layout:
        command.append("-layout")
    return run([*command, str(path), "-"]).strip()


def convert_file(path, layout, engine="pdftotext", guess=True):
    key = path.name[:-4] if path.name.lower().endswith(".pdf") else path.name
    frontmatter = build_frontmatter(path)
    text = extract_text(path, layout, engine)
    if guess:
        guessed = pdfguess.fill_frontmatter(frontmatter, text, pdfguess.first_page_lines(path), key)
        if guessed:
            frontmatter["guessed"] = guessed
    return key, {
        "key": key,
        "frontmatter": order_frontmatter(frontmatter),
        "text": text,
    }


def render_json(data):
    return json.dumps(data, indent=2, ensure_ascii=False) + "\n"


def run_cli(name, description, suffix, render):
    """Convert each PDF given on the command line and write `render(data)`.

    Shared by pdf2json.py and pdf2md.py; `suffix` is the extension of the
    output files, named after the PDF without `.pdf`.
    """
    parser = cli.Parser(name, description)
    parser.add_argument("inputs", nargs="*", metavar=_("file.pdf"), help=_("PDF file(s) to convert (none or -: one PDF on stdin, result on stdout)"))
    parser.add_argument("-d", "--outdir", metavar=_("DIR"), help=_("Output directory (default: current directory)"))
    parser.add_argument("-o", "--output", metavar=_("FILE"), help=_("Output file, or - for stdout (one PDF only)"))
    parser.add_argument("--layout", action="store_true", help=_("Keep the page layout of the text (pdftotext -layout; no effect with pdf2txt)"))
    parser.add_argument(
        "--engine", choices=["auto", "pdftotext", "pdf2txt"], default="auto",
        help=_("Text extractor: pdftotext (poppler) or pdf2txt (pdfminer.six). "
               "By default, pdftotext if installed, otherwise pdf2txt."),
    )
    parser.add_argument(
        "--no-guess", action="store_true",
        help=_("Do not look in the text for fields missing from the metadata "
               "(title, author, date, organization, url, note)"),
    )
    args = parser.parse_args()

    from_stdin = cli.stdin_requested(parser, args.inputs, _("PDF file"))
    if args.output and (not from_stdin and len(args.inputs) != 1 or args.outdir):
        parser.error(_("-o/--output needs exactly one PDF and excludes -d/--outdir"))
    if shutil.which("pdfinfo") is None:
        return cli.fail(name, _("pdfinfo is required (poppler package)"))
    try:
        engine = choose_engine(args.engine)
    except RuntimeError as error:
        return cli.fail(name, error)

    outdir = Path(args.outdir) if args.outdir else Path.cwd()
    failed = False
    scratch = tempfile.TemporaryDirectory() if from_stdin else None
    if from_stdin:
        stdin_pdf = Path(scratch.name) / "stdin.pdf"
        stdin_pdf.write_bytes(sys.stdin.buffer.read())
        inputs, output = [str(stdin_pdf)], args.output or (None if args.outdir else "-")
    else:
        inputs, output = args.inputs, args.output
    for input_name in inputs:
        path = Path(input_name)
        try:
            if not path.is_file():
                raise RuntimeError(_("PDF file missing or unreadable"))
            key, data = convert_file(path, args.layout, engine, not args.no_guess)
            text = render(data)
            if output == "-":
                sys.stdout.write(text)
                continue
            target = Path(output) if output else outdir / f"{key}{suffix}"
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(text, encoding="utf-8")
            print(target)
        except (RuntimeError, OSError) as error:
            print(f"{'stdin' if from_stdin else path}: {error}", file=sys.stderr)
            failed = True
    if scratch:
        scratch.cleanup()
    return 1 if failed else 0


def main():
    return run_cli("pdf2json", _("Convert PDF files to JSON (key, frontmatter, text)."), ".json", render_json)


if __name__ == "__main__":
    sys.exit(main())
