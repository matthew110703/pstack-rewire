# pstack dynamic model routing, orchestrator protocol & multi-agent engines

When `pstack` skills or `/poteto-mode` playbooks spawn agents, they resolve each role's model config from `.agents/rules/pstack-models.md` (workspace override) or `~/.gemini/config/pstack-models.md` (user override), falling back to the defaults and multi-hop fallback rules below.

## Universal Multi-Hop Model Fallback (Guaranteed Non-Failing Routing)

Antigravity exposes two model layers: **tier aliases** on `invoke_subagent` / `run_workflow` and **concrete model+effort slugs** on the session picker and native `swarm`. Every role must resolve through a multi-hop fallback chain so no task or subagent fails if any model is disabled, removed, or out of quota.

### Layer 1: `invoke_subagent` & `run_workflow` Tier Chains (`pro`, `inherit`, `flash`, `flash_lite`)

1. **Multi-hop tier fallback**:
   - **Judgment, synthesis, prose & hardest tasks**: `pro -> inherit -> flash -> flash_lite`
   - **Code delegates & standard workers**: `flash -> inherit -> flash_lite`
   - **High-fanout explorers, tooling & transcript miners**: `flash -> flash_lite -> inherit` (or `flash_lite -> flash -> inherit` on `small` budget)
   - **`run_workflow` under `Orchestrator (Argon)` (`model="inherit"` prohibition)**: When the parent session runs on `Orchestrator (Argon)` (`gemini-pro-orchestrator-g1-pro`), `run_workflow` child `agent()` calls MUST NOT pass `model="inherit"` — inheriting Orchestrator inside `run_workflow` triggers a `[plan review due]` / `enter_plan_mode` hook deadlock that blocks `finish`. Always resolve explicit concrete/non-inherit tiers inside `run_workflow` (`pro -> flash -> flash_lite`, skipping `"inherit"`). (`invoke_subagent` with `Model: "inherit"` does not hit this deadlock.)
   - **Ultimate safety net**: If a role's configured tier fails, is rejected by `invoke_subagent` / `run_workflow`, or hits quota/capacity limits, immediately advance to the next hop in its chain. If all explicit tiers fail outside `Orchestrator + run_workflow`, omit `Model` so the runtime uses the parent session default (`inherit`).
2. **Session-level rejection caching**: Once a model tier (e.g., `"pro"`) or concrete slug is rejected or out of quota in the current session, remember it for the rest of the session and jump directly to the next available hop on subsequent spawns without re-triggering the error.
3. **Multi-agent diversity on a single model tier**: When fallback collapses a panel (`arena runners`, `architect runners`, `interrogate reviewers`) onto the same tier (e.g., two `flash` or `inherit` runners), assign each seat a distinct **structural prior** or **adversarial lens** in its `Prompt` and `Role`.

### Layer 2: Concrete Session & Native `swarm` Slugs (`swarm{action: "models", all: true}`)

Query live availability and `quota_remaining` / `quota_resets` before dispatching multi-model `swarm` runs or changing budgets via `swarm{action: "models", all: true}`:

| Family / Mode | Concrete Slugs (`swarm` & Session) | Equivalent Tier | Quota Pool & Best Fit |
| :--- | :--- | :--- | :--- |
| **Orchestrator** | `gemini-pro-orchestrator-g1-pro` (*Orchestrator (Argon)*) | `inherit` | **Argon pool** (Argon plan/review + Hydrogen execution) |
| **Gemini 4 Argon / Carbon** | `gemini-4-argon-high`, `medium`, `low` | `pro` / `inherit` | **Argon pool** (deep architecture, synthesis, hardest tasks) |
| **Gemini 4 Hydrogen** | `gemini-4-hydrogen-xhigh`, `high`, `medium`, `low` | `flash` / `inherit` | **Hydrogen/Flash pool** (fast code edits, runners, execution) |
| **Gemini 3.8 Flash** | `gemini-3.8-flash-high`, `medium`, `low` | `flash` / `flash_lite` | **Hydrogen/Flash pool** (high-fanout explorers, tooling, `browser`) |
| **Claude 5.5** | `claude-opus-5-5-{high,medium,low}`, `claude-sonnet-5-5-{high,medium,low}` | Cross-family `swarm` | **Claude/Partner pool** (cross-family panels & judging) |
| **Open-Weight** | `gpt-oss-120b-medium` | Cross-family `swarm` | **Claude/Partner pool** (independent verification tie-breaker) |

