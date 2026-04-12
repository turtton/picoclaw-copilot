# picoclaw-copilot

[picoclaw](https://github.com/sipeed/picoclaw) の soft-fork ディストリビューション。パッチベースでカスタマイズを行い、Nix flake でビルドし、GitHub Actions で GHCR に自動公開します。

## カスタマイズ内容

- 全ビルトインコマンド（start, help, show, list, use, switch, check, clear, subagents, reload）を Discord スラッシュコマンドとして登録（テキストコマンドも引き続き動作）
- `allow_from` で Discord ロール ID をサポート（ユーザー ID と併用可能）
  - ロール ID によるアクセス制御はギルド（サーバー）内のメッセージ・スラッシュコマンドでのみ有効です。DM ではロール情報を取得できないため、DM でも利用させたい場合はユーザー ID も併記してください。

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
nix build .#picoclaw
nix build .#docker
docker load < result
```

## パッチ開発

```bash
./scripts/fetch-upstream.sh
./scripts/apply-patches.sh

# .upstream/ 内で変更を加えた後:
./scripts/create-patch.sh 0002-my-change
```

## CI/CD

- **Build and Push** (`build.yml`): `main` への push 時に Docker イメージをビルドし GHCR に公開
- **Update** (`update.yml`): 毎日 upstream の新バージョンをチェックし、自動で `flake.nix` と `.upstream-version` を更新・コミット。パッチが新バージョンに適用できない場合はビルドが失敗します
