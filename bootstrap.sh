#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BREW_BIN="/home/linuxbrew/.linuxbrew/bin/brew"

log() { printf '\n==> %s\n' "$*"; }

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "This bootstrap currently supports Linux only." >&2
  exit 1
fi

if [[ -r /etc/os-release ]]; then
  . /etc/os-release
  if [[ "${ID:-}" != "ubuntu" || "${VERSION_ID:-}" != "24.04" ]]; then
    echo "Warning: this template is tested for Ubuntu 24.04; detected ${PRETTY_NAME:-unknown}." >&2
  fi
fi

log "Installing base packages"
missing=()
for pkg in build-essential procps curl file git ca-certificates; do
  if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q 'ok installed'; then
    missing+=("$pkg")
  fi
done
if ((${#missing[@]})); then
  sudo apt-get update
  sudo apt-get install -y "${missing[@]}"
fi

if ! command -v brew >/dev/null 2>&1; then
  if [[ -x "$BREW_BIN" ]]; then
    eval "$("$BREW_BIN" shellenv)"
  else
    log "Installing Homebrew"
    NONINTERACTIVE=1 /bin/bash -c \
      "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$("$BREW_BIN" shellenv)"
  fi
fi

BREW_PREFIX="$(brew --prefix)"
if [[ ! -w "$BREW_PREFIX" ]]; then
  cat >&2 <<MSG
Homebrew exists but is not writable by user: $(id -un)
Prefix: $BREW_PREFIX

If this user should own this Homebrew installation, fix ownership explicitly, e.g.:
  sudo chown -R $(id -un):$(id -gn) $BREW_PREFIX

Then re-run ./bootstrap.sh.
MSG
  exit 1
fi

# Keep Homebrew visible from Bash/login shells. Replace our own block on every
# run, so upgrades converge to the latest bootstrap definition.
upsert_brew_init() {
  local rc="$1"
  local tmp
  touch "$rc"
  tmp="$(mktemp)"
  sed '/# >>> devcontainer-dotfiles homebrew >>>/,/# <<< devcontainer-dotfiles homebrew <<</d' "$rc" > "$tmp"
  cat >> "$tmp" <<'RC'

# >>> devcontainer-dotfiles homebrew >>>
if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi
# <<< devcontainer-dotfiles homebrew <<<
RC
  mv "$tmp" "$rc"
}

upsert_brew_init "$HOME/.bashrc"
upsert_brew_init "$HOME/.profile"

log "Installing chezmoi"
if ! command -v chezmoi >/dev/null 2>&1; then
  brew install chezmoi
fi

log "Applying chezmoi source: $SCRIPT_DIR"
chezmoi init --source="$SCRIPT_DIR" --apply

FISH_BIN="$(brew --prefix)/bin/fish"
log "Bootstrap complete"
printf '\nManaged tools:\n'
printf '  Homebrew: %s\n' "$(brew --version | head -1)"
printf '  chezmoi:  %s\n' "$(chezmoi --version)"
if [[ -x "$FISH_BIN" ]]; then
  printf '  fish:     %s\n' "$("$FISH_BIN" --version)"
fi
printf '\nStart fish now with:\n  exec %s\n' "$FISH_BIN"
printf '\nFuture Bash sessions will load Homebrew automatically.\n'
