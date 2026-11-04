# pstack in Antigravity

pstack in `antigravity/` is natively ported to the Antigravity agentic harness. All 58 skills, 23 `poteto-mode` playbooks, 2 subagents (`poteto-agent` and `comment-sicko`), scripts, and the Benny automation pack use Antigravity's native tools directly. This document serves as the architectural reference for how Cursor primitives map to Antigravity.

## Tools

| Cursor | Antigravity |
| --- | --- |
| `Task` | `invoke_subagent`, `define_subagent`, `send_message`, `manage_subagents` |
| `AskQuestion` | `ask_question` |
| `/loop` | `schedule` (`DurationSeconds` for one-shot timers, `CronExpression` for recurring schedules), plus `/schedule` and `/goal` slash commands |
| `Shell` / background jobs | `run_command` (`WaitMsBeforeAsync`, `IsDaemon`, `BypassSandbox`) and `manage_task` (`list`, `status`, `send_input`, `kill`) |
| `Read`, `Write`, `StrReplace` | `read_file`, `write_file`, `edit_file` |
| `create-skill` | `agy-customizations` built-in skill + `skills/poteto-mode/playbooks/authoring-a-skill.md` |
| `control-ui` (`cursor-team-kit`) | `.agents/skills/verify-<app>/SKILL.md` or `chrome-devtools-mcp` (`navigate_page`, `click`, `fill`, `take_screenshot`, `evaluate_script`, `performance_start_trace`, `take_heapsnapshot`) |
| `control-cli` (`cursor-team-kit`) | `.agents/skills/verify-<app>/SKILL.md` or `run_command` / `manage_task` (`send_input`) |
| `/deslop` (`cursor-team-kit`) | Inlined code-slop pass (remove narrating comments, unsupported guards, dead compatibility code, unrelated edits) + `unslop` + `no-comments` |
| `/visualize` | Mermaid `xychart-beta` / diagrams or `generative_ui` HTML widgets |
| Image generation tool | `invoke_subagent` with `TypeName: "image-generator"` |

## Subagent fields

| Cursor (`Task`) | Antigravity (`invoke_subagent` / `define_subagent`) |
| --- | --- |
| `subagent_type: "generalPurpose"` + `readonly: true` | `TypeName: "research"` (runs in a read-only sandbox with no MCP access) |
| `subagent_type: "generalPurpose"` + `readonly: false` | `TypeName: "self"` (full tools + MCP access) |
| `subagent_type: "poteto-agent"` | `TypeName: "poteto-agent"` (or `TypeName: "self"` instructing the agent to read `agents/poteto-agent.md`; can be registered in-session via `define_subagent`) |
| `subagent_type: "comment-sicko"` | `TypeName: "comment-sicko"` (registered via `define_subagent` with `EnableWriteTools: true` and `agents/comment-sicko.md`) |
| `environment: "cloud"` | `Workspace: "share"` (git-worktree-like shared repo isolation) or `Workspace: "branch"` (cloned/branched isolation) |
| `environment: "local"` | `Workspace: "inherit"` (default) |
| `cloud_base_branch: <b>` | Instruct the `Workspace: "share"` subagent to check out `<b>` first |
| `run_in_background: true` | Built-in reactive wakeup: `invoke_subagent` always runs in the background and automatically wakes the parent when it sends a message or finishes |
| `resume` | `send_message` (`Recipient: <conversationId>`) to continue an existing subagent's work |

## Dynamic Model Routing (`pro -> inherit -> flash -> flash_lite`)

Antigravity's `invoke_subagent` tool accepts `Model` values from the enum `["inherit", "flash_lite", "flash", "pro"]`:
- Because `pro` models may be unavailable in the current Antigravity environment and the parent model (`inherit`, e.g., Gemini 4 Argon) is rate-limited, pstack uses **dynamic fallback chains**:
  - **Code & high-fanout roles** (`feature, refactoring`, `bug-fix`, `perf-issue`, `hillclimb`, `how explorer`, `why investigators`, `reflect tooling`, `swarm workers`) default to `flash` to conserve parent (`inherit` / Argon) quota.
  - **Judgment, prose, synthesis, and hardest tasks** (`judgment and prose`, `hardest tasks`, `how explainer`, `why synthesizer`, `reflect judgment, divergent, synthesizer`) default to `pro -> inherit -> flash`: try `pro` first; if unavailable, fall back to `inherit` (parent model) or `flash`.
  - **Multi-agent panels** (`arena runners`, `architect runners`, `interrogate reviewers`) default to `pro -> inherit, flash`. When multiple runners in a panel resolve to the same model tier (e.g., both on `flash` or `inherit`), pstack assigns each runner a distinct **structural prior** or **adversarial lens** so the panel still explores genuinely distinct designs and failure modes.

[`/setup-pstack`](../../skills/setup-pstack/SKILL.md) configures these roles interactively via `ask_question` and writes `.agents/rules/pstack-models.md` (workspace) or `~/.gemini/config/pstack-models.md` (global).

## Paths

| Cursor | Antigravity |
| --- | --- |
| `.cursor-plugin/plugin.json` | `plugin.json` at the plugin root (`antigravity/plugin.json`) |
| `.cursor/skills/`, `~/.cursor/skills/` | `.agents/skills/`, `~/.gemini/config/skills/` |
| `~/.cursor/rules/pstack-models.mdc` | `.agents/rules/pstack-models.md` or `~/.gemini/config/pstack-models.md` |
| `.cursor/settings.json` | `.agents/plugins.json` |
| `.cursor/automations/benny/` | `.agents/automations/benny/` |
| `~/.cursor/projects/<slug>/agent-transcripts/` | `<appDataDir>/brain/<conversation-id>/.system_generated/logs/transcript.jsonl` (and `transcript_full.jsonl` when `truncated_fields` is present) |
| Scratch / artifacts | `<appDataDir>/brain/<conversation-id>/` and `<appDataDir>/brain/<conversation-id>/scratch/` |

## Automations and Sidecars

| Cursor | Antigravity |
| --- | --- |
| Cursor Automations (`/automate`) | Antigravity Sidecar Automations (`/automation` skill, `~/.gemini/config/sidecars/<id>/sidecar.json` spawning conversations via `agentapi new-conversation`) |
| `make-bot-ui` (`update_state` routine + `SendToUser` secret request) | Local HTTP webhook sidecar (`~/.gemini/config/sidecars/<slug>/`) reading `~/.gemini/config/sidecars/<slug>/.secret` and invoking `agentapi new-conversation` |
