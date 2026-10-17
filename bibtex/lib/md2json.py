#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
md2json.py — Convertit un fichier Markdown en JSON.

Fonctionnement :
- Lit un fichier Markdown et le convertit en structure JSON
- Options pour différents formats de sortie:
  * Texte brut (contenu complet)
  * Structure avec métadonnées (titre, sections, paragraphes)
  * Structure hiérarchique avec titres et contenu
  * Format simplifié (juste le texte)

Usage :
    python3 md2json.py fichier.md
    python3 md2json.py fichier.md -o sortie.json
    python3 md2json.py fichier.md --format structured
    python3 md2json.py fichier.md --format sections --pretty
    python3 md2json.py *.md --outdir json/   # plusieurs fichiers

Dépendances :
    pip install markdown  # optionnel pour une meilleure analyse
"""

import argparse
import json
import re
import sys
import io
from pathlib import Path
from typing import Any, Dict, List, Optional

if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')
    sys.argv = [arg.encode('utf-8').decode('utf-8') for arg in sys.argv]


def parse_markdown_headers(content: str) -> List[Dict[str, Any]]:
    """Parse le Markdown en une structure hiérarchique basée sur les titres."""
    lines = content.split('\n')
    sections = []
    current_section = None
    current_content = []
    current_level = 0
    stack = []

    for line in lines:
        header_match = re.match(r'^(#{1,6})\s+(.+)$', line)
        if header_match:
            if current_section is not None:
                current_section['content'] = '\n'.join(current_content).strip()
                if stack:
                    parent = stack[-1]
                    if 'subsections' not in parent:
                        parent['subsections'] = []
                    parent['subsections'].append(current_section)
                else:
                    sections.append(current_section)

            level = len(header_match.group(1))
            title = header_match.group(2).strip()
            current_section = {
                'level': level,
                'title': title,
                'content': '',
                'subsections': []
            }
            current_content = []
            current_level = level

            while stack and stack[-1]['level'] >= level:
                stack.pop()
            if stack:
                stack.append(current_section)
            else:
                stack = [current_section]
        elif current_section is not None:
            current_content.append(line)
        elif line.strip():
            sections.append({
                'level': 0,
                'title': 'Introduction',
                'content': line.strip(),
                'subsections': []
            })

    if current_section is not None:
        current_section['content'] = '\n'.join(current_content).strip()
        if stack and stack[-1] != current_section:
            parent = stack[-1]
            if 'subsections' not in parent:
                parent['subsections'] = []
            parent['subsections'].append(current_section)
        elif not stack:
            sections.append(current_section)

    return sections


def extract_tables(content: str) -> List[List[List[str]]]:
    """Extrait les tableaux Markdown et les convertit en listes de listes."""
    tables = []
    lines = content.split('\n')
    i = 0
    while i < len(lines):
        if '|' in lines[i] and '|' in lines[i + 1] if i + 1 < len(lines) else False:
            table = []
            while i < len(lines) and '|' in lines[i]:
                row = [cell.strip() for cell in lines[i].split('|')[1:-1]]
                if not all(c == '---' for c in row):
                    table.append(row)
                i += 1
            if table:
                tables.append(table)
        else:
            i += 1
    return tables


def extract_code_blocks(content: str) -> List[Dict[str, str]]:
    """Extrait les blocs de code du Markdown."""
    code_blocks = []
    lines = content.split('\n')
    i = 0
    while i < len(lines):
        if lines[i].strip().startswith('```'):
            lang = lines[i].strip()[3:].strip()
            code = []
            i += 1
            while i < len(lines) and not lines[i].strip().startswith('```'):
                code.append(lines[i])
                i += 1
            if code:
                code_blocks.append({'language': lang or 'text', 'code': '\n'.join(code)})
        i += 1
    return code_blocks


def markdown_to_json_simple(content: str) -> Dict[str, Any]:
    """Conversion simple: tout le contenu en une seule chaîne."""
    return {'content': content, 'length': len(content), 'lines': len(content.split('\n'))}


def markdown_to_json_structured(content: str) -> Dict[str, Any]:
    """Conversion structurée avec sections, tableaux et blocs de code."""
    sections = parse_markdown_headers(content)
    tables = extract_tables(content)
    code_blocks = extract_code_blocks(content)
    title = next((section['title'] for section in sections if section['level'] == 1), None)
    return {
        'title': title or Path('fichier').stem,
        'sections': sections,
        'tables': tables,
        'code_blocks': code_blocks,
        'total_sections': len(sections),
        'total_tables': len(tables),
        'total_code_blocks': len(code_blocks)
    }


def markdown_to_json_flat(content: str) -> Dict[str, Any]:
    """Format plat: sépare le texte en paragraphes."""
    paragraphs = [p.strip() for p in content.split('\n\n') if p.strip()]
    return {'paragraphs': paragraphs, 'count': len(paragraphs), 'total_chars': sum(len(p) for p in paragraphs)}


def markdown_to_json_metadata(content: str, file_path: Path) -> Dict[str, Any]:
    """Format avec métadonnées complètes."""
    structured = markdown_to_json_structured(content)
    metadata = {}
    lines = content.split('\n')
    if lines and lines[0].strip() == '---':
        end_idx = None
        for i, line in enumerate(lines[1:], 1):
            if line.strip() == '---':
                end_idx = i
                break
        if end_idx:
            for line in lines[1:end_idx]:
                if ':' in line:
                    key, value = line.split(':', 1)
                    metadata[key.strip()] = value.strip()
    return {
        'file': {'name': file_path.name, 'stem': file_path.stem, 'path': str(file_path)},
        'metadata': metadata,
        'content': structured,
        'stats': {
            'total_chars': len(content),
            'total_lines': len(content.split('\n')),
            'total_words': len(re.findall(r'\w+', content))
        }
    }


def md_to_json(md_path: Path, out_path: Path, format_type: str = 'simple', pretty: bool = False) -> None:
    """Convertit un fichier Markdown en JSON."""
    content = md_path.read_text(encoding='utf-8')
    converters = {
        'simple': markdown_to_json_simple,
        'structured': markdown_to_json_structured,
        'flat': markdown_to_json_flat,
        'metadata': markdown_to_json_metadata,
    }
    converter = converters.get(format_type)
    if not converter:
        raise ValueError(f"Format inconnu: {format_type}")
    result = converter(content, md_path) if format_type == 'metadata' else converter(content)
    if format_type != 'metadata':
        result['_meta'] = {'source': str(md_path), 'format': format_type}
    indent = 2 if pretty else None
    out_path.write_text(json.dumps(result, ensure_ascii=False, indent=indent), encoding='utf-8')
    print(f"OK : {md_path} -> {out_path}", file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(
        description="Convertit un ou plusieurs fichiers Markdown en JSON.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Formats disponibles:
  simple     - Contenu complet en une seule chaîne
  structured - Structure hiérarchique avec titres, sections, tableaux, code
  flat       - Liste de paragraphes
  metadata   - Structure complète avec métadonnées et statistiques

Exemples:
  %(prog)s doc.md
  %(prog)s doc.md -o doc.json
  %(prog)s doc.md --format structured --pretty
  %(prog)s *.md --outdir json/
        """
    )
    parser.add_argument("inputs", nargs="+", help="Fichier(s) Markdown à convertir")
    parser.add_argument("-o", "--output", help="Fichier de sortie (un seul fichier en entrée uniquement)")
    parser.add_argument("--outdir", help="Dossier de sortie pour plusieurs fichiers")
    parser.add_argument("--format", choices=['simple', 'structured', 'flat', 'metadata'], default='simple', help="Format de sortie JSON (défaut: simple)")
    parser.add_argument("--pretty", action="store_true", help="Formater le JSON avec indentation")
    args = parser.parse_args()

    inputs = [Path(p) for p in args.inputs]
    if args.output and len(inputs) > 1:
        parser.error("--output ne peut être utilisé qu'avec un seul fichier en entrée. Utilisez --outdir pour plusieurs fichiers.")

    outdir = Path(args.outdir) if args.outdir else None
    if outdir:
        outdir.mkdir(parents=True, exist_ok=True)

    for md_path in inputs:
        if not md_path.exists():
            print(f"Introuvable, ignoré : {md_path}", file=sys.stderr)
            continue
        if args.output:
            out_path = Path(args.output)
        elif outdir:
            out_path = outdir / (md_path.stem + ".json")
        else:
            out_path = md_path.with_suffix(".json")
        print(f"Conversion de {md_path}...", file=sys.stderr)
        md_to_json(md_path, out_path, format_type=args.format, pretty=args.pretty)


if __name__ == "__main__":
    main()
