---
name: how
description: "Use for \"how does X work\", code walkthroughs before changing something, and placement / ownership / layering questions (\"where should this live\", \"which package owns this\", \"is this the right layer\"). Explains subsystem architecture, runtime flow, onboarding mental models. Use why for motivation."
---

# How

Explore the codebase to answer "how does X work?" questions. Produce architectural explanations at the level of a senior engineer onboarding onto a subsystem, enough to build a working mental model, not so much that it reads like annotated source code.

Every spawn uses `invoke_subagent` with `TypeName: "research"` (or `TypeName: "poteto-explorer"` with `EnableWriteTools: false`, `EnableMCPTools: false`, `EnableSubagentTools: false` when running inside a nested custom subagent where built-in `"research"` is restricted; never pass `Name: "research"` to `define_subagent`). Explorers use the `how explorer` line in `.agents/rules/pstack-models.md` or `~/.gemini/config/pstack-models.md` (default `flash`), and every explainer uses the `how explainer` line (default `pro -> inherit -> flash`). Resolve fallback chains dynamically: if `pro` is unavailable in the environment, use `inherit` (parent model, e.g., Argon), or `flash` when conserving parent quota. Pick each subagent's `Model` for the job, per the Subagents section of the **poteto-mode** skill. After calling `invoke_subagent`, immediately end your turn and wait for reactive wakeup (never poll with `schedule` or `manage_subagents`).

## 1. Assess complexity

If the scope is ambiguous, state your interpretation and explore. The user can redirect.

- **Simple** (a single module, a small utility, a narrow question such as "how does function X work"): no explorers. Spawn one explainer via `invoke_subagent` (`TypeName: "research"`) that explores and explains in one pass, built from `references/explainer-prompt.md` without the explorer-findings section. Go to step 4.
- **Complex** (a subsystem spanning multiple files or services, a cross-cutting feature, a full architectural overview): go to step 2.

When in doubt, take the simple path.

## 2. Explore (complex only)

Decompose the question into 2 to 4 angles, each a distinct slice of the subsystem. Spawn all explorers in a single turn via `invoke_subagent` (`TypeName: "research"`, `Model: "flash"`), each with `references/explorer-prompt.md` and its angle filled in. End your turn and wait for their reactive wakeup notifications.

## 3. Synthesize (complex only)

Once all explorers have returned, spawn one explainer via `invoke_subagent` (`TypeName: "research"`, `Model` from `how explainer`: `pro -> inherit -> flash`) with `references/explainer-prompt.md` and every explorer's findings filled in.

## 4. Present

Present the explainer's output. Light edits for clarity or context from the conversation are fine. Do not substantially rewrite it.

## Output format

The explanation uses the sections defined in `references/explainer-prompt.md`, dropping any that do not apply: Overview, Key Concepts, How It Works, Where Things Live, Gotchas.
