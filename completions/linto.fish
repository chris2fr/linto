set -l linto_bin (realpath (dirname (status filename))/../bin/linto)

complete -c linto -f -n '__fish_use_subcommand' -a 'help completion'
complete -c linto -f -n '__fish_use_subcommand' -a '($linto_bin --list-groups 2>/dev/null)'
complete -c linto -f -n '__fish_use_subcommand' -a '($linto_bin --list-groups 2>/dev/null | string replace -r "^(.*)$" "linto-$1")'
complete -c linto -f -n '__fish_use_subcommand' -a '($linto_bin --help 2>/dev/null | string match -r "^  [[:alnum:]_-]+" | string trim)'
complete -c linto -f -n '__fish_seen_subcommand_from completion' -a 'bash zsh fish'

for group in ($linto_bin --list-groups 2>/dev/null)
    complete -c linto -f -n "__fish_seen_subcommand_from $group linto-$group" -a "($linto_bin --list-commands $group 2>/dev/null)"
    complete -c linto -f -n '__fish_use_subcommand' -a "($linto_bin --list-commands $group 2>/dev/null | string replace -r '^(.*)$' 'linto-$group-$1')"
end

complete -c linto -f -n '__fish_seen_subcommand_from help' -a '($linto_bin --list-groups 2>/dev/null)'
complete -c linto -f -n '__fish_seen_subcommand_from help' -a '($linto_bin --help 2>/dev/null | string match -r "^  [[:alnum:]_-]+" | string trim)'
complete -c linto -l help -s h -d 'Show help'
