[日本語](README.ja.md)

# picoclaw-copilot

A soft fork of [picoclaw](https://github.com/sipeed/picoclaw). This project focuses on patch-based customization, Nix flake builds, and auto-publishing to GHCR via GitHub Actions.

## Customizations

- Register all built-in commands (start, help, show, list, use, switch, check, clear, subagents, reload) as Discord slash commands. Text commands still work as usual.
- Support Discord role IDs in `allow_from` configuration, alongside user IDs.
  - Role-based access control works only for messages and slash commands within a guild (server). DM interactions don't provide role information, so include user IDs if you need DM access.
- `opencode_task` tool: Delegate coding tasks to an [opencode](https://opencode.ai/) agent via its REST API. Supports HTTP Basic authentication.

## Patches

| Filename | Summary | Features Added |
|---|---|---|
| `0001-add-slash-commands.patch` | Modifies `pkg/bus/types.go`, `pkg/channels/base.go`, and `pkg/channels/discord/discord.go` | Adds Discord slash command registration for 10 built-in commands, implements `handleInteraction` to translate slash commands to text format, adds `isAllowedByRole` helper for role-based `allow_from` support, and introduces a `PreAuthorized` flag to skip redundant allow-list re-checks. |
| `0002-add-opencode-tool.patch` | Adds `pkg/tools/opencode_task.go`, modifies `pkg/config/config.go` and `pkg/agent/loop.go` | Adds `opencode_task` tool that delegates coding tasks to an opencode agent via REST API (POST /session → POST /session/:id/message). Configurable via `PICOCLAW_TOOLS_OPENCODE_TASK_*` env vars (ENABLED, SERVER_URL, USERNAME, PASSWORD). |

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
