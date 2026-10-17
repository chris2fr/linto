#!/bin/sh
# listcitations2piecesyml.sh -- turn a list of citations into a YAML mapping.
#
# Entrée : une liste de citations, une par ligne (fichier ou entrée standard).
# Sortie : "valeur": n, dans l'ordre de première apparition,
#          n commençant à <debut> (défaut : 1).
#
# Usage :
#   ./listcitations2piecesyml.sh [fichier] [debut]
#   ./listcitations2piecesyml.sh [debut] < fichier
#   une commande | ./listcitations2piecesyml.sh [debut]
#
# Sans fichier, l'entrée standard est lue. Si un fichier est donné mais
# n'est pas lisible, le script s'arrête en erreur (pas de repli silencieux
# sur l'entrée standard).

usage() {
    cat <<EOF
Usage: $0 [-h|--help] [fichier] [debut]
       $0 [debut] < fichier

Convertit les citations (une par ligne) en mapping YAML, en conservant leur
ordre de première apparition. Sans fichier, lit l'entrée standard.
EOF
}

case "${1-}" in
    -h|--help) usage; exit 0 ;;
    --) shift ;;
    -*) echo "$0: option inconnue : $1" >&2; usage >&2; exit 2 ;;
esac

# --- Interpréter les arguments ----------------------------------------------
# Premier argument : soit un nom de fichier, soit le numéro de départ.
#   - un fichier existant et lisible  -> on lit ce fichier
#   - un entier (donc pas un fichier) -> on lit l'entrée standard
#   - autre chose (ex. fichier mal orthographié) -> erreur explicite
if [ $# -ge 1 ]; then
    if [ -f "$1" ] && [ -r "$1" ]; then
        file=$1
        shift
        start=${1:-1}
    elif [ -e "$1" ]; then
        # Existe mais n'est pas un fichier lisible (répertoire, permissions...).
        echo "Erreur : '$1' n'est pas un fichier lisible" >&2
        exit 1
    else
        case $1 in
            ''|*[!0-9]*)
                # Ni un fichier existant, ni un entier : fichier mal orthographié
                # ou numéro de départ invalide.
                echo "Erreur : '$1' n'est ni un fichier lisible ni un entier positif" >&2
                usage
                exit 1
                ;;
            *)
                file=
                start=$1
                ;;
        esac
    fi
else
    file=
    start=1
fi

# Vérifier que <debut> est bien un entier.
case $start in
    ''|*[!0-9]*)
        echo "Erreur : '$start' n'est pas un entier positif" >&2
        exit 1
        ;;
esac

# --- Traiter la liste --------------------------------------------------------
process() {
    awk -v n="$start" '
        /^[[:space:]]*$/ { next }
        !seen[$0]++ { printf "\"%s\": %d\n", $0, n++ }
    '
}

if [ -n "$file" ]; then
    process < "$file"
else
    # Aucun fichier : lire l'entrée standard.
    process
fi
