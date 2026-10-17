#compdef linto

_linto() {
  local -a commands groups group_commands
  local command group
  groups=(${(f)"$(linto --help 2>/dev/null | awk '/^Groups:$/ { in_groups=1; next } /^Commands/ { in_groups=0 } in_groups && /^  [[:alnum:]_-]+$/ { print $1 }')"})
  commands=(${(f)"$(linto --help 2>/dev/null | awk '/^Commands \(also available/ { in_commands=1; next } /^Examples:/ { in_commands=0 } in_commands && /^  [[:alnum:]_-]+$/ { print $1 }')"})

  if (( CURRENT == 2 )); then
    _describe 'linto command or group' commands
    _describe 'linto group' groups
    _values 'special command' help completion
  elif (( CURRENT == 3 )); then
    command=$words[2]
    if [[ $command == completion ]]; then
      _values 'shell' bash zsh fish
    elif [[ $command == help ]]; then
      _describe 'group or command' groups
      _describe 'command' commands
    elif (( ${groups[(Ie)$command]} )); then
      case $command in
        utils) group_commands=(prettyprint stripaccents) ;;
        quarto) group_commands=(firefox-open-version guillemets2quotes listcitations2piecesyml qmd-extract-citations render) ;;
        bibtex) group_commands=(bib2json build-bib format-single-bib json2bib mkbib) ;;
        internal) group_commands=(add2profile addpath) ;;
        *) group_commands=() ;;
      esac
      _describe "$command command" group_commands
    else
      _arguments '(-h --help)'{-h,--help}'[Show help]'
    fi
  elif (( CURRENT == 4 )); then
    _arguments '(-h --help)'{-h,--help}'[Show help]'
  else
    _arguments '*:argument: '
  fi
}

_linto "$@"
