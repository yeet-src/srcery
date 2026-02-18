function __srcery_svc_stop_complete
    set -l tokens (commandline -opc)
    set -l pos (count $tokens)
    if test -n "(commandline -ct)"
        set pos (math $pos - 1)
    end
    command $SRCERY_ROOT/completions/completers/@svc-stop $pos $tokens[2..]
end
complete -c @svc-stop -f -a '(__srcery_svc_stop_complete)'
