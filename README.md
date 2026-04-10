# picoclaw-copilot

[picoclaw](https://github.com/sipeed/picoclaw) のカスタム Docker イメージ。Nix flake でビルドし、GitHub Actions で GHCR に自動公開します。

## 含まれるパッケージ

| パッケージ | 用途 |
|---|---|
| picoclaw | 本体 |
| git | リポジトリ操作 |
| openssh | SSH 接続 |
| gh (GitHub CLI) | GitHub API 操作 |
| bash | シェル |
| coreutils | 基本コマンド |
| cacert | TLS 証明書 |
| tzdata | タイムゾーン |

## 使い方

```bash
docker pull ghcr.io/turtton/picoclaw-copilot:latest
docker run --rm ghcr.io/turtton/picoclaw-copilot version
```

`ENTRYPOINT` が `picoclaw` に設定されているため、引数はそのまま picoclaw のサブコマンド/フラグとして渡されます。

## ローカルビルド

[Nix](https://nixos.org/) が必要です。

```bash
# picoclaw バイナリのみ
nix build .#picoclaw

# Docker イメージ (Linux のみ)
nix build .#docker
docker load < result
```

## CI/CD

- **Build and Push** (`build.yml`): `main` への push 時に Docker イメージをビルドし GHCR に公開
- **Update** (`update.yml`): 毎日 upstream の新バージョンをチェックし、自動で `flake.nix` を更新・コミット
