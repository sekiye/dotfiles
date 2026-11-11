# Editor for git commit messages, crontab -e, etc. Exported outside the
# interactive block so tools launched from non-interactive fish see it too.
# Fall back to vi on minimal containers without vim.
if type -q vim
    set -gx EDITOR vim
else if type -q vi
    set -gx EDITOR vi
end

if set -q EDITOR
    set -gx VISUAL $EDITOR
end
