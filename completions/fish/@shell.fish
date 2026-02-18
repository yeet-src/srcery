function __srcery_shell_complete
    set -l tokens (commandline -opc)
    set -l pos (count $tokens)
    if test -n "(commandline -ct)"
        set pos (math $pos - 1)
    end
    command $SRCERY_ROOT/completions/completers/@shell $pos $tokens[2..]
end
complete -c @shell -f -a '(__srcery_shell_complete)'
