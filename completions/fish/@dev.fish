function __srcery_dev_complete
    set -l tokens (commandline -opc)
    set -l pos (count $tokens)
    if test -n "(commandline -ct)"
        set pos (math $pos - 1)
    end
    command $SRCERY_ROOT/completions/completers/@dev $pos $tokens[2..]
end
complete -c @dev -f -a '(__srcery_dev_complete)'
