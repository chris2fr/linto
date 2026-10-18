# Completion of the arguments of linto commands; sourced by linto.fish.
# $linto_bin is the dispatcher. See lib/complete.py for what it reports.

function __linto_complete_args
    set -l prior (commandline -opc)
    set -l current (commandline -ct)
    set -l reply ($linto_bin --complete $prior[2..-1] "$current" 2>/dev/null)
    test (count $reply) -gt 0; or return

    set -l kind (string split \t -- $reply[1])
    switch $kind[1]
        case files dirs
            for candidate in (__fish_complete_path "$current")
                set -l path (string split -f1 \t -- $candidate)
                if string match -q -- '*/' $path
                    echo $candidate
                else if test $kind[1] = files
                    set -l keep 1
                    if test (count $kind) -ge 2
                        set keep 0
                        for glob in (string split , -- $kind[2])
                            if string match -q -- $glob (path basename -- $path)
                                set keep 1
                            end
                        end
                    end
                    test $keep = 1; and echo $candidate
                end
            end
        case words
            printf '%s\n' $reply[2..-1]
    end
end

# True while the group (or group alias) has been typed but not its command.
function __linto_needs_command
    test (count (commandline -opc)) -eq 2
end

complete -c linto -f -n 'test (count (commandline -opc)) -ge 2' -a '(__linto_complete_args)'
