#!/usr/bin/env bash
set -euo pipefail

find_brew() {
  if command -v brew >/dev/null 2>&1; then
    command -v brew
    return 0
  fi

  local candidate
  for candidate in \
    /opt/homebrew/bin/brew \
    /usr/local/bin/brew \
    /home/linuxbrew/.linuxbrew/bin/brew; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

if ! BREW="$(find_brew)"; then
  echo "Homebrew not found." >&2
  exit 1
fi

eval "$("$BREW" shellenv bash)"
FISH="$(brew --prefix)/bin/fish"
if [[ ! -x "$FISH" ]]; then
  echo "fish not found: $FISH" >&2
  exit 1
fi

"$FISH" <<'FISH_EOF'
if not type -q fisher
    echo "==> Bootstrapping Fisher"
    curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
end

# fish_plugins is managed by chezmoi. `fisher update` installs missing plugins,
# updates existing ones, and removes plugins deleted from fish_plugins.
echo "==> Converging Fisher plugins"
fisher update
FISH_EOF
