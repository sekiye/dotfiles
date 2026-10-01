# devcontainer-dotfiles-modern-v5

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

## First setup / upgrade from v1-v4

```bash
./bootstrap.sh
```

V5 is designed to be idempotent. Running `bootstrap.sh` again converges the
managed fish configuration/plugins to the current repo definition.

V5 also repairs common Dev Container bootstrap issues:

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

V5 keeps the V4 migration behavior and removes legacy V1/V2 fish files only when their SHA-256 matches the exact
old template content. Modified files are retained. It also safely cleans the
support files that V3 could accidentally copy to `$HOME`, again only when the
contents exactly match V3.

Fisher's `fish_plugins` is declarative: `fisher update` installs missing
plugins and removes plugins no longer listed (for example the old Tide plugin).

Homebrew packages are additive on purpose: V5 ensures the Brewfile packages
exist but does not uninstall unrelated formulas from the shared Homebrew prefix.

## V5 Dev Container fixes

If a Dev Container exports `LANG=en_US.UTF-8` without actually having that
locale generated, bootstrap now installs `locales`, generates `en_US.UTF-8`,
and runs `update-locale` automatically.

If the image leaves `~/.config` or `~/.local` non-writable, bootstrap repairs
only the directories that chezmoi needs. It intentionally avoids recursive
ownership changes across `$HOME`.
