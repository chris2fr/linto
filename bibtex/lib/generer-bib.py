#!/usr/bin/env python3
"""
Génère un fichier .bib contextuel à partir de :
  - fr.bib         : entrées complètes SANS champ number
  - pieces-XXX.yml : mapping clé → numéro

Usage :
  python3 lib/generer-bib.py pieces-ref-08.yml fr-ref-08.bib
  python3 lib/generer-bib.py pieces-mem-05.yml fr-mem-05.bib
  ...

Le fichier généré est identique à fr.bib, sauf que les entrées listées
dans le YAML reçoivent un champ `number` en première position après la
ligne d'ouverture.
"""

import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("Erreur : le module PyYAML n'est pas installé.", file=sys.stderr)
    print("Installez-le avec : pip install pyyaml", file=sys.stderr)
    sys.exit(1)


def parser_fr_bib(chemin: str) -> dict:
    """Retourne un dict {clé: texte_de_l_entree}."""
    contenu = Path(chemin).read_text(encoding='utf-8')
    entrees = {}
    # Cherche chaque entrée @type{clé, ...} avec accolades équilibrées.
    motif = re.compile(r'(@\w+\{([^,]+),)', re.MULTILINE)
    for m in motif.finditer(contenu):
        debut = m.start()
        # Trouver la fin équilibrée
        profondeur = 0
        i = contenu.find('{', debut)
        fin = None
        while i < len(contenu):
            c = contenu[i]
            if c == '{':
                profondeur += 1
            elif c == '}':
                profondeur -= 1
                if profondeur == 0:
                    fin = i
                    break
            i += 1
        if fin is None:
            continue
        cle = m.group(2).strip()
        texte = contenu[debut:fin + 1]
        entrees[cle] = texte
    return entrees


def injecter_number(entree: str, num: int) -> str:
    """Injecte ou remplace le champ number."""
    # Supprimer un éventuel number existant (dans l'entrée complète)
    entree = re.sub(r'\n[ \t]*number[ \t]*=[ \t]*\{[^}]*\},?', '', entree)
    # Insérer juste après la première virgule de la ligne d'ouverture
    return re.sub(
        r'(@\w+\{[^,]+,)',
        rf'\1\n\tnumber = {{{num}}},',
        entree,
        count=1,
    )


def main():
    if len(sys.argv) < 3:
        print("Usage : python3 lib/generer-bib.py pieces-XXX.yml fr-XXX.bib",
              file=sys.stderr)
        sys.exit(1)

    chemin_yaml = Path(sys.argv[1])
    chemin_sortie = Path(sys.argv[2])
    chemin_fr = Path('fr.bib')

    if not chemin_fr.exists():
        print(f"Erreur : {chemin_fr} introuvable.", file=sys.stderr)
        sys.exit(1)
    if not chemin_yaml.exists():
        print(f"Erreur : {chemin_yaml} introuvable.", file=sys.stderr)
        sys.exit(1)

    with chemin_yaml.open('r', encoding='utf-8') as f:
        pieces = yaml.safe_load(f) or {}

    entrees = parser_fr_bib('fr.bib')

    lignes = []
    lignes.append(f"% Fichier généré automatiquement depuis fr.bib et {chemin_yaml}")
    lignes.append("% Ne pas modifier à la main.")
    lignes.append("")

    manquantes = []
    for cle, num in pieces.items():
        if cle not in entrees:
            manquantes.append(cle)
            continue
        entree = injecter_number(entrees[cle], num)
        lignes.append(entree)
        lignes.append("")

    chemin_sortie.write_text('\n'.join(lignes), encoding='utf-8')

    print(f"✓ {chemin_sortie} généré ({len(pieces) - len(manquantes)} entrées).")
    if manquantes:
        print(f"⚠ {len(manquantes)} clé(s) introuvable(s) dans fr.bib :", file=sys.stderr)
        for c in manquantes:
            print(f"  - {c}", file=sys.stderr)


if __name__ == '__main__':
    main()