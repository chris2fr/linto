_linto_complete() {
  local cur prev commands groups
  COMPREPLY=()
  cur=${COMP_WORDS[COMP_CWORD]}
  prev=${COMP_WORDS[COMP_CWORD-1]}

  if [[ $COMP_CWORD -eq 1 ]]; then
    commands=$(linto --help 2>/dev/null | awk '/^  [[:alnum:]_-]+$/ { print $1 }')
    groups=$(linto --help 2>/dev/null | awk '/^Groups:$/ { in_groups=1; next } /^Commands/ { in_groups=0 } in_groups && /^  [[:alnum:]_-]+$/ { print $1 }')
    COMPREPLY=( $(compgen -W "help completion $groups $commands" -- "$cur") )
  elif [[ ${COMP_WORDS[1]} == help ]]; then
    if [[ $COMP_CWORD -eq 2 ]]; then
      groups=$(linto --help 2>/dev/null | awk '/^Groups:$/ { in_groups=1; next } /^Commands/ { in_groups=0 } in_groups && /^  [[:alnum:]_-]+$/ { print $1 }')
      commands=$(linto --help 2>/dev/null | awk '/^Commands/ { in_commands=1; next } /^Examples:/ { in_commands=0 } in_commands && /^  [[:alnum:]_-]+$/ { print $1 }')
      COMPREPLY=( $(compgen -W "$groups $commands" -- "$cur") )
    elif [[ $COMP_CWORD -eq 3 ]]; then
      commands=$(linto --help 2>/dev/null | awk -v group="${COMP_WORDS[2]}" '$0 == "Commands (also available as GROUP COMMAND):" { in_commands=1; next } /^Examples:/ { in_commands=0 } in_commands { print $1 }')
      COMPREPLY=( $(compgen -W "$commands -h --help" -- "$cur") )
    fi
  elif [[ $COMP_CWORD -eq 2 ]]; then
    case "$prev" in
      completion) COMPREPLY=( $(compgen -W 'bash zsh fish' -- "$cur") ) ;;
      utils|quarto|bibtex|internal|beta|awk)
        commands=$(linto --help 2>/dev/null | awk -v group="$prev" '$0 == "Commands (also available as GROUP COMMAND):" { in_commands=1; next } /^Examples:/ { in_commands=0 } in_commands && /^  [[:alnum:]_-]+$/ { print $1 }')
        case "$prev" in
          utils) commands='prettyprint stripaccents' ;;
          quarto) commands='firefox-open-version guillemets2quotes listcitations2piecesyml qmd-extract-citations render' ;;
          bibtex) commands='bib2json build-bib format-single-bib json2bib mkbib' ;;
          internal) commands='add2profile addpath' ;;
          *) commands='' ;;
        esac
        COMPREPLY=( $(compgen -W "$commands -h --help" -- "$cur") )
        ;;
      *) COMPREPLY=( $(compgen -W '-h --help' -- "$cur") ) ;;
    esac
  elif [[ $COMP_CWORD -eq 3 ]]; then
    COMPREPLY=( $(compgen -W '-h --help' -- "$cur") )
  fi
}
complete -F _linto_complete linto
