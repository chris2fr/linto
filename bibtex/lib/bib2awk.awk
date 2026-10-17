#!/usr/bin/env gawk -f
#
# bib2csv.awk
#
# Extracts the citekey plus a fixed set of fields from a .bib file into a
# semicolon-separated CSV.
#
# Usage:
#   gawk -f bib2csv.awk input.bib > output.csv
#   gawk -v theme="acp" -f bib2csv.awk input.bib > output.csv
#   gawk -v theme="acp,far" -f bib2csv.awk input.bib > output.csv
#
# The optional theme parameter filters output to entries whose theme
# field matches one of the given values (comma-separated, case-insensitive,
# whitespace-trimmed). If an entry's own theme field holds multiple
# tokens (comma- or semicolon-separated), a match on any one token is
# enough to include the entry. Leave theme unset (or empty) for no
# filtering.
#
# Requires GNU awk (gawk) because it uses IGNORECASE for case-insensitive
# field-name matching. Tested against entries of the form:
#
#   @article{someKey2024,
#     title    = {Some {T}itle},
#     author   = {Last, First and Other, Person},
#     abstract = "A quoted value",
#     year     = 2024,
#     ...
#   }
#
# Notes / limitations:
#   - @comment, @string and @preamble entries are skipped.
#   - String concatenation with '#' and @string macro expansion are NOT
#     resolved; the raw text is emitted as-is.
#   - Field values delimited by {...} may contain nested braces (e.g. for
#     case protection); these are handled via brace-depth counting.
#   - Field values delimited by "..." are read up to the next unescaped
#     double quote (standard BibTeX does not allow braces to nest inside
#     quotes for this purpose, so this is the common case).
#   - Bare/unquoted values (e.g. year = 2024, or a @string macro key) are
#     read up to the next comma, closing brace, or newline.
#   - Internal newlines/tabs in a value are collapsed to single spaces.
#   - CSV quoting is applied whenever a value contains a semicolon, a
#     double quote, or a newline (double quotes are doubled per CSV rules).

 # abstract
 # author
 # date
 # edition
 # file
 # howpublished
 # keywords
 # language
 # month
 # note
 # number
 # organization
 # publisher
 # shorthand
 # shorthand2
 # title
 # type
 # url
 # urldate
 # xacronym
 # xcounter
 # xdatetime
 # xduplicate
 # xeditionorig
 # xeditionorig2
 # xeditionorig3
 # xfileorig
 # xkeyorig
 # xkeyorig2
 # xkeyorig3
 # xkeyorig4
 # xnumberorig
 # xshorthandorig
 # xshorthandorig2
 # xtheme
 # xtime
 # xtype
 # xtypeorig
 # year


BEGIN {
    IGNORECASE = 1
    # Split records on "\n@" (a newline immediately followed by "@"),
    # not on every bare "@". A plain RS="@" would also split mid-record
    # whenever a field value contains an "@" (e.g. an email address in
    # an author/published/howpublished field), silently truncating the
    # entry and dropping every field that came after it.
    RS = "\n@"
    OFS = ";"

    if (format == "")
        output_format = "1" # changer pour les formats de sorti 1, 2 ou 3
    else
        output_format = format

    n = split("key abstract author date edition file howpublished keywords language month note number organization publisher shorthand shorthand2 title type url urldate xacronym xcontentmd xcounter xdatetime xduplicate xeditionorig xeditionorig2 xeditionorig3 xfileorig xkeyorig xkeyorig2 xkeyorig3 xkeyorig4 xnumberorig xshorthandorig xshorthandorig2 xtheme xtime xtype xtypeorig year", fld, " ")

    # Map field name -> position, so the theme filter doesn't rely on a
    # hardcoded index and stays correct if the field list above changes.
    for (i = 1; i <= n; i++) fldidx[fld[i]] = i

    # Optional -v theme="val1,val2,..." filter, case-insensitive.
    filtering = 0
    if (theme != "") {
        m = split(theme, themelist, ",")
        for (i = 1; i <= m; i++) {
            t = themelist[i]
            gsub(/^[ \t]+|[ \t]+$/, "", t)
            if (t != "") {
                themefilter[tolower(t)] = 1
                filtering = 1
            }
        }
    }

    if (output_format == "1")
        format1_begin(fld, n)
    if (output_format == "2")
        format2_begin()
    if (output_format == "3")
        format3_begin()
}


