#compdef linto

_linto() {
  local -a commands groups group_commands aliases
  local command group linto_bin completion_file
  completion_file="${${funcsourcetrace[1]:-${(%):-%x}}}"
  linto_bin="$(cd "$(dirname "$completion_file")/../bin" && pwd -P)/linto"
  groups=(${(f)"$("$linto_bin" --list-groups 2>/dev/null)"})
  commands=(${(f)"$("$linto_bin" --help 2>/dev/null | awk '/^Available commands/ { in_commands=1; next } /^Examples:/ { in_commands=0 } in_commands && /^  [[:alnum:]_-]+$/ { print $1 }')"})

  if (( CURRENT == 2 )); then
    aliases=(linto-${^groups})
    _describe 'linto command' commands
    _describe 'linto group' groups
    _describe 'group alias' aliases
    _values 'special command' help completion
  elif [[ $words[2] == completion ]] && (( CURRENT == 3 )); then
    _values 'shell' bash zsh fish
  elif [[ $words[2] == help ]]; then
    if (( CURRENT == 3 )); then
      _describe 'group' groups
      _describe 'command' commands
    elif (( CURRENT == 4 )); then
      group=$words[3]
      group_commands=(${(f)"$("$linto_bin" --list-commands "$group" 2>/dev/null)"})
      _describe "$group command" group_commands
    fi
  elif [[ $words[2] == linto-* ]]; then
    group=${words[2]#linto-}
    if [[ $group == *-* ]]; then
      _arguments '*:argument: '
    elif (( CURRENT == 3 )); then
      group_commands=(${(f)"$("$linto_bin" --list-commands "$group" 2>/dev/null)"})
      _describe "$group command" group_commands
    else
      _arguments '*:argument: '
    fi
  elif (( ${groups[(Ie)$words[2]]} )); then
    group=$words[2]
    if (( CURRENT == 3 )); then
      group_commands=(${(f)"$("$linto_bin" --list-commands "$group" 2>/dev/null)"})
      _describe "$group command" group_commands
    else
      _arguments '(-h --help)'{-h,--help}'[Show help]'
    fi
  elif (( CURRENT == 3 )); then
    _arguments '(-h --help)'{-h,--help}'[Show help]'
  else
    _arguments '*:argument: '
  fi
}

_linto "$@"
