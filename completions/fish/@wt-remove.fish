function __srcery_wt_remove_complete
    set -l tokens (commandline -opc)
    set -l pos (count $tokens)
    if test -n (commandline -ct)
        set pos (math $pos - 1)
    end
    command $SRCERY_ROOT/completions/completers/@wt-remove $pos $tokens[2..]
end
complete -c @wt-remove -f -a '(__srcery_wt_remove_complete)'
