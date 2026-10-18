"""
pdfguess.py — Retrouve dans le contenu d'un PDF les informations que ses
métadonnées ne donnent pas : title, author, date, organization, url, note.

Partagé par pdf2json.py et pdf2md.py. Ce sont des heuristiques : un champ
trouvé ainsi est signalé dans la clé `guessed` du frontmatter.

Stratégies :
  title         les lignes de plus grande taille en haut de la première page
                (tailles données par `pdftotext -bbox-layout`), sinon la
                première ligne qui ressemble à du texte.
  author        « Auteur : », « Par », « By »…, sinon une ligne qui ressemble à
                des noms de personnes juste après le titre.
  date          date étiquetée (« Date : », « Paris, le », « Published »…) puis
                toute date des premières lignes ; ISO 8601 (AAAA-MM-JJ, AAAA-MM
                ou AAAA).
  organization  une ligne d'en-tête ou de pied de page qui contient un mot
                comme Université, Ministère, Association, Inc., GmbH…
  url           la première adresse http(s):// ou www. de la première page.
  note          une ligne « Note : », « Remarque : »…, sinon un statut
                (Brouillon, Draft, Confidentiel, Version 2…).

Les métadonnées l'emportent, sauf pour la date : la date de création d'un PDF
n'est pas celle du document, alors une date trouvée dans le texte la remplace
et la date de création passe dans `created`.
"""

import calendar
import datetime
import html
import re
import shutil
import subprocess
from dataclasses import dataclass

TOP_LINES = 40

JUNK_TITLE = re.compile(
    r"^(microsoft\s+(word|powerpoint|excel)\b.*|untitled.*|sans\s+titre.*|document\s*\d*|"
    r"présentation\d*|presentation\d*|.*\.(docx?|odt|pptx?|xlsx?|indd|tex|pdf|rtf|txt))$",
    re.IGNORECASE,
)
JUNK_AUTHOR = re.compile(
    r"^(admin(istrat(or|eur))?|user|utilisateur|unknown|inconnu|owner|propriétaire|"
    r"windows\s+user|pc|default|root|author|auteur)$",
    re.IGNORECASE,
)

MONTHS = {
    "janvier": 1, "janv": 1, "fevrier": 2, "février": 2, "fevr": 2, "févr": 2, "mars": 3,
    "avril": 4, "avr": 4, "mai": 5, "juin": 6, "juillet": 7, "juil": 7, "aout": 8,
    "août": 8, "septembre": 9, "sept": 9, "octobre": 10, "oct": 10, "novembre": 11,
    "nov": 11, "decembre": 12, "décembre": 12, "dec": 12, "déc": 12,
    "january": 1, "jan": 1, "february": 2, "feb": 2, "march": 3, "mar": 3,
    "april": 4, "apr": 4, "may": 5, "june": 6, "jun": 6, "july": 7, "jul": 7,
    "august": 8, "aug": 8, "september": 9, "sep": 9, "october": 10,
    "november": 11, "december": 12,
}
MONTH_NAMES = "|".join(sorted(MONTHS, key=len, reverse=True))
DAY = r"(\d{1,2})(?:er|st|nd|rd|th)?"

DATE_LABEL = re.compile(
    r"(date|daté|fait\s+à|publié|publication|published|mis\s+à\s+jour|updated|"
    r"paris,?\s+le|[a-zé]+,?\s+le)\b",
    re.IGNORECASE,
)
DATE_PATTERNS = [
    (re.compile(r"\b(\d{4})-(\d{2})-(\d{2})\b"), lambda m: (m[1], m[2], m[3])),
    (re.compile(r"\b(\d{1,2})[/.](\d{1,2})[/.](\d{4})\b"), lambda m: (m[3], m[2], m[1])),
    (re.compile(rf"\b{DAY}\s+({MONTH_NAMES})\.?,?\s+(\d{{4}})\b", re.IGNORECASE),
     lambda m: (m[3], MONTHS[m[2].lower()], m[1])),
    (re.compile(rf"\b({MONTH_NAMES})\.?\s+{DAY},?\s+(\d{{4}})\b", re.IGNORECASE),
     lambda m: (m[3], MONTHS[m[1].lower()], m[2])),
    (re.compile(rf"\b({MONTH_NAMES})\.?\s+(\d{{4}})\b", re.IGNORECASE),
     lambda m: (m[2], MONTHS[m[1].lower()], None)),
    (re.compile(r"(?:©|\(c\)|copyright)\s*(?:\(c\)\s*)?(\d{4})\b", re.IGNORECASE),
     lambda m: (m[1], None, None)),
]

