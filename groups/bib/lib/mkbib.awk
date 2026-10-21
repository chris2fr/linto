/^@[[:alnum:]_]+\{/ {
    if (out != "") close(out)

    key = $0
    sub(/^@[[:alnum:]_]+\{/, "", key)
    sub(/,.*/, "", key)

    out = outdir "/" key ".bib"
}

out != "" {
    print > out
}