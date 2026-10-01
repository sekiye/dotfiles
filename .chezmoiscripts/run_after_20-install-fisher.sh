#!/usr/bin/env bash
set -euo pipefail

FISH="/home/linuxbrew/.linuxbrew/bin/fish"
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
