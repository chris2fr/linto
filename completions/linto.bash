_linto_complete() {
  local linto_bin cur prev first groups commands aliases group
  local -a reply globs
  local kind patterns entry pattern matched
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
    aliases=$($linto_bin --list-shortcuts 2>/dev/null | sed 's#^#linto-#')
    COMPREPLY=( $(compgen -W "$commands $aliases" -- "$cur") )
    return
  fi

  if [[ $COMP_CWORD -eq 1 ]]; then
    groups=$("$linto_bin" --list-groups 2>/dev/null)
    commands=$("$linto_bin" --list-shortcuts 2>/dev/null)
    aliases=$(printf '%s\n' "$groups" | sed 's#^#linto-#')
    grouped_commands=$(printf '%s\n' "$groups" | sed 's#^#linto #')
    COMPREPLY=( $(compgen -W "help completion $groups $grouped_commands $aliases $commands" -- "$cur") )
    return
  fi

  # Past the command name, ask the dispatcher what the command's arguments
  # look like (see lib/complete.py); it prints nothing while the cursor is still
  # on a group or command name.
  if [[ $COMP_CWORD -ge 2 && $first != help && $first != completion ]]; then
    mapfile -t reply < <("$linto_bin" --complete "${COMP_WORDS[@]:1:COMP_CWORD}" 2>/dev/null)
    if (( ${#reply[@]} )); then
      kind=${reply[0]%%$'\t'*}
      patterns=
      [[ ${reply[0]} == *$'\t'* ]] && patterns=${reply[0]#*$'\t'}
      case $kind in
        files|dirs)
          compopt -o filenames 2>/dev/null
          while IFS= read -r entry; do
            [[ -n $entry ]] || continue
            if [[ -d $entry ]]; then
              COMPREPLY+=("$entry")
            elif [[ $kind == files ]]; then
              matched=
              if [[ -z $patterns ]]; then
                matched=1
              else
                IFS=, read -ra globs <<< "$patterns"
                for pattern in "${globs[@]}"; do
                  [[ ${entry##*/} == $pattern ]] && matched=1
                done
              fi
              [[ -n $matched ]] && COMPREPLY+=("$entry")
            fi
          done < <(compgen -f -- "$cur")
          ;;
        words)
          # Bash cannot show descriptions; keep only the words.
          COMPREPLY=( $(compgen -W "$(printf '%s\n' "${reply[@]:1}" | cut -f1)" -- "$cur") )
          ;;
      esac
      return
    fi
  fi

  if [[ $first == linto-* && $COMP_CWORD -eq 2 ]]; then
    group=${first#linto-}
    if [[ $group == *-* ]]; then
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
      commands=$("$linto_bin" --list-shortcuts 2>/dev/null)
      COMPREPLY=( $(compgen -W "$groups $commands" -- "$cur") )
    elif [[ $COMP_CWORD -eq 3 ]]; then
      commands=$("$linto_bin" --list-commands "$prev" 2>/dev/null)
      COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
    fi
    return
  fi

  if [[ $COMP_CWORD -eq 2 ]]; then
    if groups=$("$linto_bin" --list-groups 2>/dev/null) && [[ $'\n'$groups$'\n' == *$'\n'"$first"$'\n'* ]]; then
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
