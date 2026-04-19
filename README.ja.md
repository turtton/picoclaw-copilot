[English](README.md)

# picoclaw-copilot

[picoclaw](https://github.com/sipeed/picoclaw) のソフトフォーク版。パッチベースでカスタマイズを行い、Nix flake でビルドし、GitHub Actions で GHCR に自動公開します。

## カスタマイズ内容

- 全ビルトインコマンド（start, help, show, list, use, switch, check, clear, subagents, reload）を Discord スラッシュコマンドとして登録（テキストコマンドも引き続き動作）
- `allow_from` で Discord ロール ID をサポート（ユーザー ID と併用可能）
  - ロール ID によるアクセス制御はギルド（サーバー）内のメッセージ・スラッシュコマンドでのみ有効です。DM ではロール情報を取得できないため、DM でも利用させたい場合はユーザー ID も併記してください。
- `opencode_task` ツール: [opencode](https://opencode.ai/) エージェントに REST API 経由でコーディングタスクを委譲。非同期実行、SSE イベント監視（`question.asked` イベントの Discord 転送 + 自動 reject）、HTTP Basic 認証に対応。
  - **別途 opencode サーバーの起動が必要です。** このツールは `SERVER_URL` で指定されたサーバーに接続します。opencode 本体はこのイメージに含まれていません。
  - **注意**: このツールはセルフホスト版 opencode サーバーの内部 API を対象としています。SSE イベント形式や question/control エンドポイントは公開 opencode SDK と異なる場合があります。サーバーバージョンが想定する API 仕様と一致することを確認してください。
- Web UI でのマルチチャンネルセッション履歴: セッション API を pico 専用からチャンネル非依存に一般化し、Discord などのチャンネルのセッションも Web UI のセッション履歴に表示されるようにしました。フロントエンドにはチャンネル種別アイコンを表示します。
- サブエージェントの Discord スレッド可視化: エージェントがサブターンを生成するたびに Discord スレッドを開き、サブエージェントの動作をリアルタイムで追えるようにします。スレッド作成ができない場合（DM 等）は安全にフォールバックします。
- GitHub Copilot プロバイダのセッション自動復旧: Copilot CLI はアイドル時間が続くとセッションを破棄するため、以前は `Session not found` エラーで pod を再起動するまで回復できませんでした。このエラーを検知して同じ model/permission/hook 設定で透過的にセッションを再作成し、1 回だけリトライします。

## パッチ一覧

| ファイル名 | 概要 | 追加機能 |
|---|---|---|
| `0001-add-slash-commands.patch` | `pkg/bus/types.go`, `pkg/channels/base.go`, `pkg/channels/discord/discord.go` を修正 | 全10種のビルトインコマンドを Discord スラッシュコマンドとして登録。スラッシュコマンドをテキスト形式に変換して処理する `handleInteraction`、ロールベースの `allow_from` 対応、および許可チェックの重複をスキップする `PreAuthorized` フラグを追加。 |
| `0002-add-opencode-tool.patch` | `pkg/tools/opencode_task.go` を新規追加、`pkg/config/config.go` と `pkg/agent/loop.go` を修正 | opencode エージェントに REST API 経由でタスクを委譲する `opencode_task` ツールを追加（POST /session → GET /event SSE → POST /session/:id/message）。`AsyncExecutor` による非同期実行、`question.asked` イベントの Discord 転送・自動 reject を実装。`PICOCLAW_TOOLS_OPENCODE_TASK_*` 環境変数（ENABLED, SERVER_URL, USERNAME, PASSWORD）で設定。 |
| `0003-add-multi-channel-session-history.patch` | `web/backend/api/session.go`, `web/frontend/src/api/sessions.ts`, `web/frontend/src/hooks/use-sidebar-channels.ts` を修正、`web/frontend/src/components/chat/session-history-menu.tsx` を新規追加 | セッション履歴 API を pico 専用からチャンネル非依存に一般化し、Discord 等のチャンネルでも Web UI のセッション履歴に表示されるようにする。バックエンドで入力バリデーションとパストラバーサル対策を実施、フロントエンドにチャンネル種別アイコンを追加。 |
| `0004-add-subagent-discord-visibility.patch` | `pkg/channels/discord/discord.go`, `pkg/channels/interfaces.go`, `pkg/gateway/gateway.go` を修正、`pkg/gateway/subturn_notifier.go` を新規追加 | サブターンイベントごとに Discord スレッドを開き、サブエージェントの動作をリアルタイムで可視化する。2 ゴルーチン構成（EventBus 購読の `eventLoop` と Discord I/O 用 `workerLoop`）で gateway をブロックしない。`ThreadCapable` チャンネルインターフェースを導入し、スレッド作成不能時（DM 等）は安全にフォールバック。 |
| `0005-fix-copilot-session-resume.patch` | `pkg/providers/github_copilot_provider.go` を修正 | GitHub Copilot CLI はアイドル約 35 分でセッションを破棄するが、プロバイダはセッションをキャッシュしたまま `Session not found` エラーで失敗し続け、pod 再起動が必要だった。このパッチでは同エラーを検知し、同じ model/permission/hook 設定でセッションを透過的に再作成して `SendAndWait` を 1 回だけリトライする。 |

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