ORGANIZATION = re.compile(
    r"\b(universit[éey]\w*|université|institut\w*|institute|ministère|ministry|association|"
    r"fondation|foundation|société|company|inc\.?|ltd\.?|llc|sarl|sas|sa|gmbh|"
    r"conseil|council|commission|agence|agency|cour\s+\w+|tribunal|mairie|préfecture|"
    r"département|laboratoire|laboratory|école|school|college|collège|hôpital|hospital|"
    r"syndicat|fédération|federation|gouvernement|government|nations\s+unies|united\s+nations)\b",
    re.IGNORECASE,
)
STATUS = re.compile(
    r"^(brouillon|draft|confidentiel|confidential|projet|ébauche|interne|internal|"
    r"version\s*[\w.]+|v\d+(\.\d+)*)\b.{0,70}$",
    re.IGNORECASE,
)
URL = re.compile(r"(https?://[^\s<>\"')\]]+|\bwww\.[^\s<>\"')\]]+)", re.IGNORECASE)
AUTHOR_LABEL = re.compile(
    r"^(?:auteurs?|authors?|rédigé\s+par|écrit\s+par|written\s+by|par|by|présenté\s+par|"
    r"prepared\s+by)\s*[:\-]?\s+(\S.{2,100})$",
    re.IGNORECASE,
)
NOTE_LABEL = re.compile(r"^(?:notes?|remarques?|nota(?:\s+bene)?|remark)\s*:\s*(\S.{0,300})$", re.IGNORECASE)
NAME_WORD = re.compile(r"^(?:[A-ZÀ-ÖØ-Þ][\w'’\-]*|[A-ZÀ-ÖØ-Þ]\.)$")
NAME_STOP = {
    "rapport", "report", "annual", "annuel", "étude", "study", "guide", "manuel", "manual",
    "chapitre", "chapter", "table", "sommaire", "contents", "introduction", "résumé",
    "abstract", "page", "annexe", "université", "university", "institut", "ministère",
}


@dataclass
class Line:
    text: str
    size: float = 0.0


def first_page_lines(path):
    """Lines of the first page with their height, from `pdftotext -bbox-layout`.

    Returns None when poppler's pdftotext is missing or fails.
    """
    if shutil.which("pdftotext") is None:
        return None
    result = subprocess.run(
        ["pdftotext", "-enc", "UTF-8", "-f", "1", "-l", "1", "-bbox-layout", str(path), "-"],
        capture_output=True, text=True, encoding="utf-8", errors="replace",
    )
    if result.returncode:
        return None
    lines = []
    for match in re.finditer(r'<line [^>]*yMin="([\d.]+)"[^>]*yMax="([\d.]+)"[^>]*>(.*?)</line>',
                             result.stdout, re.DOTALL):
        words = [html.unescape(word) for word in re.findall(r"<word[^>]*>(.*?)</word>", match[3])]
        text = " ".join(words).strip()
        if text:
            lines.append(Line(text, float(match[2]) - float(match[1])))
    return lines or None


def is_noise(text):
    """A line that cannot be a title or a name: page number, URL, date, rule."""
    return (
        len(text) < 3
        or re.fullmatch(r"[\W\d_]+", text) is not None
        or URL.search(text) is not None
        or find_date([text]) is not None
    )


def guess_title(lines):
    candidates = [line for line in lines[:TOP_LINES] if not is_noise(line.text)]
    if not candidates:
        return None
    largest = max(line.size for line in candidates)
    if largest > 0 and any(line.size < largest * 0.9 for line in candidates):
        chosen = []
        for line in candidates:
            if line.size >= largest * 0.9:
                chosen.append(line)
            elif chosen:
                break
        title = " ".join(line.text for line in chosen)
    else:
        title = candidates[0].text
    return title[:200].strip() or None


def split_names(text):
    return [part.strip() for part in re.split(r",|;|\bet\b|\band\b|&", text) if part.strip()]


def looks_like_names(text):
    if len(text) > 90 or re.search(r"\d|@|:", text) or ORGANIZATION.search(text):
        return False
    names = split_names(text)
    if not names:
        return False
    for name in names:
        words = name.split()
        if not 2 <= len(words) <= 5:
            return False
        if not all(NAME_WORD.match(word) for word in words):
            return False
        if any(word.lower() in NAME_STOP for word in words):
            return False
    return True


