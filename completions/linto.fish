
complete -c linto -f -n '__fish_use_subcommand' -a 'help completion'
complete -c linto -f -n '__fish_use_subcommand' -a '(linto --help 2>/dev/null | string match -r "^  [[:alnum:]_-]+" | string trim)'
complete -c linto -f -n '__fish_seen_subcommand_from completion' -a 'bash zsh fish'
complete -c linto -l help -s h -d 'Show help'
