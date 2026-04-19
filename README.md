[日本語](README.ja.md)

# picoclaw-copilot

A soft fork of [picoclaw](https://github.com/sipeed/picoclaw). This project focuses on patch-based customization, Nix flake builds, and auto-publishing to GHCR via GitHub Actions.

## Customizations

- Register all built-in commands (start, help, show, list, use, switch, check, clear, subagents, reload) as Discord slash commands. Text commands still work as usual.
- Support Discord role IDs in `allow_from` configuration, alongside user IDs.
  - Role-based access control works only for messages and slash commands within a guild (server). DM interactions don't provide role information, so include user IDs if you need DM access.
- `opencode_task` tool: Delegate coding tasks to an [opencode](https://opencode.ai/) agent via its REST API. Supports async execution, SSE event monitoring (forwards `question.asked` events to Discord with auto-reject), and HTTP Basic authentication.
  - **Requires a separately running opencode server.** This tool connects to it via `SERVER_URL` — opencode is not included in this image.
  - **Note**: This tool targets a self-hosted opencode server's internal API. The SSE event format and question/control endpoints may differ from the public opencode SDK. Verify your server version matches the expected API contract.
- Multi-channel session history in the Web UI: session API generalized from pico-only to channel-agnostic so Discord (and other channel) sessions appear in the session history list, with channel-type icons in the frontend.
- Subagent Discord thread visibility: when an agent spawns a subturn, a Discord thread is opened so users can follow subagent activity in real time. Falls back gracefully when thread creation is unavailable (e.g. DMs).
- Resilient GitHub Copilot provider: transparently recreates its session on `Session not found` errors (which the Copilot CLI raises after idle timeout / CLI restart) and retries once, so long-idle bots no longer need a full restart to recover.

## Patches

| Filename | Summary | Features Added |
|---|---|---|
| `0001-add-slash-commands.patch` | Modifies `pkg/bus/types.go`, `pkg/channels/base.go`, and `pkg/channels/discord/discord.go` | Adds Discord slash command registration for 10 built-in commands, implements `handleInteraction` to translate slash commands to text format, adds `isAllowedByRole` helper for role-based `allow_from` support, and introduces a `PreAuthorized` flag to skip redundant allow-list re-checks. |
| `0002-add-opencode-tool.patch` | Adds `pkg/tools/opencode_task.go`, modifies `pkg/config/config.go` and `pkg/agent/loop.go` | Adds `opencode_task` tool that delegates coding tasks to an opencode agent via REST API (POST /session → GET /event SSE → POST /session/:id/message). Implements `AsyncExecutor` for non-blocking execution, SSE listener that forwards `question.asked` events to Discord and auto-rejects them. Configurable via `PICOCLAW_TOOLS_OPENCODE_TASK_*` env vars (ENABLED, SERVER_URL, USERNAME, PASSWORD). |
| `0003-add-multi-channel-session-history.patch` | Modifies `web/backend/api/session.go`, `web/frontend/src/api/sessions.ts`, `web/frontend/src/hooks/use-sidebar-channels.ts`, and adds `web/frontend/src/components/chat/session-history-menu.tsx` | Generalizes the session history API from pico-only to channel-agnostic so Discord and other channels appear in the Web UI session list. Adds input validation and path-traversal defense on the backend, plus channel-type icons in the frontend. |
| `0004-add-subagent-discord-visibility.patch` | Modifies `pkg/channels/discord/discord.go`, `pkg/channels/interfaces.go`, `pkg/gateway/gateway.go`, and adds `pkg/gateway/subturn_notifier.go` | Opens a Discord thread per subturn event so users can observe subagent activity in real time. Uses a two-goroutine architecture (EventBus `eventLoop` for state, `workerLoop` for Discord I/O) to avoid blocking the gateway. Introduces a `ThreadCapable` channel interface and falls back gracefully when thread creation isn't possible (e.g. DMs). |
| `0005-fix-copilot-session-resume.patch` | Modifies `pkg/providers/github_copilot_provider.go` | The GitHub Copilot CLI discards sessions after ~35 minutes of idle time; the provider used to cache its session forever and fail with `Session not found` until the pod was restarted. This patch detects that error, transparently recreates the session with the same model/permission/hook config, and retries `SendAndWait` once. |

## Included Packages

| Package | Purpose |
|---|---|
| picoclaw | Core application |
| git | Repository operations |
| openssh | SSH connectivity |
| gh (GitHub CLI) | GitHub API interactions |
| bash | Shell environment |
| coreutils | Essential commands |
| cacert | TLS certificates |
| tzdata | Timezone data |

## Usage

```bash
docker pull ghcr.io/turtton/picoclaw-copilot:latest
docker run --rm ghcr.io/turtton/picoclaw-copilot version
```

The `ENTRYPOINT` is set to `picoclaw`, so any arguments pass directly to picoclaw subcommands and flags.

## Local Build

Requires [Nix](https://nixos.org/).

```bash
nix build .#picoclaw
nix build .#docker
docker load < result
```

## Patch Development

```bash
./scripts/fetch-upstream.sh
./scripts/apply-patches.sh

# After making changes in .upstream/:
./scripts/create-patch.sh 0002-my-change
```

## CI/CD

- **Build and Push** (`build.yml`): Builds the Docker image and pushes it to GHCR on every push to `main`.
- **Update** (`update.yml`): Checks for new upstream versions daily and automatically updates/commits `flake.nix` and `.upstream-version`. If patches fail to apply to the new version, the build will fail.
