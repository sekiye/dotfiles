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

### Artifactory（任意）

環境変数 `ARTIFACTORY_URL`（例: `artifactory.example.com`）/ `ARTIFACTORY_USER` /
`ARTIFACTORY_TOKEN`（Identity Token）があり、Artifactoryに接続できる場合だけ、
apt と Homebrew の取得先を Artifactory の remote repository に切り替えます。
どれかが無い、または接続できない場合は使いません。

環境変数が無い場合、`bootstrap.sh` は git から補います。

- `ARTIFACTORY_URL`: `git config artifactory.url`
- `ARTIFACTORY_USER` / `ARTIFACTORY_TOKEN`: git credential helper（`https://<host>`）

VS Code の Dev Containers は git credential をホストへ転送するので、認証情報は
`devcontainer.json` を変更せずに使えます。ここでのホストは Dev Containers が動く
マシンです（Remote-SSH 経由ならリモート側）。ただし `~/.gitconfig` は `user.*`
しかコピーされないため、Dev Container では `ARTIFACTORY_URL` を
[personal-bootstrap](https://github.com/sekiye/devcontainer-features) Feature の
`artifactoryUrl` オプション（VS Code のユーザー設定）で渡します。

ホストで一度だけ設定します（`artifactory.url` はホスト上での実行用）:

```bash
host=artifactory.example.com
git config --global artifactory.url "$host"
# Linux ホスト: Artifactory 専用のファイルに保存（macOS ならキーチェーンが使われるので不要）
git config --global "credential.https://$host.helper" \
  "store --file ~/.config/git/artifactory-credentials"
mkdir -p ~/.config/git
read -rp 'user: ' u; read -rsp 'token: ' t; echo
printf 'protocol=https\nhost=%s\nusername=%s\npassword=%s\n\n' "$host" "$u" "$t" \
  | git credential approve
```

確認（ホストとコンテナ内の両方で `username=` が出ればOK）:

```bash
printf 'protocol=https\nhost=%s\n\n' "$(git config --get artifactory.url)" \
  | git credential fill | grep -v password
```

`devcontainer.json` を変更できる場合は、環境変数で渡すこともできます:

```jsonc
"remoteEnv": {
  "ARTIFACTORY_URL": "${localEnv:ARTIFACTORY_URL}",
  "ARTIFACTORY_USER": "${localEnv:ARTIFACTORY_USER}",
  "ARTIFACTORY_TOKEN": "${localEnv:ARTIFACTORY_TOKEN}"
}
```

#### apt

base packagesが不足していてaptを実行する場合だけ、apt の取得先を切り替えます
（`--no-install-recommends` でインストール）。

- Artifactoryを使える場合: `debian-remote` / `debian-ubuntu-ports-remote`。
  認証情報は `/etc/apt/auth.conf.d/artifactory.conf`（root所有・権限600）に
  書き込まれます。既存の `/etc/apt/auth.conf{,.d/*}` に認証情報があれば
  `ARTIFACTORY_USER` / `ARTIFACTORY_TOKEN` は不要です。
- それ以外: amd64 では `jp.archive.ubuntu.com`。

Artifactoryに切り替えたコンテナは、その後のaptもArtifactoryへの接続が必要です。

```bash
APT_MIRROR=artifactory ./bootstrap.sh  # auto(default) / artifactory / jp / off
APT_FORCE_IPV4=1 ./bootstrap.sh        # IPv6経路が不安定な場合にaptをIPv4に固定
```

#### Homebrew bottles

`brew bundle install` は ghcr.io proxy（`docker-ghcr-remote`）から
bottleを取得します（Linux / macOS 共通、`BREW_ARTIFACTORY=off` で無効化）。

Artifactoryは「プラットフォーム別manifestを一度取得したbottle」しか返さないため、
使うbottleを事前にキャッシュへ載せておきます。新しいバージョンが出たら再実行します。

```bash
scripts/warm-artifactory-brew.sh          # Brewfile + 依存（Linux/macOS）
scripts/warm-artifactory-brew.sh tree jq  # 個別に指定
```

キャッシュに無いbottleがあると、Artifactory無しで ghcr.io から再実行します。
Homebrewは認証ヘッダーを全GitHub Packages URLに付けるため、トークンは
`brew bundle install` にだけ渡し、ghcr.io へのフォールバックと自動updateは無効にしています。

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