**Concrete slug fallback rules**:
1. **Pre-flight filter**: Never pass a concrete slug to `swarm{action: "add" | "model"}` if it is absent from `swarm{action: "models", all: true}` or has `0%` `quota_remaining` (unless AI credits cover it per `quota_note`).
2. **Effort step-down (`xhigh -> high -> medium -> low`)**: If a slug's effort level is unavailable or exhausted, step down within the same family before switching families.
3. **Cross-family concrete chains**:
   - **Frontier Reasoning / Synthesis**: `gemini-4-argon-high -> claude-opus-5-5-high -> gemini-4-hydrogen-xhigh -> gemini-4-argon-medium -> claude-sonnet-5-5-high -> gemini-4-hydrogen-high -> gemini-3.8-flash-high -> inherit (omit model)`
   - **Fast Code / Execution**: `gemini-4-hydrogen-xhigh -> gemini-4-hydrogen-high -> claude-sonnet-5-5-high -> gemini-3.8-flash-high -> gemini-4-hydrogen-medium -> gemini-3.8-flash-medium -> gpt-oss-120b-medium -> inherit (omit model)`
   - **Cross-Family Panel Seat 1 (Gemini 4)**: `gemini-4-argon-high -> gemini-4-hydrogen-xhigh -> gemini-4-hydrogen-high -> gemini-3.8-flash-high -> inherit`
   - **Cross-Family Panel Seat 2 (Claude / Partner)**: `claude-opus-5-5-high -> claude-sonnet-5-5-high -> gpt-oss-120b-medium -> gemini-4-hydrogen-high -> gemini-3.8-flash-high -> inherit`
