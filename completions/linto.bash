_linto_complete() {
  local linto_bin cur prev first groups commands aliases group
  linto_bin="$(cd "$(dirname "${BASH_SOURCE[0]}")/../bin" && pwd -P)/linto"
  COMPREPLY=()
  cur=${COMP_WORDS[COMP_CWORD]}
  prev=${COMP_WORDS[COMP_CWORD-1]}
  first=${COMP_WORDS[1]-}

  if [[ $cur == linto-* && $COMP_CWORD -eq 1 ]]; then
    groups=$("$linto_bin" --list-groups 2>/dev/null)
    commands=$(printf '%s\n' "$groups" | while IFS= read -r group; do
      "$linto_bin" --list-commands "$group" 2>/dev/null | sed "s#^#linto-$group-#"
    done)
    COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
    return
  fi

  if [[ $COMP_CWORD -eq 1 ]]; then
    groups=$("$linto_bin" --list-groups 2>/dev/null)
    commands=$("$linto_bin" --help 2>/dev/null | awk '/^Available commands/ { in_commands=1; next } /^Examples:/ { in_commands=0 } in_commands && /^  [[:alnum:]_-]+$/ { print $1 }')
    aliases=$(printf '%s\n' "$groups" | sed 's#^#linto-#')
    COMPREPLY=( $(compgen -W "help completion $groups $aliases $commands" -- "$cur") )
    return
  fi

  if [[ $first == linto-* && $COMP_CWORD -eq 2 ]]; then
    local group
    group=${first#linto-}
    if [[ $group == *-* ]]; then
      group=${group%%-*}
      COMPREPLY=()
    else
      commands=$("$linto_bin" --list-commands "$group" 2>/dev/null)
      COMPREPLY=( $(compgen -W "$commands -h --help" -- "$cur") )
    fi
    return
  fi



  if [[ $first == completion && $COMP_CWORD -eq 2 ]]; then
    COMPREPLY=( $(compgen -W 'bash zsh fish' -- "$cur") )
    return
  fi

  if [[ $first == help ]]; then
    if [[ $COMP_CWORD -eq 2 ]]; then
      groups=$("$linto_bin" --list-groups 2>/dev/null)
      commands=$("$linto_bin" --help 2>/dev/null | awk '/^Available commands/ { in_commands=1; next } /^Examples:/ { in_commands=0 } in_commands && /^  [[:alnum:]_-]+$/ { print $1 }')
      COMPREPLY=( $(compgen -W "$groups $commands" -- "$cur") )
    elif [[ $COMP_CWORD -eq 3 ]]; then
      commands=$("$linto_bin" --list-commands "$prev" 2>/dev/null)
      COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
    fi
    return
  fi

  if [[ $COMP_CWORD -eq 2 ]]; then
    if groups=$("$linto_bin" --list-groups 2>/dev/null) && [[ " $groups " == *" $first "* ]]; then
      commands=$("$linto_bin" --list-commands "$first" 2>/dev/null)
      COMPREPLY=( $(compgen -W "$commands -h --help" -- "$cur") )
    else
      COMPREPLY=( $(compgen -W '-h --help' -- "$cur") )
    fi
  elif [[ $COMP_CWORD -eq 3 ]]; then
    COMPREPLY=( $(compgen -W '-h --help' -- "$cur") )
  fi
}
complete -F _linto_complete linto
