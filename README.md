# devcontainer-dotfiles-modern-v7

Ubuntu / Dev Container / macOS で共通利用する個人 dotfiles。

## Stack

- fish
- Starship
- Fisher
- PatrickF1/fzf.fish
- wfxr/forgit
- zoxide
- fd / ripgrep / bat / eza / jq
- chezmoi

## Supported environments

- Ubuntu / Ubuntu-based Dev Containers
- macOS Apple Silicon (`/opt/homebrew`)
- macOS Intel (`/usr/local`)

Homebrew の場所は固定せず、検出後に `brew shellenv` を使います。

## First setup / upgrade

```bash
./bootstrap.sh
```

V7 is idempotent. Re-running `bootstrap.sh` converges the Homebrew packages,
chezmoi-managed files, and Fisher plugins to the repository definition.

### Linux / Dev Container

Linuxでは必要なbase packagesと `en_US.UTF-8` localeもbootstrapが準備します。
Dev Container向けのownership修復は `~/.config` / `~/.local` など管理対象だけに限定し、
`$HOME` 全体には再帰的 `chown` を行いません。

### macOS

Apple Silicon / Intel の両方をサポートします。既存Homebrewがあれば再利用し、
無ければ公式install scriptで導入します。

bootstrap後、fishをすぐ使う場合:

```bash
exec "$(brew --prefix)/bin/fish"
```

macOSのログインシェル自体をfishに変更したい場合だけ、任意で次を実行します。
Dev Containerではこの変更は不要です。

```bash
FISH="$(brew --prefix)/bin/fish"
grep -qxF "$FISH" /etc/shells || echo "$FISH" | sudo tee -a /etc/shells
chsh -s "$FISH"
```

## Updates after the repo has a Git remote

```bash
chezmoi update
```

## fzf.fish

`PatrickF1/fzf.fish` provides Fish-native fuzzy pickers for history, files,
directories, Git status/log, variables, etc.

```fish
fzf_configure_bindings --help
```

## forgit

`wfxr/forgit` provides short interactive Git commands powered by fzf.
It is managed by Fisher together with `fzf.fish`.

Useful commands:

```text
gsw     branch -> git switch
ga      interactive git add
gd      interactive git diff
glo     interactive git log
gss     stash viewer
gcp     cherry-pick
grb     interactive rebase
gwt     worktree selector
```

For branch switching, use `gsw`, choose the branch, and press Enter.

## Aliases

```text
ls   -> eza
ll   -> eza -lah --git
lt   -> eza --tree --level=2
b    -> bat

gs   -> git status
gl   -> compact graph log
```

`cat` is intentionally not replaced by `bat`.

## Cross-platform details

- Homebrew detection: Linuxbrew / Apple Silicon macOS / Intel macOS
- shell initialization: Bash/Profile on Linux, Zsh on macOS, Fish on both
- SHA-256 migration checks: `sha256sum` on Linux, `shasum -a 256` fallback on macOS
- Homebrew packages are additive; unrelated formulas are not removed
- Fisher `fish_plugins` is declarative, so removed plugins are cleaned up by `fisher update`
