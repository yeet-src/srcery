function __srcery_cd_complete
    set -l tokens (commandline -opc)
    set -l pos (count $tokens)
    if test -n "(commandline -ct)"
        set pos (math $pos - 1)
    end
    command $SRCERY_ROOT/completions/completers/@cd $pos $tokens[2..]
end
complete -c @cd -f -a '(__srcery_cd_complete)'
