if status is-interactive
    set -l fzf_git "$HOME/.local/share/fzf-git.sh/fzf-git.fish"
    if test -f "$fzf_git"
        source "$fzf_git"
    end
end
