---
name: reflect
description: Spawn three parallel review subagents over the active transcript, surface learnings, and route each to a concrete edit on an existing skill. Use when the user says reflect.
---

# Reflect

Mine the current conversation for durable learnings, then route them into skill edits.

Invoke when the user says "reflect" or "/reflect". Skip when the conversation is trivial, off-topic, or already covered by an existing skill the parent followed correctly. One-offs are not learnings.

## 1. Locate the active transcript

Before fanning out, locate this conversation's transcript at `<appDataDir>/brain/<conversation-id>/.system_generated/logs/transcript.jsonl` (or `transcript_full.jsonl` when `truncated_fields` is present; the system prompt names both `<appDataDir>` and `<conversation-id>`). Do not scan across unrelated conversations in `<appDataDir>/brain/` unless asked. If the file is unavailable, pass a tight digest of the session instead.

## 2. Spawn three reviewers in parallel (or run as a `run_workflow` pipeline)

Choose one execution path:
- **`invoke_subagent` wave**: One turn, three `invoke_subagent` calls with `TypeName: "self"` (so reviewers retain MCP access to look up the tickets, chat threads, and observability traces the transcript references; `TypeName: "research"` strips MCP access).
- **`run_workflow` pipeline** (recommended for complex sessions): Run one `run_workflow` script that can inspect recent steps/errors directly via `await trajectory(...)`, run `phase("Review")` with `parallel` across the three lenses (`type_name="self"`), and feed all three outputs straight into `phase("Synthesize")` with `agent(...)` and tier fallback if any `model` tier is unavailable (under `Orchestrator (Argon)`, skip `"inherit"` inside `run_workflow` `agent(model=...)` and resolve `"pro" -> "flash" -> "flash_lite"`, passing paths relative to `WORKSPACES[0]`).

Each reviewer and the synthesizer name a role line in `.agents/rules/pstack-models.md` or `~/.gemini/config/pstack-models.md` and a default. Resolve multi-hop fallback chains automatically (`pro -> inherit -> flash -> flash_lite` for judgment/divergent/synthesizer; `flash -> flash_lite -> inherit` for tooling): if any tier is unavailable, rejected, or out of quota, advance immediately to the next hop in its chain. Pick each subagent's `Model` for the job, per the Subagents section of the **poteto-mode** skill.

| Lens | Role line | Default `Model` | Prompt template |
|---|---|---|---|
| Judgment | `reflect judgment, divergent, synthesizer` | `pro -> inherit -> flash -> flash_lite` | `references/judgment-reviewer.md` |
| Tooling | `reflect tooling` | `flash -> flash_lite -> inherit` | `references/tooling-reviewer.md` |
| Divergent | `reflect judgment, divergent, synthesizer` | `pro -> inherit -> flash -> flash_lite` | `references/divergent-reviewer.md` |

Pass each template verbatim, substituting the transcript path or digest where marked. End your turn and wait for their reactive wakeup notifications.

## 3. Synthesize

One `invoke_subagent` call, `TypeName: "self"`, `Model` from the `reflect judgment, divergent, synthesizer` line (default `pro -> inherit -> flash -> flash_lite`)—or `phase("Synthesize")` inside Step 2's `run_workflow`. It spot-verifies citations through MCP. Pass `references/synthesizer.md` verbatim, with each reviewer's full output inlined where marked. It returns an Accepted / Rejected / Backlog list.

## 4. Structural enforcement check

Move any Accepted item that a lint rule, script, metadata flag, or runtime check would enforce more reliably to Backlog. See the **principle-encode-lessons-in-structure** skill.

## 5. Apply

Present the synthesizer's full Accepted / Rejected / Backlog output and wait for explicit approval before applying any Accepted edit. The user picks the subset and may redirect routings. Skill changes affect every future agent in the org. Do not auto-apply.

File each Backlog item to your team's devex or backlog tracker without waiting. Only the Accepted list waits for approval.

Never edit a skill inside an installed read-only plugin bundle. Before approval, show its destination: `.agents/skills/<skill>/` (workspace) or `~/.gemini/config/skills/<skill>/` (user). After approval, copy the skill folder there (or edit in place if already in the workspace/user skills directory). Never open a PR or push without being asked.

Follow each approved row's Routing exactly:

- Trivial existing-skill edit (a one-line bullet, a tightened sentence, a stale fact corrected): the parent does it directly.
- Substantive existing-skill edit (a new section, a new pattern table, more than ~10 lines): follow the **agy-customizations** skill and **poteto-mode**'s `playbooks/authoring-a-skill.md` draft / test / iterate loop.
- `tune description: <skill path>` (the skill exists but didn't trigger when it should have): refine the YAML frontmatter `description` per **agy-customizations** and `playbooks/authoring-a-skill.md`.
- `new skill via agy-customizations: <kebab-name>` (or `new skill via create-skill: <kebab-name>`): author the skill following **agy-customizations** and `playbooks/authoring-a-skill.md`. Do not invent the shape ad hoc.

## 6. Summarize for the user

Short list, no preamble:

- Edits applied: `<skill path>`. What changed, one line each.
- New skills created: `<skill path>`. One line each (rare).
- Backlog filed to the devex tracker: `<issue title>` (`<tags>`). One line each.
- Dropped: one line per rejected finding + reason from the synthesizer.
