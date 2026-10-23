set -g linto_bin (realpath (dirname (status filename))/../bin/linto)
source (dirname (realpath (status filename)))/linto-args.fish
complete -c linto -f -n '__fish_use_subcommand' -a 'help completion'
complete -c linto -f -n '__fish_use_subcommand' -a '($linto_bin --list-groups 2>/dev/null)'
complete -c linto -f -n '__fish_use_subcommand' -a '($linto_bin --list-shortcuts 2>/dev/null)'
complete -c linto -f -n '__fish_seen_subcommand_from completion' -a 'bash zsh fish'
complete -c linto -f -n '__fish_seen_subcommand_from beta linto-beta; and __linto_needs_command' -a '($linto_bin --list-commands beta 2>/dev/null)'

complete -c linto -f -n '__fish_seen_subcommand_from bib linto-bib; and __linto_needs_command' -a '($linto_bin --list-commands bib 2>/dev/null)'

complete -c linto -f -n '__fish_seen_subcommand_from launch linto-launch; and __linto_needs_command' -a '($linto_bin --list-commands launch 2>/dev/null)'

complete -c linto -f -n '__fish_seen_subcommand_from linto linto-linto; and __linto_needs_command' -a '($linto_bin --list-commands linto 2>/dev/null)'

complete -c linto -f -n '__fish_seen_subcommand_from quarto linto-quarto; and __linto_needs_command' -a '($linto_bin --list-commands quarto 2>/dev/null)'

complete -c linto -f -n '__fish_seen_subcommand_from utils linto-utils; and __linto_needs_command' -a '($linto_bin --list-commands utils 2>/dev/null)'

complete -c linto -f -n '__fish_seen_subcommand_from help' -a '($linto_bin --list-groups 2>/dev/null)'
complete -c linto -f -n '__fish_seen_subcommand_from help' -a '($linto_bin --list-shortcuts 2>/dev/null)'
complete -c linto -l help -s h -d 'Show help'
complete -c linto -l version -s V -d 'Show the version'
