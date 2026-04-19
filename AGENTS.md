# AGENTS.md

## Overview

[picoclaw](https://github.com/sipeed/picoclaw) (Go製 Discord bot) のソフトフォーク。直接のGoソースは持たず、**パッチファイルだけで変更を管理**する。Nix flake でビルドし、GitHub Actions で GHCR に Docker イメージを公開する。

## Architecture

- `patches/` — 番号付き `.patch` ファイル（lexicographic order で適用。`0001-` のようなゼロ埋め命名を維持すること）。**これが実質的なソースコード**
- `flake.nix` — ビルド定義。`buildGoModule` で upstream を fetch → パッチ適用 → ビルド。Docker イメージも定義
- `.upstream-version` — 追跡中の upstream バージョン（`flake.nix` 内の `version` と同期）
- `.upstream/` — ローカル開発用の作業ディレクトリ（gitignore 済、ビルドには使われない）
- `scripts/` — パッチ開発用ヘルパー
- `flake.lock` — Nix 依存のロックファイル（`nixpkgs` + `numtide/llm-agents.nix`）

## Build Details

`flake.nix` の `buildGoModule` で以下の前提がある。変更時は注意:

- `env.CGO_ENABLED = "0"` — pure Go ビルド
- build tags: `goolm`, `stdjson`
- `subPackages = [ "cmd/picoclaw" ]` — ビルド対象
- `preBuild` で `go generate ./cmd/picoclaw/...` を実行
- `ldflags` で strip (`-s -w`) + `pkg/config.Version` に version を埋め込み
- `proxyVendor = true`
- `.#picoclaw` は Linux/Darwin 両方で利用可能。`.#docker` は **Linux のときだけ定義**される

## Commands

```bash
# ビルド（Nix 必須）
nix build .#picoclaw        # バイナリのみ（Linux/Darwin）
nix build .#docker           # Docker イメージ（Linux のみ）
docker load < result         # イメージをロード

# パッチ開発
./scripts/fetch-upstream.sh [version]  # .upstream/ に clean upstream を取得（省略時は .upstream-version を使用）
./scripts/apply-patches.sh             # .upstream/ に既存パッチを適用
./scripts/create-patch.sh <name>       # .upstream/ と clean upstream の差分からパッチ生成（同名パッチは上書き）
```

## Patch Development Gotchas

- `create-patch.sh` は `.upstream/` の内容を clean upstream に上書きコピーして差分を取る。**ファイルの追加・変更は検出されるが、削除は検出されない**（clean upstream 側のファイルが残るため）。削除を含むパッチは手動で編集する必要がある
- `create-patch.sh` は累積 diff を生成する。個別パッチを作る場合は、`.upstream/` に**そのパッチの変更だけ**が含まれる状態で実行すること
- `create-patch.sh` は常に **`.upstream-version` のバージョン**を基準に clean upstream を取得する。`fetch-upstream.sh <version>` で別バージョンの upstream を取得した場合、`.upstream-version` も更新しないと**誤ったベースとの差分**で壊れたパッチが生成される
- `fetch-upstream.sh` は `.upstream/` を **rm -rf してから取り直す**。未保存の作業内容は消える
- `apply-patches.sh` は **idempotent ではない**。すでにパッチ適用済み・部分適用・手編集済みの `.upstream/` に再実行すると壊れる。再適用時は `fetch-upstream.sh` で取り直してから実行すること
- **パッチを追加・削除したら `flake.nix` の `patches` リストも必ず更新すること**。ここを忘れるとビルドに反映されない
- パッチの適用順: `apply-patches.sh` は `patches/*.patch` の **lexicographic order**、Nix build は `flake.nix` の **`patches` 配列の列挙順**で適用する。両者を一致させること（`0001-`, `0002-`, ... のゼロ埋め命名を維持）
- upstream バージョンが上がるとパッチが適用できなくなる可能性がある。CI (`update.yml`) がこの失敗を検知する

### 新しいパッチを追加する最小手順

```bash
./scripts/fetch-upstream.sh           # clean upstream を取得（.upstream/ はリセットされる）
./scripts/apply-patches.sh            # 既存パッチを適用
# .upstream/ 内でファイルを編集
./scripts/create-patch.sh 000N-name   # パッチ生成
# flake.nix の patches リストに追加
nix build .#picoclaw                  # ビルド検証
```

## CI/CD

- `build.yml` — push（main）、PR、`workflow_dispatch` で `nix build .#docker` を実行。**GHCR push と git tag 作成は `main` への push 時のみ**。バージョンタグは `{upstream_version}-{copilot_rev}`（例: `0.2.6-1`）
- `update.yml` — 毎日 cron で `sipeed/picoclaw` の新リリースをチェック → `flake.nix` のバージョンとハッシュを自動更新 → コミット & push。`vendorHash` はダミーハッシュでビルドを走らせて正しい値を取得する手法

## Version Management

upstream バージョンは2箇所で管理:
1. `flake.nix` 内の `version = "X.Y.Z"`
2. `.upstream-version` ファイル

両方を同期すること。CI の `update.yml` は両方を更新する。

手動で upstream バージョンを上げる場合は、`version` と `.upstream-version` に加えて `flake.nix` 内の `src.hash` と `vendorHash` も更新が必要（CI は dummy hash trick で自動取得する）。最後に `nix build .#picoclaw` で検証すること。

## Flake Inputs

- `nixpkgs` — `nixos-unstable`
- `llm-agents` — `numtide/llm-agents.nix`（`copilot-cli` パッケージを提供）

## Docker Image Contents

主要ツール: picoclaw, git, openssh, gh, copilot-cli, bash, coreutils, cacert, tzdata。ENTRYPOINT は `picoclaw`。
