if status is-interactive
    # eza is close enough to ls for interactive use. Keep cat untouched because
    # bat intentionally differs in paging/formatting and is safer as `b`.
    if type -q eza
        alias ls='eza --group-directories-first'
        alias ll='eza -lah --git --group-directories-first'
        alias lt='eza --tree --level=2 --group-directories-first'
    end

    if type -q bat
        alias b='bat'
    end

    alias gs='git status'
    alias gd='git diff'
    alias gl='git log --oneline --graph --decorate'
end
