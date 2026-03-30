function __srcery_sy_complete
    set -l tokens (commandline -opc)
    set -l pos (count $tokens)
    if test -n "(commandline -ct)"
        set pos (math $pos - 1)
    end
    command /Users/ben/src/yeet/srcery/completions/completers/sy $pos $tokens[2..]
end
complete -c sy -f -a '(__srcery_sy_complete)'
