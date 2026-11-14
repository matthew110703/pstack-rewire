# pstack in Antigravity

pstack in `antigravity/` is natively ported to the Antigravity agentic harness. All 58 skills, 23 `poteto-mode` playbooks, subagents (`poteto-agent`, `poteto-explorer`, and `comment-sicko`), scripts, and the Benny automation pack use Antigravity's native tools directly. This document serves as the architectural reference for how Cursor primitives map to Antigravity.

## Tools

| Cursor | Antigravity |
| --- | --- |
| `Task` | `invoke_subagent`, `define_subagent`, `send_message`, `manage_subagents` |
| Multi-stage workflow scripts | `run_workflow` (Python `phase`, `parallel`, `pipeline`, stateful `agent`, `trajectory`, `call_tool`, JSON-schema `finish`) |
| Coordinated parallel board | Native `swarm` (`swarm`, `post_message`, `read_board`, `swarm_wait`, `#channel` partitioning, `swarm_monitor`) |
| `AskQuestion` | `ask_question` |
| `/loop` | `schedule` (`DurationSeconds` for one-shot timers, `CronExpression` for recurring schedules), plus `/schedule` and `/goal` slash commands |
| Plan Mode | `Orchestrator (Argon)` (`gemini-pro-orchestrator-g1-pro`) `<plan_execute_protocol>`, `exit_plan_mode`, `enter_plan_mode`, plus `/plan` and `/grill-me` |
| `Shell` / background jobs | `run_command` (`WaitMsBeforeAsync`, `IsDaemon`, `BypassSandbox`) and `manage_task` (`list`, `status`, `send_input`, `kill`) |
| `Read`, `Write`, `StrReplace` | `read_file`, `write_file`, `edit_file` |
| `create-skill` | `agy-customizations` built-in skill + `skills/poteto-mode/playbooks/authoring-a-skill.md` |
| `control-ui` (`cursor-team-kit`) | `.agents/skills/verify-<app>/SKILL.md`, built-in `browser` subagent (`TypeName: "browser"`, `Model: "flash"`, `BROWSER_HOST_FACTS`), or `chrome-devtools-mcp` (`navigate_page`, `click`, `fill`, `take_screenshot`, `evaluate_script`, `performance_start_trace`, `take_heapsnapshot`) |
| `control-cli` (`cursor-team-kit`) | `.agents/skills/verify-<app>/SKILL.md` or `run_command` / `manage_task` (`send_input`) |
| `/deslop` (`cursor-team-kit`) | Inlined code-slop pass (remove narrating comments, unsupported guards, dead compatibility code, unrelated edits) + `unslop` + `no-comments` |
| `/visualize` | Mermaid `xychart-beta` / diagrams or `generative_ui` HTML widgets |
| Image generation tool | `invoke_subagent` with `TypeName: "image-generator"` |

## Subagent & Multi-Agent Engine Fields

| Cursor (`Task`) | Antigravity (`invoke_subagent` / `run_workflow` / `swarm`) |
| --- | --- |
| `subagent_type: "generalPurpose"` + `readonly: true` | `TypeName: "research"` from root session, or `TypeName: "poteto-explorer"` (`EnableWriteTools: false`, `EnableMCPTools: false`, `EnableSubagentTools: false`) when inside a nested custom subagent |
| `subagent_type: "generalPurpose"` + `readonly: false` | `TypeName: "self"` (full tools + MCP access) |
| `subagent_type: "poteto-agent"` | `TypeName: "poteto-coder"` (registered via `define_subagent` with `EnableWriteTools: true`, `EnableMCPTools: true`, `EnableSubagentTools: true` and `agents/poteto-agent.md`) or `TypeName: "self"` reading `agents/poteto-agent.md` (note: plugin-preloaded `poteto-agent` has `EnableWriteTools: false` and is advisory/read-only) |
| `subagent_type: "comment-sicko"` | `TypeName: "comment-sicko-writer"` (registered via `define_subagent` with `EnableWriteTools: true` and `agents/comment-sicko.md`) or `TypeName: "self"` reading `agents/comment-sicko.md` (note: plugin-preloaded `comment-sicko` has `EnableWriteTools: false`) |
| Browser automation subagent | `TypeName: "browser"` (`Model: "flash"`, staging uploads/references under `<Artifact Directory Path>/browser_sandbox/{uploads,references}/`, verified via `BROWSER_HOST_FACTS`) |
| `environment: "cloud"` | `Workspace: "share"` (git-worktree-like shared repo isolation) or `Workspace: "branch"` (cloned/branched isolation) |
| `environment: "local"` | `Workspace: "inherit"` (default) |
| `cloud_base_branch: <b>` | Instruct the `Workspace: "share"` subagent to check out `<b>` first |
| `run_in_background: true` | Built-in reactive wakeup: `invoke_subagent` and `run_workflow` run asynchronously and wake the parent when finished (never poll with `schedule` or `manage_subagents`) |
| `resume` | `send_message` (`Recipient: <conversationId>`) for `invoke_subagent`, or stateful `a = agent(...)` in `run_workflow` |

