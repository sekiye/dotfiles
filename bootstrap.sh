#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"

log() { printf '\n==> %s\n' "$*"; }

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

case "$OS" in
  Linux)
    if [[ -r /etc/os-release ]]; then
      . /etc/os-release
      if [[ "${ID:-}" != "ubuntu" || "${VERSION_ID:-}" != "24.04" ]]; then
        echo "Warning: Linux bootstrap is tested primarily on Ubuntu 24.04; detected ${PRETTY_NAME:-unknown}." >&2
      fi
    fi

    # A Dev Container may export en_US.UTF-8 before the locale has actually been
    # generated. Use C.UTF-8 while bootstrapping, then generate en_US.UTF-8.
    if locale -a 2>/dev/null | grep -qi '^C\.utf8$'; then
      export LANG=C.UTF-8
      export LC_ALL=C.UTF-8
    fi

    log "Installing base packages"
    missing=()
    for pkg in build-essential procps curl file git ca-certificates locales; do
      if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q 'ok installed'; then
        missing+=("$pkg")
      fi
    done
    if ((${#missing[@]})); then
      sudo apt-get update
      sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "${missing[@]}"
    fi

    log "Ensuring en_US.UTF-8 locale"
    if ! locale -a 2>/dev/null | grep -qi '^en_US\.utf8$'; then
      sudo locale-gen en_US.UTF-8
    fi
    if ! grep -Eq '^LANG=en_US\.UTF-8$' /etc/default/locale 2>/dev/null; then
      sudo update-locale LANG=en_US.UTF-8
    fi
    unset LC_ALL
    export LANG=en_US.UTF-8
    ;;

  Darwin)
    log "Detected macOS"
    ;;

  *)
    echo "Unsupported OS: $OS" >&2
    exit 1
    ;;
esac

# Some Dev Container images can leave user configuration directories owned by
# root. Fix only paths managed by this dotfiles setup; never chown all of HOME.
ensure_user_dir() {
  local dir="$1"
  if ! mkdir -p "$dir" 2>/dev/null; then
    sudo install -d -o "$(id -u)" -g "$(id -g)" -m 0755 "$dir"
  fi
  if [[ ! -w "$dir" ]]; then
    log "Fixing ownership: $dir"
    sudo chown "$(id -u):$(id -g)" "$dir"
  fi
}

ensure_user_dir "$HOME/.config"
ensure_user_dir "$HOME/.config/chezmoi"
ensure_user_dir "$HOME/.local"
ensure_user_dir "$HOME/.local/share"

if BREW_BIN="$(find_brew)"; then
  eval "$("$BREW_BIN" shellenv bash)"
else
  log "Installing Homebrew"
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if ! BREW_BIN="$(find_brew)"; then
    echo "Homebrew installation finished but brew could not be located." >&2
    exit 1
  fi
  eval "$("$BREW_BIN" shellenv bash)"
fi

BREW_BIN="$(command -v brew)"
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

# Keep Homebrew visible from the platform's normal bootstrap/login shells.
# The absolute brew path is generated from the active installation, so the same
# repo supports Linuxbrew, Apple Silicon macOS, and Intel macOS.
upsert_brew_init() {
  local rc="$1"
  local shell_name="$2"
  local tmp
  touch "$rc"
  tmp="$(mktemp)"
  sed '/# >>> devcontainer-dotfiles homebrew >>>/,/# <<< devcontainer-dotfiles homebrew <<</d' "$rc" > "$tmp"
  cat >> "$tmp" <<RC

# >>> devcontainer-dotfiles homebrew >>>
if [ -x "$BREW_BIN" ]; then
  eval "\$(\"$BREW_BIN\" shellenv $shell_name)"
fi
# <<< devcontainer-dotfiles homebrew <<<
RC
  mv "$tmp" "$rc"
}

if [[ "$OS" == "Darwin" ]]; then
  upsert_brew_init "$HOME/.zprofile" zsh
  upsert_brew_init "$HOME/.zshrc" zsh
else
  upsert_brew_init "$HOME/.bashrc" bash
  upsert_brew_init "$HOME/.profile" sh
fi

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
if [[ "$OS" == "Linux" ]]; then
  printf '  locale:   %s\n' "${LANG:-unset}"
fi
printf '\nStart fish now with:\n  exec %s\n' "$FISH_BIN"
printf '\nFuture login shells will load Homebrew automatically.\n'
