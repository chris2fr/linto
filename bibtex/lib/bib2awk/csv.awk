function format1_begin(fld, count, i) {
    for (i = 1; i <= count; i++) printf "%s;", fld[i]
    printf "\n"
}

function format1_output(vals, fldidx, fld, count, i) {
    count = length(fldidx)
    for (i = 1; i <= count; i++) printf "%s;", csv(vals[i])
    printf "\n"
}
