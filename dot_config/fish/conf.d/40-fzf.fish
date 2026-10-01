if status is-interactive
    # fzf.fish uses fd/bat when available. Keep defaults generic so fzf remains
    # useful for non-file inputs as well.
    set -gx FZF_DEFAULT_OPTS '--height=60% --layout=reverse --border --info=inline'

    if type -q fd
        set -g fzf_fd_opts --hidden --follow --exclude=.git
    end
    if type -q bat
        set -g fzf_preview_file_cmd 'bat --color=always --style=numbers --line-range=:500'
    end
    if type -q eza
        set -g fzf_preview_dir_cmd 'eza --all --color=always --group-directories-first'
    end
end
