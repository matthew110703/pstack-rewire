---
name: how
description: "Use for \"how does X work\", code walkthroughs before changing something, and placement / ownership / layering questions (\"where should this live\", \"which package owns this\", \"is this the right layer\"). Explains subsystem architecture, runtime flow, onboarding mental models. Use why for motivation."
---

# How

Explore the codebase to answer "how does X work?" questions. Produce architectural explanations at the level of a senior engineer onboarding onto a subsystem, enough to build a working mental model, not so much that it reads like annotated source code.

Every spawn uses `invoke_subagent` with `TypeName: "research"` (or `TypeName: "poteto-explorer"` with `EnableWriteTools: false`, `EnableMCPTools: false`, `EnableSubagentTools: false` when running inside a nested custom subagent where built-in `"research"` is restricted; never pass `Name: "research"` to `define_subagent`), or a single two-phase `run_workflow` script (`phase("Explore")` with `parallel(...)` -> `phase("Synthesize")` with `agent(...)`) for complex subsystems. Explorers use the `how explorer` line in `.agents/rules/pstack-models.md` or `~/.gemini/config/pstack-models.md` (default `flash -> flash_lite -> inherit`), and every explainer uses the `how explainer` line (default `pro -> inherit -> flash -> flash_lite`). Resolve fallback chains automatically: if any tier is unavailable, rejected, or quota-limited, advance to the next hop in its chain (inside `run_workflow` under `Orchestrator (Argon)`, skip `"inherit"` and resolve `"pro" -> "flash" -> "flash_lite"` directly, passing paths relative to `WORKSPACES[0]`). Pick each subagent's `Model` for the job, per the Subagents section of the **poteto-mode** skill. After calling `invoke_subagent` or `run_workflow`, immediately end your turn and wait for reactive wakeup (never poll with `schedule` or `manage_subagents`).

## 1. Assess complexity

If the scope is ambiguous, state your interpretation and explore. The user can redirect.

- **Simple** (a single module, a small utility, a narrow question such as "how does function X work"): no explorers. Spawn one explainer via `invoke_subagent` (`TypeName: "research"`) that explores and explains in one pass, built from `references/explainer-prompt.md` without the explorer-findings section. Go to step 4.
- **Complex** (a subsystem spanning multiple files or services, a cross-cutting feature, a full architectural overview): go to step 2.

When in doubt, take the simple path.

## 2. Explore (complex only)

Decompose the question into 2 to 4 angles, each a distinct slice of the subsystem. Choose one execution path:
- **`invoke_subagent` wave**: Spawn all explorers in a single turn via `invoke_subagent` (`TypeName: "research"`, `Model` from `how explorer`: `flash -> flash_lite -> inherit`), each with `references/explorer-prompt.md` and its angle filled in. End your turn and wait for their reactive wakeup notifications.
- **`run_workflow` two-phase pipeline** (recommended when avoiding a manual relay turn): Call `run_workflow` with `phase("Explore")` running `parallel(angles, lambda a: agent(..., type_name="research", model="flash", schema={"type": "string"}))` (falling back to `"flash_lite"` or, outside Orchestrator, `"inherit"` if `"flash"` is unavailable) followed immediately by `phase("Synthesize")` running the explainer `agent(...)` (skip `"inherit"` under `Orchestrator (Argon)` — use `"pro"` -> `"flash"` -> `"flash_lite"`, passing paths relative to `WORKSPACES[0]`), then jump to step 4 when the workflow completes.

## 3. Synthesize (complex only)

Once all explorers have returned (if using `invoke_subagent`), spawn one explainer via `invoke_subagent` (`TypeName: "research"`, `Model` from `how explainer`: `pro -> inherit -> flash -> flash_lite`) with `references/explainer-prompt.md` and every explorer's findings filled in.

## 4. Present

Present the explainer's output. Light edits for clarity or context from the conversation are fine. Do not substantially rewrite it.

## Output format

The explanation uses the sections defined in `references/explainer-prompt.md`, dropping any that do not apply: Overview, Key Concepts, How It Works, Where Things Live, Gotchas.
