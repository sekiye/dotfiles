# devcontainer-dotfiles-modern-v6

Ubuntu 24.04向けの個人dotfilesテンプレート。

## Stack

- fish
- Starship
- Fisher
- PatrickF1/fzf.fish
- wfxr/forgit
- zoxide
- fd / ripgrep / bat / eza / jq
- chezmoi

## First setup / upgrade

```bash
./bootstrap.sh
```

V6 is designed to be idempotent. Running `bootstrap.sh` again converges the
managed fish configuration/plugins to the current repo definition.

V6 keeps the existing Dev Container bootstrap fixes:

- installs `locales`, generates `en_US.UTF-8`, and sets it as the default locale
- temporarily uses `C.UTF-8` during bootstrap to avoid locale warnings before generation
- repairs ownership of only `~/.config`, `~/.config/chezmoi`, `~/.local`, and `~/.local/share` when needed
- deliberately does **not** recursively `chown` `$HOME`, so bind mounts such as `~/.claude` are left alone

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

## Upgrade safety

V6 keeps the previous migration behavior and removes legacy V1/V2 fish files only when their SHA-256 matches the exact
old template content. Modified files are retained. It also safely cleans the
support files that V3 could accidentally copy to `$HOME`, again only when the
contents exactly match V3.

Fisher's `fish_plugins` is declarative: `fisher update` installs missing
plugins and removes plugins no longer listed (for example the old Tide plugin).

Homebrew packages are additive on purpose: V6 ensures the Brewfile packages
exist but does not uninstall unrelated formulas from the shared Homebrew prefix.

## Dev Container fixes

If a Dev Container exports `LANG=en_US.UTF-8` without actually having that
locale generated, bootstrap now installs `locales`, generates `en_US.UTF-8`,
and runs `update-locale` automatically.

If the image leaves `~/.config` or `~/.local` non-writable, bootstrap repairs
only the directories that chezmoi needs. It intentionally avoids recursive
ownership changes across `$HOME`.
