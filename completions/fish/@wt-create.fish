function __srcery_wt_create_complete
    set -l tokens (commandline -opc)
    set -l pos (count $tokens)
    if test -n "(commandline -ct)"
        set pos (math $pos - 1)
    end
    command $SRCERY_ROOT/completions/completers/@wt-create $pos $tokens[2..]
end
complete -c @wt-create -f -a '(__srcery_wt_create_complete)'
