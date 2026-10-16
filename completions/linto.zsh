#compdef linto

_linto() {
  local -a commands
  local command
  commands=(help completion ${(f)"$(linto --help 2>/dev/null | awk '/^  [[:alnum:]_-]+$/ { print $1 }')"})

  if (( CURRENT == 2 )); then
    _describe 'linto command' commands
  elif (( CURRENT == 3 )); then
    command=$words[2]
    if [[ $command == completion ]]; then
      _values 'shell' bash zsh fish
    else
      _arguments '(-h --help)'{-h,--help}'[Show help]'
    fi
  else
    _arguments '*:argument: '
  fi
}

_linto "$@"
