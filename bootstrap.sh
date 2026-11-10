#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"

log() { printf '\n==> %s\n' "$*"; }

# Normalize ARTIFACTORY_URL ("host", "https://host" or "https://host/artifactory")
# to the Artifactory base URL.
artifactory_base_url() {
  local url="${1%/}"
  [[ "$url" == *://* ]] || url="https://$url"
  [[ "$url" == */artifactory ]] || url="$url/artifactory"
  printf '%s\n' "$url"
}

# Fill unset ARTIFACTORY_URL / ARTIFACTORY_USER / ARTIFACTORY_TOKEN from git:
# the URL from `git config artifactory.url`, the credentials from the git
# credential helper. Dev Containers copies the host ~/.gitconfig and forwards
# git credentials to the host, so this needs no devcontainer.json change.
load_artifactory_config() {
  command -v git >/dev/null 2>&1 || return 0
  if [[ -z "${ARTIFACTORY_URL:-}" ]]; then
    ARTIFACTORY_URL="$(git config --get artifactory.url 2>/dev/null || true)"
  fi
  [[ -n "$ARTIFACTORY_URL" ]] || return 0

  if [[ -z "${ARTIFACTORY_USER:-}" || -z "${ARTIFACTORY_TOKEN:-}" ]]; then
    local host cred timeout_cmd=()
    host="$(artifactory_base_url "$ARTIFACTORY_URL")"
    host="${host#*://}"
    host="${host%%/*}"
    command -v timeout >/dev/null 2>&1 && timeout_cmd=(timeout 15)
    # Never prompt: without a stored credential, just skip Artifactory.
    cred="$(printf 'protocol=https\nhost=%s\n\n' "$host" \
      | GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=true SSH_ASKPASS=true \
        ${timeout_cmd[@]+"${timeout_cmd[@]}"} git credential fill 2>/dev/null || true)"
    ARTIFACTORY_USER="$(sed -n 's/^username=//p' <<<"$cred")"
    ARTIFACTORY_TOKEN="$(sed -n 's/^password=//p' <<<"$cred")"
  fi
  export ARTIFACTORY_URL ARTIFACTORY_USER ARTIFACTORY_TOKEN
}
load_artifactory_config

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
      # archive.ubuntu.com can be very slow from Japan. APT_MIRROR selects:
      #   auto (default): Artifactory (ARTIFACTORY_URL) when it is reachable and
      #                   credentials are given by ARTIFACTORY_USER /
      #                   ARTIFACTORY_TOKEN (or already exist in
      #                   /etc/apt/auth.conf{,.d/*}); otherwise the JP mirror
      #                   (amd64 only; ports.ubuntu.com has none)
      #   artifactory | jp | off
      # The rewrite is persistent: a container switched to Artifactory needs it
      # to be reachable for later apt runs.
      apt_mirror="${APT_MIRROR:-auto}"
      artifactory_url=""
      artifactory_host=""
      if [[ -n "${ARTIFACTORY_URL:-}" ]]; then
        artifactory_url="$(artifactory_base_url "$ARTIFACTORY_URL")"
        artifactory_host="${artifactory_url#*://}"
        artifactory_host="${artifactory_host%%/*}"
      fi
      if [[ "$apt_mirror" == "auto" ]]; then
        skip_reason=""
        if [[ -z "$artifactory_url" ]]; then
          skip_reason="ARTIFACTORY_URL is not set"
        elif [[ ! -r /etc/ssl/certs/ca-certificates.crt ]] || ! command -v curl >/dev/null 2>&1; then
          skip_reason="curl or ca-certificates is not installed"
        elif ! curl -fsS -o /dev/null --max-time 3 "$artifactory_url/api/system/ping" 2>/dev/null; then
          skip_reason="$artifactory_url is not reachable"
        elif ! [[ -n "${ARTIFACTORY_USER:-}" && -n "${ARTIFACTORY_TOKEN:-}" ]] \
          && ! sudo grep -qsF "$artifactory_host" /etc/apt/auth.conf /etc/apt/auth.conf.d/*; then
          skip_reason="no credentials (ARTIFACTORY_USER / ARTIFACTORY_TOKEN or git credential)"
        fi

        if [[ -z "$skip_reason" ]]; then
          apt_mirror=artifactory
        else
          log "Artifactory skipped for apt: $skip_reason"
          if [[ "$(dpkg --print-architecture)" == "amd64" ]]; then
            apt_mirror=jp
          else
            apt_mirror=off
          fi
        fi
      fi

      case "$apt_mirror" in
        artifactory)
          if [[ -z "$artifactory_url" ]]; then
            echo "APT_MIRROR=artifactory requires ARTIFACTORY_URL." >&2
            exit 1
          fi
          mirror_sed="s#https\?://\(jp\.\)\?\(archive\|security\)\.ubuntu\.com/ubuntu/\?#$artifactory_url/debian-remote/#g"
          mirror_sed+="; s#https\?://ports\.ubuntu\.com/ubuntu-ports/\?#$artifactory_url/debian-ubuntu-ports-remote/#g"
          ;;
        jp)
          mirror_sed='s#http://archive\.ubuntu\.com/ubuntu#http://jp.archive.ubuntu.com/ubuntu#g'
          ;;
        off)
          mirror_sed=''
          ;;
        *)
          echo "Unknown APT_MIRROR: $apt_mirror (expected auto, artifactory, jp, or off)" >&2
          exit 1
          ;;
      esac
      if [[ "$apt_mirror" == "artifactory" && -n "${ARTIFACTORY_USER:-}" && -n "${ARTIFACTORY_TOKEN:-}" ]]; then
        log "Writing apt credentials for Artifactory"
        # printf is a builtin, so the token never appears in a process argv.
        printf 'machine %s\nlogin %s\npassword %s\n' \
          "$artifactory_host" "$ARTIFACTORY_USER" "$ARTIFACTORY_TOKEN" \
          | sudo sh -c 'install -d -m 0755 /etc/apt/auth.conf.d && umask 077 && cat > /etc/apt/auth.conf.d/artifactory.conf'
      fi
      if [[ -n "$mirror_sed" ]]; then
        log "Using apt mirror: $apt_mirror"
        for src in /etc/apt/sources.list.d/ubuntu.sources /etc/apt/sources.list; do
          if [[ -f "$src" ]]; then
            sudo sed -i "$mirror_sed" "$src"
          fi
        done
      fi

      # Opt-in workaround for unstable IPv6 routes.
      if [[ "${APT_FORCE_IPV4:-0}" == "1" ]]; then
        echo 'Acquire::ForceIPv4 "true";' | sudo tee /etc/apt/apt.conf.d/99force-ipv4 >/dev/null
      fi

      sudo apt-get update
      sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${missing[@]}"
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
chezmoi init --source="$SCRIPT_DIR"
chezmoi apply --force

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
