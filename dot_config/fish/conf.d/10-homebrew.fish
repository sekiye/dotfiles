# Locate Homebrew without assuming Linux, Apple Silicon macOS, or Intel macOS.
set -l brew_path

if type -q brew
    set brew_path (command -v brew)
else
    for candidate in \
        /opt/homebrew/bin/brew \
        /usr/local/bin/brew \
        /home/linuxbrew/.linuxbrew/bin/brew
        if test -x $candidate
            set brew_path $candidate
            break
        end
    end
end

if test -n "$brew_path"
    eval ($brew_path shellenv fish)
end
