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

Le texte vient de pdftotext et les métadonnées de pdfinfo (champs standards),
de qpdf (autres entrées du dictionnaire Info, si qpdf est installé) et du flux
XMP du document.
"""

import argparse
import json
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

RDF = "http://www.w3.org/1999/02/22-rdf-syntax-ns#"
XML = "http://www.w3.org/XML/1998/namespace"

# Noms pdfinfo -> noms du frontmatter.
RENAMED = {"creationdate": "date", "moddate": "modified"}
INTEGERS = {"pages", "file_size", "page_rot"}
BOOLEANS = {
    "encrypted", "tagged", "form_is_xfa", "userproperties", "suspects",
    "javascript", "optimized", "custom_metadata", "metadata_stream",
}
FIRST = ("title", "author", "date")


def run(command):
    result = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or f"{command[0]} a échoué")
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
        if isinstance(value, str) and value.startswith("u:"):
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
    ordered = {name: frontmatter.pop(name) for name in FIRST if name in frontmatter}
    ordered.update(frontmatter)
    return ordered


def extract_text(path, layout):
    command = ["pdftotext", "-enc", "UTF-8", "-nopgbrk"]
    if layout:
        command.append("-layout")
    return run([*command, str(path), "-"]).strip()


def convert_file(path, layout):
    key = path.name[:-4] if path.name.lower().endswith(".pdf") else path.name
    return key, {
        "key": key,
        "frontmatter": build_frontmatter(path),
        "text": extract_text(path, layout),
    }


def main():
    parser = argparse.ArgumentParser(
        description="Convertit des fichiers PDF en JSON (clé, frontmatter, text)."
    )
    parser.add_argument("inputs", nargs="+", metavar="fichier.pdf", help="Fichier(s) PDF à convertir")
    parser.add_argument("-d", "--outdir", metavar="DOSSIER", help="Dossier de sortie (défaut : dossier courant)")
    parser.add_argument("-o", "--output", metavar="FICHIER", help="Fichier de sortie, ou - pour stdout (un seul PDF)")
    parser.add_argument("--layout", action="store_true", help="Conserve la mise en page du texte (pdftotext -layout)")
    args = parser.parse_args()

    if args.output and (len(args.inputs) != 1 or args.outdir):
        parser.error("-o/--output demande exactement un PDF et exclut -d/--outdir")
    for tool in ("pdfinfo", "pdftotext"):
        if shutil.which(tool) is None:
            print(f"{sys.argv[0]}: {tool} est requis (paquet poppler)", file=sys.stderr)
            return 1

    outdir = Path(args.outdir) if args.outdir else Path.cwd()
    failed = False
    for name in args.inputs:
        path = Path(name)
        try:
            if not path.is_file():
                raise RuntimeError("fichier PDF absent ou illisible")
            key, data = convert_file(path, args.layout)
            text = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
            if args.output == "-":
                sys.stdout.write(text)
                continue
            target = Path(args.output) if args.output else outdir / f"{key}.json"
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(text, encoding="utf-8")
            print(target)
        except (RuntimeError, OSError) as error:
            print(f"{path}: {error}", file=sys.stderr)
            failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
