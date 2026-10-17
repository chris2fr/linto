set -g linto_bin (realpath (dirname (status filename))/../bin/linto)
complete -c linto -f -n '__fish_use_subcommand' -a 'help completion'
complete -c linto -f -n '__fish_use_subcommand' -a '($linto_bin --list-groups 2>/dev/null)'
complete -c linto -f -n '__fish_use_subcommand' -a '($linto_bin --list-groups 2>/dev/null | while read -l group; $linto_bin --list-commands $group 2>/dev/null; end | sort -u)'
complete -c linto -f -n '__fish_seen_subcommand_from completion' -a 'bash zsh fish'
complete -c linto -f -n '__fish_seen_subcommand_from beta linto-beta' -a '($linto_bin --list-commands beta 2>/dev/null)'

complete -c linto -f -n '__fish_seen_subcommand_from launch linto-launch' -a '($linto_bin --list-commands launch 2>/dev/null)'

complete -c linto -f -n '__fish_seen_subcommand_from linto linto-linto' -a '($linto_bin --list-commands linto 2>/dev/null)'

complete -c linto -f -n '__fish_seen_subcommand_from quarto linto-quarto' -a '($linto_bin --list-commands quarto 2>/dev/null)'

complete -c linto -f -n '__fish_seen_subcommand_from utils linto-utils' -a '($linto_bin --list-commands utils 2>/dev/null)'

complete -c linto -f -n '__fish_seen_subcommand_from biblio linto-biblio' -a '($linto_bin --list-commands biblio 2>/dev/null)'

complete -c linto -f -n '__fish_seen_subcommand_from help' -a '($linto_bin --list-groups 2>/dev/null)'
complete -c linto -f -n '__fish_seen_subcommand_from help' -a '($linto_bin --list-groups 2>/dev/null | while read -l group; $linto_bin --list-commands $group 2>/dev/null; end | sort -u)'
complete -c linto -l help -s h -d 'Show help'
