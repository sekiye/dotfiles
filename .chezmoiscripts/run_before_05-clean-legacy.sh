#!/usr/bin/env bash
set -euo pipefail

# V1/V2 files whose names changed in V3+. Remove only when they still match the
# exact template content we previously shipped; user-modified files are kept.
safe_remove_sha256() {
  local path="$1"
  shift
  [[ -f "$path" ]] || return 0
  local actual
  actual="$(sha256sum "$path" | awk '{print $1}')"
  local expected
  for expected in "$@"; do
    if [[ "$actual" == "$expected" ]]; then
      echo "==> Removing legacy managed file: $path"
      rm -f -- "$path"
      return 0
    fi
  done
  echo "==> Keeping modified legacy file: $path"
}

safe_remove_sha256 "$HOME/.config/fish/conf.d/20-path.fish" \
  6b3aa90a0d2e3f5b580c57bff56a6969647bde26353cf71884c882cb9e806834
safe_remove_sha256 "$HOME/.config/fish/conf.d/30-starship.fish" \
  29bcde84852565f19d834bc29befe0ebcce45a02af8cff2db9e200cccc1093cc
safe_remove_sha256 "$HOME/.config/fish/conf.d/40-zoxide.fish" \
  a3576f0ec06eae0b3b2bb4bfe632a39783a9bd0addabc764b065869e192db616
safe_remove_sha256 "$HOME/.config/fish/conf.d/50-fzf.fish" \
  7671f4a7ced7f1c00c73e937e1550d4535690b2f691f4c676e9c4b40badb25cc
safe_remove_sha256 "$HOME/.config/fish/conf.d/40-aliases.fish" \
  7d4e0e4427f68e76da2ef70704201c62b47cc7f13631f30d85873378309cc754

# V3 accidentally treated repository support files as HOME targets because the
# repo lacked .chezmoiignore. Remove them only if they are byte-for-byte the V3
# templates, so unrelated ~/README.md etc. are never deleted.
safe_remove_sha256 "$HOME/README.md" \
  7cf2b2dbb87326032b85b72b9ce06ffd99b3211b5ac9a41fe63ec4332632d6f5
safe_remove_sha256 "$HOME/bootstrap.sh" \
  17623835df3d167b079708368cc8c59c062955ae2ce83f0019616da1913e9489
safe_remove_sha256 "$HOME/install.sh" \
  cd4cad5fe21a917810558aead8b564e316721cd34b43de4538b6c0a4c3e6673c
safe_remove_sha256 "$HOME/packages/Brewfile" \
  3064d885e680a50383c888de67d32c45980768c62df6dd1837a73278a9ea4004
rmdir "$HOME/packages" 2>/dev/null || true
