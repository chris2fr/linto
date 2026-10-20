#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
eml2pdf.py — conversion de courriels .eml en PDF pour bordereau de pieces

Chaque PDF produit commence par un bloc d'en-tetes complet (De, A, Cc, Date,
Objet, Message-ID) suivi du corps du message, puis de la liste des pieces
jointes. L'objectif est la valeur probatoire : rien de ce qui identifie le
message n'est perdu.

USAGE
  ./eml2pdf.py                       convertit tous les .eml du dossier courant
  ./eml2pdf.py DOSSIER               convertit tous les .eml de DOSSIER
  ./eml2pdf.py fichier.eml           convertit un seul fichier
  ./eml2pdf.py -o SORTIE DOSSIER     ecrit les PDF dans SORTIE
  ./eml2pdf.py --html-only           produit les .html sans les convertir
  ./eml2pdf.py --force               ecrase les PDF existants
  ./eml2pdf.py --attachments         extrait aussi les pieces jointes
  ./eml2pdf.py --moteur wkhtmltopdf  force un moteur de rendu

MOTEURS DE RENDU (detectes automatiquement, dans cet ordre)
  1. wkhtmltopdf    sudo apt install wkhtmltopdf
  2. weasyprint     pip install weasyprint
  3. chromium       sudo apt install chromium-browser

NOTE SUR THUNDERBIRD
  Thunderbird n'offre pas de conversion .eml -> .pdf en ligne de commande.
  L'extension ImportExportTools NG permet un export PDF depuis l'interface,
  message par message ou par selection, ce qui reste utile pour verifier
  ponctuellement le rendu d'un message delicat. Pour un lot de quarante
  courriels, ce script est plus sur et reproductible.
