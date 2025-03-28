# I've noticed this file gets called multiple times. 
# todo, investigate later.
# status stack-trace

#   upfront add homebrew stuff to path

# set fish_trace 1
# /Users/paulirish/.homebrew/bin/fish --debug "*" # super noisy
# see `fish --print-debug-categories`
# /Users/paulirish/.homebrew/bin/fish --debug "abbrs ast-construction char-encoding complete config debug env-dispatch env-export env-locale error event exec exec-fork exec-job-exec exec-job-status fd-monitor history history-file iothread output-invalid path proc-internal-proc proc-job-run proc-pgroup proc-reap-external proc-reap-internal proc-termowner profile-history reader reader-render screen term-support topic-monitor uvar-file uvar-notifier warning warning-path" 

function fish_greeting
end

# TODO: path and aliases are kinda slow to source. optimize later.
function ssource --description "source most of my dotfiles, useful if making changes and iterating"

    source ~/.config/fish/path.fish
    source ~/.config/fish/aliases.fish
    source ~/.config/fish/functions.fish
    source ~/.config/fish/chromium.fish

    # pull in all shared `export …` aka `set -gx …`
    source ~/.exports

    if test -e "../private/extras.fish";
        source ../private/extras.fish
    end

    # for things not checked into git..
    if test -e "$HOME/.extra.fish";
        source ~/.extra.fish
    end
end


fish_add_path $HOME/.homebrew/bin; fish_add_path $HOME/homebrew/bin; # so i can use utils in startup

ssource;

# I don't need a prompt symbol for you-got-things-in-yr-stash
set --erase pure_symbol_git_stash

# Readline colors
set -g fish_color_autosuggestion 555 yellow
set -g fish_color_command 5f87d7
set -g fish_color_comment 808080
set -g fish_color_cwd 87af5f
set -g fish_color_cwd_root 5f0000
set -g fish_color_error 870000 --bold
set -g fish_color_escape af5f5f
set -g fish_color_history_current 87afd7
set -g fish_color_host 5f87af
set -g fish_color_match d7d7d7 --background=303030
set -g fish_color_normal normal
set -g fish_color_operator d7d7d7
set -g fish_color_param 5f87af
set -g fish_color_quote d7af5f
set -g fish_color_redirection normal
set -g fish_color_search_match --background=purple
set -g fish_color_status 5f0000
set -g fish_color_user 5f875f
set -g fish_color_valid_path --underline

set -g fish_color_dimmed 555
set -g fish_color_separator 999

# Git prompt status
set -g __fish_git_prompt_showdirtystate 'yes'
set -g __fish_git_prompt_showupstream auto
set -g pure_git_untracked_dirty false

# pure
set pure_threshold_command_duration 1
set pure_separate_prompt_on_error true
set pure_begin_prompt_with_current_directory false
set -U pure_color_success (set_color green)
set -U pure_color_git_dirty (set_color cyan)

set -U pure_color_git_unpushed_commits (set_color yellow)
set -U pure_color_git_unpulled_commits (set_color brgreen)

# prompt (lucid)

set -g lucid_prompt_symbol_error_color red

# Status Chars
#set __fish_git_prompt_char_dirtystate '*'
set __fish_git_prompt_char_upstream_equal ''
set __fish_git_prompt_char_upstream_ahead '↑'
set __fish_git_prompt_char_upstream_behind '↓'
set __fish_git_prompt_color_branch yellow
set __fish_git_prompt_color_dirtystate 'red'

set __fish_git_prompt_color_upstream_ahead ffb90f
set __fish_git_prompt_color_upstream_behind blue

# Local prompt customization
set -e fish_greeting


set -g fish_pager_color_completion normal
set -g fish_pager_color_description 555 yellow
set -g fish_pager_color_prefix cyan
set -g fish_pager_color_progress cyan


# ctrl-b invokes the fancy boi. but this doesnt really work right.
#bind \cb git-recent-with-fzf-and-diff
#if bind -M insert > /dev/null 2>&1
#    bind -M insert \cb git-recent-with-fzf-and-diff
#end

# Added by `rbenv init` on Mon Jan  6 13:43:48 JST 2025
status --is-interactive; and rbenv init - --no-rehash fish | source

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init2.fish 2>/dev/null || :