{
    rec = $0
    sub(/^@/, "", rec)
    if (rec !~ /^[A-Za-z]+[ \t\n]*\{/) next
    match(rec, /^[A-Za-z]+/)
    etype = substr(rec, RSTART, RLENGTH)
    letype = tolower(etype)
    if (letype == "comment" || letype == "string" || letype == "preamble") next
    bpos = index(rec, "{")
    if (!bpos) next
    rest = substr(rec, bpos + 1)
    cpos = index(rest, ",")
    if (!cpos) next
    key = substr(rest, 1, cpos - 1)
    gsub(/^[ \t\n\r]+|[ \t\n\r]+$/, "", key)

    # date = getfield(rec, "date")

    # Extract every remaining field once into vals[], so the theme
    # filter check below and the final print both reuse the same values
    # instead of calling getfield() twice for the same field.
    # delete vals
    vals[1] = key
    for (i = 2; i <= n; i++) {
        vals[i] = getfield(rec, fld[i])
    }

    if (filtering && !theme_match(vals[fldidx["keywords"]])) {
        next
    }

    if (output_format == "1")
        format1_output(vals, fldidx, fld)
    if (output_format == "2")
        format2_output(vals, fldidx, fld)
    if (output_format == "3")
        format3_output(vals, fldidx, fld)
}


# Return 1 if val's theme content matches the -v theme filter (or if no
# filter is active), 0 otherwise. Splits val on comma/semicolon in case a
# single entry's theme field holds more than one tag.
function theme_match(val, i, m, toks, t) {
    if (!filtering) return 1
    m = split(val, toks, /[,;]/)
    for (i = 1; i <= m; i++) {
        t = toks[i]
        gsub(/^[ \t]+|[ \t]+$/, "", t)
        if (tolower(t) in themefilter) return 1
    }
    return 0
}

# Locate and extract the value of field "name" within BibTeX entry text "rec".
function getfield(rec, name, re, pos, eq, i, len, ch, depth, start, val, delim) {
    re = "[,{[:space:]]" name "[ \t\n]*="
    pos = match(rec, re)
    if (pos == 0) return ""

    eq = pos + RLENGTH - 1     # index of the "=" character (last char of match)
    i = eq + 1
    len = length(rec)

    while (i <= len && substr(rec, i, 1) ~ /[ \t\n\r]/) i++
    delim = substr(rec, i, 1)

    if (delim == "{") {
        depth = 1
        i++
        start = i
        while (i <= len && depth > 0) {
            ch = substr(rec, i, 1)
            if (ch == "{") depth++
            else if (ch == "}") depth--
            if (depth > 0) i++
        }
        val = substr(rec, start, i - start)

    } else if (delim == "\"") {
        i++
        start = i
        while (i <= len) {
            ch = substr(rec, i, 1)
            if (ch == "\"") break
            i++
        }
        val = substr(rec, start, i - start)

    } else {
        start = i
        while (i <= len && substr(rec, i, 1) !~ /[,\n}]/) i++
        val = substr(rec, start, i - start)
        gsub(/[ \t\r]+$/, "", val)
    }

    return val
}

# Clean and CSV-escape a field value.         s = "\"" s "\""
function csv(s) {
    gsub(/\r/, "", s)
    gsub(/\n/, " ", s)
    gsub(/[ \t]+/, " ", s)
    sub(/^ /, "", s)
    sub(/ $/, "", s)
    if (s ~ /[;"\n]/) {
        gsub(/"/, "_", s)
        gsub(/;/, "_", s)
    }
    return s
}

# Clean and JSON-escape a field value.         s = "\"" s "\""
function json(s) {
    gsub(/\r/, "", s)
    gsub(/\n/, "\\n", s)
    gsub(/\t/, "\\t", s)
    sub(/^ /, "", s)
    sub(/ $/, "", s)
    gsub(/"/, "\\\"", s)
    return s
}