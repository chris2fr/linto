function format_begin(fld, count) {
}

function format_output(vals, fldidx, fld, count, i, firstfield) {
    if (out != "") close(out)

    key = vals[fldidx["key"]]
    out = "./bib/" key ".json"

    printf "{" > out
    count = length(fldidx)
    firstfield = ""
    for (i = 1; i <= count; i++) {
        if (vals[i]) {
            printf "%s\n  \"%s\":\"%s\"", firstfield, fld[i], json(vals[i]) > out
            firstfield = ","
        }
    }
    printf "\n}\n" > out
}