4. **Mid-run quota hot-swap (`swarm{action: "model"}`)**: If a `swarm` worker fails on quota or receives a `[quota]` low-quota warning, never `kill` and re-`add` it. Switch its model in place along its fallback chain (or omit `model` to inherit the coordinator's live model) so it preserves its conversation state and resumes.

## Orchestrator Mode (`<plan_execute_protocol>` & `exit_plan_mode`)

When running under **Orchestrator (Argon)** (`gemini-pro-orchestrator-g1-pro`):

1. **Planning Turn (`plan_mode` active, editing tools refused)**:
   - Do read-only grounding only (`read_file`, `grep_search`, read-only `run_command`, or read-only `how`/`why` subagents). Never call `write_file` or `edit_file` for workspace changes.
   - Put the `/poteto-mode` `in-your-own-words` restatement, chosen data shape (`principle-model-the-domain`), throughput checkpoint, ordered playbook steps, exact verification commands, and `"Re-plan if:"` triggers into the plan.
   - If the user asked to review the plan first (`/plan`), present it and wait. Otherwise call `exit_plan_mode(plan="...")` to hand execution to **Gemini 4 Hydrogen**.
2. **Execution Turn (`Gemini 4 Hydrogen`)**:
   - Execute the plan's edits, `invoke_subagent` / `run_workflow` / `swarm` spawns, surface verification, `/unslop`, and `/no-comments` passes. Hand back via `enter_plan_mode` if blocked twice, a plan assumption fails, or a `[plan review due]` message arrives.
3. **`[plan review]` Turn (`Gemini 4 Argon`)**:
   - Audit Hydrogen's diff and verification output against the playbook's exit criteria. Either call `exit_plan_mode` with remaining steps or deliver the final `/poteto-mode` report.
4. **Orchestrator Fallback**:
   - If `Orchestrator (Argon)` (`gemini-pro-orchestrator-g1-pro`) is unavailable or out of quota, fall back to `Gemini 4 Argon (High)` (`gemini-4-argon-high`) or `Claude Opus 5.5 (High)` (`claude-opus-5-5-high`) for planning/synthesis and `Gemini 4 Hydrogen (XHigh/High)` (`gemini-4-hydrogen-xhigh` / `gemini-4-hydrogen-high`) for execution.

## Multi-Agent Engine Selection & Antigravity Subagent Rules

1. **Choose the right execution engine**:
   - **`invoke_subagent`**: Best for single delegates (`poteto-coder`, `self`, `comment-sicko-writer`, `research`, `poteto-explorer`, `browser`, `image-generator`) and quick waves. Antigravity mounts plugin `agents/*.md` (`poteto-agent`, `comment-sicko`) read-only (`EnableWriteTools: false`); for delegates that edit files or run shell commands, use `TypeName: "self"` (instructed to read `agents/poteto-agent.md` or `agents/comment-sicko.md`) or call `define_subagent` once per session with a distinct writable name (`Name: "poteto-coder"` or `"comment-sicko-writer"`, `EnableWriteTools: true`, `EnableMCPTools: true`, `EnableSubagentTools: true`).
   - **`run_workflow`**: Best for staged multi-agent pipelines (`phase()`, `parallel()`, `pipeline()`, stateful `agent()`, `await trajectory()`, `call_tool()`, and JSON-schema `finish` outputs) such as `how`, `why`, `reflect`, `arena`, and 5+ slice `swarm` runs. Under `Orchestrator (Argon)`, child `agent(model=...)` calls MUST skip `"inherit"` (`pro -> flash -> flash_lite`) to avoid the `[plan review due]` / `enter_plan_mode` `finish` deadlock, and `agent()` prompts must pass paths relative to `WORKSPACES[0]` (or absolute paths) because `run_workflow(Cwd=...)` sets only the Python orchestrator's working directory.
   - **Native `swarm`**: Best for true cross-family multi-model panels (pinning concrete slugs like `gemini-4-argon-high` + `claude-opus-5-5-high`) and coordinated multi-worktree programs (`workspace: "share"`, `#channel` partitioning, `swarm_monitor`, mid-run `swarm{action: "model"}` hot-swap).
2. **Reactive Wakeup (Never Poll After `invoke_subagent` or `run_workflow`)**: Subagents and workflows run asynchronously and automatically resume your turn when they finish. Immediately end your turn after launching a wave; never poll with `schedule(...)` or `manage_subagents(Action: "list")`.
3. **Nested Read-Only Subagents (`poteto-explorer` vs `research`)**: Built-in `TypeName: "research"` is reserved for the root session agent. Inside a nested custom subagent (`poteto-coder`, `poteto-agent`), or if `invoke_subagent(TypeName: "research")` is denied, call `define_subagent(Name: "poteto-explorer", Description: "Read-only exploration and review subagent", SystemPrompt: "You are a read-only exploration and review subagent. Do not modify files.", EnableWriteTools: false, EnableMCPTools: false, EnableSubagentTools: false)` and invoke `TypeName: "poteto-explorer"`.
4. **Built-in `browser` Subagent (`TypeName: "browser"`)**: Use `Model: "flash"` by default (tell the user before switching models if `flash` errors). Stage uploads in `<Artifact Directory Path>/browser_sandbox/uploads/` and references in `<Artifact Directory Path>/browser_sandbox/references/`. Verify every visited origin and screenshot against the host-emitted `BROWSER_HOST_FACTS` message.

## Default Role Mapping

```text
# budget: large (xhigh reasoning, multi-hop fallback on every role)
feature, refactoring: flash -> inherit -> flash_lite
bug-fix: flash -> inherit -> flash_lite
perf-issue: flash -> inherit -> flash_lite
hillclimb: flash -> inherit -> flash_lite
judgment and prose: pro -> inherit -> flash -> flash_lite
hardest tasks: pro -> inherit -> flash -> flash_lite
how explorer: flash -> flash_lite -> inherit
how explainer: pro -> inherit -> flash -> flash_lite
why investigators: flash -> flash_lite -> inherit
why synthesizer: pro -> inherit -> flash -> flash_lite
reflect tooling: flash -> flash_lite -> inherit
reflect judgment, divergent, synthesizer: pro -> inherit -> flash -> flash_lite
arena runners: pro -> inherit -> flash, flash -> inherit -> flash_lite
arena cross-judge pool: flash -> inherit, pro -> inherit -> flash
swarm workers: flash -> inherit -> flash_lite
architect runners: pro -> inherit -> flash, flash -> inherit -> flash_lite
interrogate reviewers: pro -> inherit -> flash, flash -> inherit -> flash_lite
# @swarm concrete fallback chains (parsed by /setup-pstack and native swarm panels):
@swarm frontier: gemini-4-argon-high -> claude-opus-5-5-high -> gemini-4-hydrogen-xhigh -> gemini-4-argon-medium -> claude-sonnet-5-5-high -> gemini-3.8-flash-high -> inherit
@swarm code: gemini-4-hydrogen-xhigh -> gemini-4-hydrogen-high -> claude-sonnet-5-5-high -> gemini-3.8-flash-high -> gemini-4-hydrogen-medium -> gpt-oss-120b-medium -> inherit
@swarm panel-seat-1: gemini-4-argon-high -> gemini-4-hydrogen-xhigh -> gemini-4-hydrogen-high -> gemini-3.8-flash-high -> inherit
@swarm panel-seat-2: claude-opus-5-5-high -> claude-sonnet-5-5-high -> gpt-oss-120b-medium -> gemini-4-hydrogen-high -> gemini-3.8-flash-high -> inherit
```
