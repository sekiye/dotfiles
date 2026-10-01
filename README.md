# devcontainer-dotfiles-modern-v4

Ubuntu 24.04向けの個人dotfilesテンプレート。

## Stack

- fish
- Starship
- Fisher
- PatrickF1/fzf.fish
- junegunn/fzf-git.sh
- zoxide
- fd / ripgrep / bat / eza / jq
- chezmoi

## First setup / upgrade from v1-v3

```bash
./bootstrap.sh
```

V4 is designed to be idempotent. Running `bootstrap.sh` again converges the
managed fish configuration/plugins to the current repo definition.

After bootstrap, start fish with:

```bash
exec /home/linuxbrew/.linuxbrew/bin/fish
```

## Updates after the repo has a Git remote

```bash
chezmoi update
```

## fzf.fish

`PatrickF1/fzf.fish` provides Fish-native fuzzy pickers (history, files,
directories, Git status/log, variables, etc.). Use:

```fish
fzf_configure_bindings --help
```

to inspect/customize bindings.

## fzf-git.sh

Git objects can be inserted interactively using the `Ctrl-G` key sequences.
For example, type:

```fish
git switch 
```

then press `Ctrl-G Ctrl-B` to choose a branch.

Other selectors include commits, tags, stashes and worktrees.

## Aliases

```text
ls   -> eza
ll   -> eza -lah --git
lt   -> eza --tree --level=2
b    -> bat

gs   -> git status
gd   -> git diff
gl   -> compact graph log
```

`cat` is intentionally not replaced by `bat`.

## Upgrade safety

V4 removes legacy V1/V2 fish files only when their SHA-256 matches the exact
old template content. Modified files are retained. It also safely cleans the
support files that V3 could accidentally copy to `$HOME`, again only when the
contents exactly match V3.

Fisher's `fish_plugins` is declarative: `fisher update` installs missing
plugins and removes plugins no longer listed (for example the old Tide plugin).

Homebrew packages are additive on purpose: V4 ensures the Brewfile packages
exist but does not uninstall unrelated formulas from the shared Homebrew prefix.
