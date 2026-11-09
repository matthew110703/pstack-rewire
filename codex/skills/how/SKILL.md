---
name: how
description: "Use for \"how does X work\", code walkthroughs before changing something, and placement / ownership / layering questions (\"where should this live\", \"which package owns this\", \"is this the right layer\"). Explains subsystem architecture, runtime flow, onboarding mental models. Use why for motivation."
---

# How

`<pstack>` is the pstack plugin root, two folders above this SKILL.md (Codex shows each skill's path; if not, run `ls -d ~/.codex/plugins/cache/*/pstack/*/ | sort -V | tail -1`). To run another pstack skill or `$pstack:<name>`, read `<pstack>/skills/<name>/SKILL.md` and follow it.

Explore the codebase to answer "how does X work?" questions. Produce architectural explanations at the level of a senior engineer onboarding onto a subsystem, enough to build a working mental model, not so much that it reads like annotated source code.

Every spawn is a `spawn_agent` subagent with `agent_type: "explorer"`. Every brief says not to edit files, and you check `git status` after each returns. Explorers use the `how explorer` line in the `pstack-models` block of `~/.codex/AGENTS.md` (default `inherit-parent`), and every explainer uses the `how explainer` line (default `gpt-6-astra xhigh`). Set `model` to that line's slug and `reasoning_effort` to its level, or to the default if the block or the line is missing. Leave `model` unset when the value is `auto` or `inherit-parent`. If the slug is not listed (`visibility: "list"`) in `~/.codex/models_cache.json`, or `spawn_agent` rejects it, use the default and say so. If the default is rejected too, omit `model` and say so. Pick each subagent's effort level for the job, per the Subagents section of the **poteto-mode** skill.

## 1. Assess complexity

If the scope is ambiguous, state your interpretation and explore. The user can redirect.

- **Simple** (a single module, a small utility, a narrow question such as "how does function X work"): no explorers. Spawn one explainer that explores and explains in one pass, built from `<pstack>/skills/how/references/explainer-prompt.md` without the explorer-findings section. Go to step 4.
- **Complex** (a subsystem spanning multiple files or services, a cross-cutting feature, a full architectural overview): go to step 2.

When in doubt, take the simple path.

## 2. Explore (complex only)

Decompose the question into 2 to 4 angles, each a distinct slice of the subsystem. Spawn all explorers in a single message, each with `<pstack>/skills/how/references/explorer-prompt.md` and its angle filled in.

## 3. Synthesize (complex only)

Once all explorers have returned, spawn one explainer with `<pstack>/skills/how/references/explainer-prompt.md` and every explorer's findings filled in.

## 4. Present

Present the explainer's output. Light edits for clarity or context from the conversation are fine. Do not substantially rewrite it.

## Output format

The explanation uses the sections defined in `<pstack>/skills/how/references/explainer-prompt.md`, dropping any that do not apply: Overview, Key Concepts, How It Works, Where Things Live, Gotchas.
