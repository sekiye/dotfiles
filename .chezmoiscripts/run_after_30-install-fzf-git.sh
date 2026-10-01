#!/usr/bin/env bash
set -euo pipefail

DEST="$HOME/.local/share/fzf-git.sh"
REPO="https://github.com/junegunn/fzf-git.sh.git"
mkdir -p "$HOME/.local/share"

if [[ -d "$DEST/.git" ]]; then
  echo "==> Updating fzf-git.sh"
  git -C "$DEST" fetch --prune origin
  git -C "$DEST" reset --hard origin/main
  git -C "$DEST" clean -fd
else
  echo "==> Installing fzf-git.sh"
  rm -rf "$DEST"
  git clone --depth=1 "$REPO" "$DEST"
fi