def guess_author(lines, title):
    texts = [line.text for line in lines[:TOP_LINES]]
    for text in texts:
        match = AUTHOR_LABEL.match(text)
        if match and not re.search(r"\d{4}", match[1]):
            return match[1].strip().rstrip(".")
    if title:
        words = title.split()
        for index, text in enumerate(texts):
            if text.split() and text.split()[0] == words[0]:
                position = index
                while position < len(texts) and texts[position] in title:
                    position += 1
                for candidate in texts[position:position + 6]:
                    if looks_like_names(candidate):
                        return candidate.strip()
                break
    return None


def valid_date(year, month, day):
    year = int(year)
    if not 1900 <= year <= datetime.date.today().year + 1:
        return None
    if month is None:
        return f"{year:04d}"
    month = int(month)
    if not 1 <= month <= 12:
        return None
    if day is None:
        return f"{year:04d}-{month:02d}"
    day = int(day)
    if not 1 <= day <= calendar.monthrange(year, month)[1]:
        return None
    return f"{year:04d}-{month:02d}-{day:02d}"


def find_date(texts):
    """First date found in `texts`, preferring lines that announce a date."""
    unlabelled = None
    for text in texts:
        for pattern, extract in DATE_PATTERNS:
            for match in pattern.finditer(text):
                date = valid_date(*extract(match))
                if not date:
                    continue
                if DATE_LABEL.search(text):
                    return date
                if unlabelled is None:
                    unlabelled = date
    return unlabelled


def guess_date(lines):
    return find_date([line.text for line in lines[:TOP_LINES]])


def guess_organization(lines, title):
    texts = [line.text for line in lines[:25]] + [line.text for line in lines[-10:]]
    for text in texts:
        if len(text) <= 100 and text != title and ORGANIZATION.search(text) and not URL.search(text):
            return text.strip()
    return None


def guess_url(text):
    match = URL.search(text)
    if not match:
        return None
    url = match[1].rstrip(".,;:!?")
    return url if url.lower().startswith("http") else f"https://{url}"


def guess_note(lines):
    texts = [line.text for line in lines[:TOP_LINES]]
    for text in texts:
        match = NOTE_LABEL.match(text)
        if match:
            return match[1].strip()
    for text in texts[:15]:
        if STATUS.match(text):
            return text.strip()
    return None


def lines_from_text(text):
    return [Line(line.strip()) for line in text.splitlines() if line.strip()]


def usable_title(title):
    return isinstance(title, str) and title.strip() and not JUNK_TITLE.match(title.strip())


def usable_author(author):
    return isinstance(author, str) and author.strip() and not JUNK_AUTHOR.match(author.strip())


# Metadata fields that already hold one of the wanted values under another name.
ALIASES = {
    "organization": ("organisation", "company", "publisher", "institution", "organization_name"),
    "url": ("source", "website", "link"),
    "note": ("comments", "comment", "description", "notes"),
}


def adopt_aliases(frontmatter):
    for name, aliases in ALIASES.items():
        if name in frontmatter:
            continue
        for alias in aliases:
            value = frontmatter.get(alias)
            if isinstance(value, str) and value.strip() and (name != "url" or value.startswith("http")):
                frontmatter[name] = value.strip()
                break


def fill_frontmatter(frontmatter, text, page_lines=None, filename_key=None):
    """Complete `frontmatter` in place with what the document itself says.

    `page_lines` are the lines of the first page with their sizes (see
    first_page_lines); without them the first lines of `text` are used.
    Returns the names of the fields that were guessed.
    """
    adopt_aliases(frontmatter)
    lines = page_lines or lines_from_text(text)
    guessed = []

    title = frontmatter.get("title")
    if not usable_title(title) or title == filename_key:
        found = guess_title(lines)
        if found:
            if title:
                frontmatter["title_metadata"] = title
            frontmatter["title"] = found
            guessed.append("title")
    current_title = frontmatter.get("title")

    author = frontmatter.get("author")
    if not usable_author(author):
        found = guess_author(lines, current_title)
        if found:
            if author:
                frontmatter["author_metadata"] = author
            frontmatter["author"] = found
            guessed.append("author")

    found = guess_date(lines)
    if found:
        created = frontmatter.get("date")
        if created and not str(created).startswith(found):
            frontmatter["created"] = created
        frontmatter["date"] = found
        guessed.append("date")

    if "organization" not in frontmatter:
        found = guess_organization(lines, current_title)
        if found:
            frontmatter["organization"] = found
            guessed.append("organization")

    if "url" not in frontmatter:
        found = guess_url("\n".join(line.text for line in lines))
        if found:
            frontmatter["url"] = found
            guessed.append("url")

    if "note" not in frontmatter:
        found = guess_note(lines)
        if found:
            frontmatter["note"] = found
            guessed.append("note")
    return guessed
