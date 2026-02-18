function __srcery_attach_complete
    set -l tokens (commandline -opc)
    set -l pos (count $tokens)
    if test -n "(commandline -ct)"
        set pos (math $pos - 1)
    end
    command $SRCERY_ROOT/completions/completers/@attach $pos $tokens[2..]
end
complete -c @attach -f -a '(__srcery_attach_complete)'