## Universal Multi-Hop Model Routing & Concrete Roster

Antigravity exposes two complementary model interfaces:

### 1. Subagent & Workflow Tiers (`invoke_subagent` & `run_workflow`)
Accepts `Model` values from `["inherit", "pro", "flash", "flash_lite"]`. Every role resolves through a complete multi-hop fallback chain so no spawn fails if any tier is disabled or quota-limited, and rejected tiers are cached for the rest of the session:
- **Code delegates & standard workers** (`feature, refactoring`, `bug-fix`, `perf-issue`, `hillclimb`, `swarm workers`): `flash -> inherit -> flash_lite`
- **Explorers, investigators & tooling** (`how explorer`, `why investigators`, `reflect tooling`): `flash -> flash_lite -> inherit` (or `flash_lite -> flash -> inherit` on `small` budget)
- **Judgment, prose, synthesis & hardest tasks** (`judgment and prose`, `hardest tasks`, `how explainer`, `why synthesizer`, `reflect judgment, divergent, synthesizer`): `pro -> inherit -> flash -> flash_lite`
- **Multi-agent panels** (`arena runners`, `architect runners`, `interrogate reviewers`): `pro -> inherit -> flash, flash -> inherit -> flash_lite` (cross-judge pool: `flash -> inherit, pro -> inherit -> flash`). When fallback collapses multiple seats onto the same tier, each runner receives a distinct **structural prior** or **adversarial lens**.

### 2. Concrete Session & Native `swarm` Models (`swarm{action: "models", all: true}`)
Query `swarm{action: "models", all: true}` to inspect live model availability and `quota_remaining` / `quota_resets` across all 18 concrete model+effort slugs:
- **Orchestrator Mode:** `gemini-pro-orchestrator-g1-pro` (*Orchestrator (Argon)* — Argon planning + Hydrogen execution)
- **Gemini 4 Argon / Carbon:** `gemini-4-argon-high`, `gemini-4-argon-medium`, `gemini-4-argon-low`
- **Gemini 4 Hydrogen:** `gemini-4-hydrogen-xhigh`, `gemini-4-hydrogen-high`, `gemini-4-hydrogen-medium`, `gemini-4-hydrogen-low`
- **Gemini 3.8 Flash:** `gemini-3.8-flash-high`, `gemini-3.8-flash-medium`, `gemini-3.8-flash-low`
- **Claude 5.5:** `claude-opus-5-5-high`, `claude-opus-5-5-medium`, `claude-opus-5-5-low`, `claude-sonnet-5-5-high`, `claude-sonnet-5-5-medium`, `claude-sonnet-5-5-low`
- **Open-Weight:** `gpt-oss-120b-medium`

When pinning concrete models in native `swarm`:
1. Filter against `swarm{action: "models", all: true}` so no missing or `0%` quota slug is passed.
2. Step down effort within a family (`xhigh -> high -> medium -> low`) before crossing families along the concrete chains in `rules/AGENTS.md` (ending with `inherit`).
3. Hot-swap any quota-exhausted worker in place via `swarm{action: "model", name: "<worker>", model: "<fallback-slug>"}` instead of killing its conversation.

[`/setup-pstack`](../../skills/setup-pstack/SKILL.md) inspects live models and quotas via `swarm{action: "models", all: true}` + `ask_question` and writes `.agents/rules/pstack-models.md` (workspace) or `~/.gemini/config/pstack-models.md` (global).

## Orchestrator Mode (`<plan_execute_protocol>` & `exit_plan_mode`)

When running under **Orchestrator (Argon)** (`gemini-pro-orchestrator-g1-pro`):
1. **Planning Turn (Argon, `plan_mode` on)**: Read-only grounding only. Encode the `in-your-own-words` restatement, data shape, throughput checkpoint, verification plan, and `"Re-plan if:"` triggers, then call `exit_plan_mode(plan="...")`.
2. **Execution Turn (Hydrogen)**: Perform edits, spawn delegates / `run_workflow` / `swarm`, and run surface verification. Hand back via `enter_plan_mode` if blocked twice or on `[plan review due]`. In `run_workflow`, skip `model="inherit"` when the parent session is `Orchestrator (Argon)` (`pro -> flash -> flash_lite`), and pass paths relative to `WORKSPACES[0]` (or absolute paths) regardless of `Cwd`. If `Orchestrator (Argon)` is unavailable or out of quota, fall back to `Gemini 4 Argon (High)` / `Claude Opus 5.5 (High)` for planning and `Gemini 4 Hydrogen (XHigh/High)` for execution.
3. **`[plan review]` Turn (Argon)**: Audit diffs and proof against playbook gates before delivering the final reply or continuing execution.

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