"""

import argparse
import base64
import html
import mimetypes
import os
import re
import shutil
import subprocess
import sys
import tempfile
from email import policy
from email.parser import BytesParser
from email.utils import parsedate_to_datetime

# --------------------------------------------------------------------------
# Gabarit HTML
# --------------------------------------------------------------------------

CSS = """
@page { size: A4; margin: 18mm 16mm 20mm 16mm; }
body { font-family: "DejaVu Serif", Georgia, serif; font-size: 10.5pt;
       line-height: 1.45; color: #000; }
.entete { border: 1pt solid #000; padding: 8pt 10pt; margin-bottom: 14pt; }
.entete table { width: 100%; border-collapse: collapse; }
.entete th { text-align: left; vertical-align: top; width: 26mm;
             white-space: nowrap;
             font-weight: bold; padding: 1.5pt 6pt 1.5pt 0;
             font-family: "DejaVu Sans", Helvetica, sans-serif; font-size: 9pt; }
.entete td { vertical-align: top; padding: 1.5pt 0;
             font-family: "DejaVu Sans", Helvetica, sans-serif; font-size: 9pt;
             word-break: break-word; }
.objet td { font-weight: bold; font-size: 10pt; }
.corps { margin-top: 6pt; }
.corps pre { white-space: pre-wrap; word-wrap: break-word;
             font-family: "DejaVu Sans Mono", monospace; font-size: 9.5pt;
             margin: 0; }
.corps img { max-width: 100%; height: auto; }
.corps table { max-width: 100%; }
.corps blockquote { border-left: 2pt solid #999; margin-left: 0;
                    padding-left: 8pt; color: #444; }
.pj { margin-top: 14pt; border-top: 0.5pt solid #666; padding-top: 6pt;
      font-family: "DejaVu Sans", Helvetica, sans-serif; font-size: 8.5pt; }
.pj h2 { font-size: 9pt; margin: 0 0 4pt 0; text-transform: uppercase;
         letter-spacing: 0.4pt; }
.pj ul { margin: 0; padding-left: 14pt; }
.pied { margin-top: 12pt; border-top: 0.5pt solid #999; padding-top: 4pt;
        font-family: "DejaVu Sans", Helvetica, sans-serif;
        font-size: 7.5pt; color: #555; }
"""

GABARIT = """<!DOCTYPE html>
<html lang="fr"><head><meta charset="utf-8">
<title>{titre}</title><style>{css}</style></head>
<body>
<div class="entete"><table>{lignes_entete}</table></div>
<div class="corps">{corps}</div>
{bloc_pj}
<div class="pied">Fichier source : {source} &mdash; converti le {horodatage}</div>
</body></html>
"""

CHAMPS = [
    ("De", "From"),
    ("À", "To"),
    ("Cc", "Cc"),
    ("Cci", "Bcc"),
    ("Répondre à", "Reply-To"),
    ("Date", "Date"),
    ("Objet", "Subject"),
    ("Message-ID", "Message-ID"),
]


# --------------------------------------------------------------------------
# Extraction
# --------------------------------------------------------------------------

def lire_message(chemin):
    with open(chemin, "rb") as f:
        return BytesParser(policy=policy.default).parse(f)


def valeur_entete(msg, cle):
    try:
        v = msg.get(cle)
    except Exception:
        v = None
    if not v:
        return ""
    return str(v).replace("\r", " ").replace("\n", " ").strip()


def date_lisible(msg):
    brut = valeur_entete(msg, "Date")
    if not brut:
        return ""
    try:
        d = parsedate_to_datetime(brut)
        jours = ["lundi", "mardi", "mercredi", "jeudi", "vendredi",
                 "samedi", "dimanche"]
        mois = ["janvier", "février", "mars", "avril", "mai", "juin",
                "juillet", "août", "septembre", "octobre", "novembre",
                "décembre"]
        return "%s %d %s %d à %02d h %02d (%s)" % (
            jours[d.weekday()], d.day, mois[d.month - 1], d.year,
            d.hour, d.minute, brut)
    except Exception:
        return brut


def extraire_corps(msg):
    """Retourne (html, est_html). Prefere text/html, sinon text/plain."""
    corps_html = None
    corps_texte = None

    if msg.is_multipart():
        for part in msg.walk():
            if part.get_content_maintype() == "multipart":
                continue
            disp = (part.get_content_disposition() or "")
            if disp == "attachment":
                continue
            ctype = part.get_content_type()
            if ctype == "text/html" and corps_html is None:
                corps_html = obtenir_texte(part)
            elif ctype == "text/plain" and corps_texte is None:
                corps_texte = obtenir_texte(part)
    else:
        if msg.get_content_type() == "text/html":
            corps_html = obtenir_texte(msg)
        else:
            corps_texte = obtenir_texte(msg)

    if corps_html:
        return nettoyer_html(corps_html), True
    if corps_texte:
        return "<pre>" + html.escape(corps_texte) + "</pre>", False
    return "<p><em>Message sans corps textuel.</em></p>", False


def obtenir_texte(part):
    try:
        return part.get_content()
    except Exception:
        pass
    try:
        charge = part.get_payload(decode=True) or b""
        jeu = part.get_content_charset() or "utf-8"
        return charge.decode(jeu, errors="replace")
    except Exception:
        return ""


def nettoyer_html(src):
    """Retire ce qui empeche un rendu hors ligne fiable et retire le
    chrome du document, en conservant le contenu."""
    src = re.sub(r"(?is)<script.*?</script>", "", src)
    src = re.sub(r"(?is)<meta[^>]*http-equiv=[\"']?refresh.*?>", "", src)
    m = re.search(r"(?is)<body[^>]*>(.*)</body>", src)
    if m:
        src = m.group(1)
    else:
        src = re.sub(r"(?is)</?(html|head|body|!doctype)[^>]*>", "", src)
    return src


def images_inline(msg):
    """cid -> data URI, pour que les images embarquees survivent au rendu."""
    table = {}
    if not msg.is_multipart():
        return table
    for part in msg.walk():
        cid = part.get("Content-ID")
        if not cid:
            continue
        cid = cid.strip("<>").strip()
        if part.get_content_maintype() != "image":
            continue
        donnees = part.get_payload(decode=True)
        if not donnees:
            continue
        table[cid] = "data:%s;base64,%s" % (
            part.get_content_type(),
            base64.b64encode(donnees).decode("ascii"))
    return table


def injecter_images(corps, table):
    if not table:
        return corps
    def sub(m):
        cid = m.group(2).strip()
        return m.group(1) + table.get(cid, m.group(2)) + m.group(3)
    return re.sub(r"(src\s*=\s*[\"'])cid:([^\"']+)([\"'])", sub, corps,
                  flags=re.I)


def lister_pj(msg):
    pj = []
    if not msg.is_multipart():
        return pj
    for part in msg.walk():
        if part.get_content_maintype() == "multipart":
            continue
        disp = part.get_content_disposition()
        nom = part.get_filename()
        if disp != "attachment" and not nom:
            continue
        donnees = part.get_payload(decode=True) or b""
        pj.append({
            "nom": nom or "(sans nom)",
            "type": part.get_content_type(),
            "taille": len(donnees),
            "donnees": donnees,
        })
    return pj


def taille_lisible(n):
    for unite in ("o", "ko", "Mo", "Go"):
        if n < 1024 or unite == "Go":
            return "%.0f %s" % (n, unite) if unite == "o" else "%.1f %s" % (n, unite)
        n /= 1024.0


# --------------------------------------------------------------------------
# Construction du HTML
# --------------------------------------------------------------------------

def construire_html(msg, source, horodatage):
    lignes = []
    for libelle, cle in CHAMPS:
        val = date_lisible(msg) if cle == "Date" else valeur_entete(msg, cle)
        if not val:
            continue
        classe = ' class="objet"' if cle == "Subject" else ""
        lignes.append("<tr%s><th>%s</th><td>%s</td></tr>"
                      % (classe, html.escape(libelle), html.escape(val)))

    corps, _ = extraire_corps(msg)
    corps = injecter_images(corps, images_inline(msg))

    pj = lister_pj(msg)
    if pj:
        items = "".join(
            "<li>%s &mdash; %s, %s</li>" % (html.escape(p["nom"]),
                                            html.escape(p["type"]),
                                            taille_lisible(p["taille"]))
            for p in pj)
        bloc_pj = ('<div class="pj"><h2>Pièces jointes au message '
                   '(%d)</h2><ul>%s</ul></div>' % (len(pj), items))
    else:
        bloc_pj = ""

    return GABARIT.format(
        titre=html.escape(valeur_entete(msg, "Subject") or source),
        css=CSS,
        lignes_entete="".join(lignes),
        corps=corps,
        bloc_pj=bloc_pj,
        source=html.escape(source),
        horodatage=horodatage,
    ), pj


# --------------------------------------------------------------------------
# Rendu PDF
# --------------------------------------------------------------------------

def detecter_moteur(force=None):
    if force:
        return force
    if shutil.which("wkhtmltopdf"):
        return "wkhtmltopdf"
    try:
        import weasyprint  # noqa: F401
        return "weasyprint"
    except ImportError:
        pass
    for c in ("chromium", "chromium-browser", "google-chrome",
              "google-chrome-stable"):
        if shutil.which(c):
            return "chromium:" + c
    return None


def rendre(chemin_html, chemin_pdf, moteur):
    if moteur == "wkhtmltopdf":
        cmd = ["wkhtmltopdf", "--quiet", "--enable-local-file-access",
               "--encoding", "utf-8",
               "--margin-top", "18mm", "--margin-bottom", "20mm",
               "--margin-left", "16mm", "--margin-right", "16mm",
               "--footer-font-size", "7", "--footer-right", "[page]/[topage]",
               chemin_html, chemin_pdf]
        r = subprocess.run(cmd, capture_output=True)
        return r.returncode == 0, r.stderr.decode("utf-8", "replace")

    if moteur == "weasyprint":
        try:
            from weasyprint import HTML
            HTML(filename=chemin_html).write_pdf(chemin_pdf)
            return True, ""
        except Exception as e:
            return False, str(e)

    if moteur.startswith("chromium:"):
        binaire = moteur.split(":", 1)[1]
        cmd = [binaire, "--headless", "--disable-gpu", "--no-sandbox",
               "--no-pdf-header-footer",
               "--print-to-pdf=" + chemin_pdf,
               "file://" + os.path.abspath(chemin_html)]
        r = subprocess.run(cmd, capture_output=True)
        return os.path.exists(chemin_pdf), r.stderr.decode("utf-8", "replace")

    return False, "moteur inconnu : " + moteur


# --------------------------------------------------------------------------
# Programme principal
# --------------------------------------------------------------------------

def nom_cible(chemin, sortie):
    base = os.path.basename(chemin)
    # gere les doubles extensions .eml.eml
    while base.lower().endswith(".eml"):
        base = base[:-4]
    return os.path.join(sortie or os.path.dirname(chemin) or ".", base + ".pdf")


def main():
    ap = argparse.ArgumentParser(
        description="Conversion de courriels .eml en PDF pour bordereau.",
        formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("cible", nargs="?", default=".",
                    help="fichier .eml ou dossier (defaut : dossier courant)")
    ap.add_argument("-o", "--sortie", help="dossier de destination des PDF")
    ap.add_argument("--force", action="store_true",
                    help="ecrase les PDF existants")
    ap.add_argument("--html-only", action="store_true",
                    help="produit les .html sans convertir")
    ap.add_argument("--attachments", action="store_true",
                    help="extrait les pieces jointes dans un sous-dossier")
    ap.add_argument("--moteur", help="wkhtmltopdf, weasyprint ou chromium:BIN")
    args = ap.parse_args()

    import datetime
    horodatage = datetime.datetime.now().strftime("%d/%m/%Y à %H h %M")

    if os.path.isdir(args.cible):
        fichiers = sorted(
            os.path.join(args.cible, f) for f in os.listdir(args.cible)
            if f.lower().endswith(".eml"))
    elif os.path.isfile(args.cible):
        fichiers = [args.cible]
    else:
        print("Cible introuvable : %s" % args.cible, file=sys.stderr)
        return 1

    if not fichiers:
        print("Aucun fichier .eml trouvé.")
        return 0

    moteur = None
    if not args.html_only:
        moteur = detecter_moteur(args.moteur)
        if not moteur:
            print("Aucun moteur de rendu PDF détecté.\n"
                  "Installez l'un des suivants :\n"
                  "  sudo apt install wkhtmltopdf\n"
                  "  pip install weasyprint\n"
                  "  sudo apt install chromium-browser\n"
                  "Ou relancez avec --html-only pour produire seulement le HTML.",
                  file=sys.stderr)
            return 1
        print("Moteur de rendu : %s" % moteur)

    if args.sortie:
        os.makedirs(args.sortie, exist_ok=True)

    ok = ignores = echecs = 0
    for chemin in fichiers:
        pdf = nom_cible(chemin, args.sortie)
        if os.path.exists(pdf) and not args.force and not args.html_only:
            print("  = déjà présent : %s" % os.path.basename(pdf))
            ignores += 1
            continue

        try:
            msg = lire_message(chemin)
            doc, pj = construire_html(msg, os.path.basename(chemin), horodatage)
        except Exception as e:
            print("  ! lecture impossible : %s (%s)"
                  % (os.path.basename(chemin), e), file=sys.stderr)
            echecs += 1
            continue

        if args.attachments and pj:
            dossier_pj = os.path.splitext(pdf)[0] + "-pj"
            os.makedirs(dossier_pj, exist_ok=True)
            for i, p in enumerate(pj, 1):
                nom = re.sub(r"[/\\\0]", "_", p["nom"])
                with open(os.path.join(dossier_pj, "%02d-%s" % (i, nom)),
                          "wb") as f:
                    f.write(p["donnees"])

        if args.html_only:
            chemin_html = os.path.splitext(pdf)[0] + ".html"
            with open(chemin_html, "w", encoding="utf-8") as f:
                f.write(doc)
            print("  + %s" % os.path.basename(chemin_html))
            ok += 1
            continue

        with tempfile.NamedTemporaryFile("w", suffix=".html", delete=False,
                                         encoding="utf-8") as tmp:
            tmp.write(doc)
            chemin_html = tmp.name
        try:
            reussi, err = rendre(chemin_html, pdf, moteur)
        finally:
            os.unlink(chemin_html)

        if reussi:
            suffixe = " (%d pj)" % len(pj) if pj else ""
            print("  + %s%s" % (os.path.basename(pdf), suffixe))
            ok += 1
        else:
            print("  ! échec : %s\n    %s" % (os.path.basename(chemin),
                                              err.strip()[:300]),
                  file=sys.stderr)
            echecs += 1

    print("\n==================== RAPPORT ====================")
    print("Convertis ................. %d" % ok)
    print("Déjà présents ............. %d" % ignores)
    print("Échecs .................... %d" % echecs)
    if ok:
        print("\nRelancez ensuite copie-pieces.sh : les nouveaux PDF seront\n"
              "repris automatiquement à la place des .eml.")
    return 0 if echecs == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
