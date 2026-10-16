_linto_complete() {
  local cur prev commands
  COMPREPLY=()
  cur=${COMP_WORDS[COMP_CWORD]}
  prev=${COMP_WORDS[COMP_CWORD-1]}

  if [[ $COMP_CWORD -eq 1 ]]; then
    commands=$(linto --help 2>/dev/null | awk '/^  [[:alnum:]_-]+$/ { print $1 }')
    COMPREPLY=( $(compgen -W "help completion $commands" -- "$cur") )
  elif [[ $prev == completion ]]; then
    COMPREPLY=( $(compgen -W 'bash zsh fish' -- "$cur") )
  elif [[ $COMP_CWORD -eq 2 && $prev != help ]]; then
    COMPREPLY=( $(compgen -W '-h --help' -- "$cur") )
  fi
}
complete -F _linto_complete linto
