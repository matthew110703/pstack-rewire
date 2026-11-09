---
name: setup-pstack
description: Configure which models pstack uses per role and at what reasoning budget. Detects your available models and writes an always-loaded block in your global AGENTS.md that overrides the skill defaults. Use for $pstack:setup-pstack, "configure pstack models", "pstack budget", or changing pstack's model choices.
---

# Setup pstack

This SKILL.md is longer than the part Codex injects. Before acting, read this whole file from the path Codex shows for it, then follow all of it.

`<pstack>` is the pstack plugin root, two folders above this SKILL.md (Codex shows each skill's path; if not, run `ls -d ~/.codex/plugins/cache/*/pstack/*/ | sort -V | tail -1`). To run another pstack skill or `$pstack:<name>`, read `<pstack>/skills/<name>/SKILL.md` and follow it.

Write the `pstack-models` block of `~/.codex/AGENTS.md`, or of `~/.codex/AGENTS.override.md` when that file exists. Codex loads it into every session, and it sets pstack's model per role.

## Steps

### 1. Detect available models

Read `~/.codex/models_cache.json`. That is the dependable source. Each entry in its `models` list with `visibility: "list"`, with each of its `supported_reasoning_levels[].effort` values, is one detected slug, written `<model> <effort>`, such as `gpt-6-astra xhigh`. Leave out `ultra`, which pstack never sets. If the file is missing or lists no models, ask the user to paste the slugs they have access to (`/model` shows them). Never write a real slug you have not confirmed is available. The aliases `inherit-parent` and `auto` are always valid even though they are not detected slugs.

### 2. Load current state

The default role-to-model mapping is the block shape shown in step 5 below. The target file is `~/.codex/AGENTS.override.md` when it exists, else `~/.codex/AGENTS.md`. If it already holds the block, between `<!-- pstack-models:begin -->` and `<!-- pstack-models:end -->`, read it and treat its `# budget` line and its role values as the current choices. Otherwise start from those defaults. A line whose role is not in step 5, such as `how critics`, is from a retired role. Drop it.

### 3. Budget, map, and confirm

**(a) Ask for a budget.** Prefer `request_user_input` over free text. Offer these four choices with these exact labels, and name the current budget when the block records one. With no block, say that `large` matches the skill defaults. `request_user_input` takes at most 3 options per question, so give `large`, `unlimited`, and `medium` as options and name `small — medium reasoning` in the question, so the user can pick it through "Other". If the tool is unavailable or refused, list all four as numbered options in plain text and end the turn. In `codex exec`, take the current budget, or `large`, and say so.

- `unlimited — max reasoning`
- `large — xhigh reasoning`
- `medium — high reasoning`
- `small — medium reasoning`

**(b) Apply it.** Build the working table from the skill defaults, and on a re-run keep any role you changed by family, list, or alias (`inherit-parent`, `auto`). `unlimited`, `large`, `medium`, and `small` set the effort token of every real slug, panel entries included, to `max`, `xhigh`, `high`, or `medium`. The effort token is the last token, on the ladder `max` > `xhigh` > `high` > `medium` > `low`. Never set `ultra`. If the result is not a detected slug, use the same model's detected slug with the highest effort at or below the target, else mark the role as needing a choice. `inherit-parent` and `auto` do not change. So `unlimited` turns `gpt-6-astra xhigh` into `gpt-6-astra max` and `gpt-6.1-sol xhigh` into `gpt-6.1-sol max`. `gpt-6-luna` tops out at `max`. `large` keeps the defaults. `small` turns `gpt-6-astra xhigh` into `gpt-6-astra medium`.

**(c) Show the roles and confirm.** Show every role with its model, marking any real slug not in the detected set as needing a choice. Also list each line step 2 dropped. Ask whether to accept as-is or change specific roles, offering the detected models plus `inherit-parent` and `auto` (both mean: this role runs on the session model set by `/model`) as the options. For the code roles and `swarm workers`, also offer `gpt-6.1-terra` as the fast code model. Prefer `request_user_input` over free text. It takes at most 3 options per question, so offer `inherit-parent` and `auto` as one option, and ask the model and the effort as two questions. When a question still has more than 3 options, list the 3 most likely and name the rest in the question, so the user can pick one through "Other". If the tool is unavailable or refused, ask in plain text with numbered options and end the turn. In `codex exec`, accept as-is and say so. For panel roles (arena runners, architect runners, interrogate reviewers) the value is a list, and one subagent runs per entry, alias entries included, so the list length sets the count. `arena cross-judge pool` is also a list, but Arena runs one judge. It tries only values from a model other than the parent's, in list order, so order it by preference. An `inherit-parent` or `auto` value never judges. `swarm workers` is the default model for every worker unless a race or comparison assigns another model per arm.

### 4. Validate

Every real slug written must be in the detected set. `inherit-parent` and `auto` always pass. If a chosen real slug is not available, stop and ask again.

### 5. Write the block

Write the block into the target file from step 2, and create `~/.codex/AGENTS.md` when neither file exists. The block is the two markers around the comment lines, a `# budget` line with the chosen label and its target effort, and one line per role, using the same labels poteto-mode uses. Replace only the text between `<!-- pstack-models:begin -->` and `<!-- pstack-models:end -->`, or append the block at the end of the file when it is missing, so re-runs stay idempotent. Never touch the rest of the file. Never write to `~/.codex/rules/`, which holds exec-policy rules. Shape:

```
<!-- pstack-models:begin -->
# pstack model configuration. One line per role. Delete a line to fall back to the skill default.
# A value is `<model> <effort>`: `spawn_agent` `model` and `reasoning_effort`.
# `inherit-parent` or `auto` as a value: the role runs on the session model (omit `spawn_agent` `model`). Alias entries in a panel list still count toward its fan-out.
# budget: large (xhigh)
feature, refactoring: inherit-parent
bug-fix: inherit-parent
perf-issue: inherit-parent
hillclimb: inherit-parent
judgment and prose: gpt-6-astra xhigh
hardest tasks: gpt-6-astra xhigh
how explorer: inherit-parent
how explainer: gpt-6-astra xhigh
why investigators: inherit-parent
why synthesizer: gpt-6-astra xhigh
reflect tooling: inherit-parent
reflect judgment, divergent, synthesizer: gpt-6-astra xhigh
arena runners: gpt-6-astra xhigh, gpt-6.1-sol xhigh
arena cross-judge pool: gpt-6-astra xhigh, gpt-6.1-sol xhigh
swarm workers: inherit-parent
architect runners: gpt-6-astra xhigh, gpt-6.1-sol xhigh
interrogate reviewers: gpt-6-astra xhigh, gpt-6.1-sol xhigh
<!-- pstack-models:end -->
```

### 6. Confirm

Tell the user the block was written and that it applies to new Codex sessions. Re-running this skill updates it. `~/.codex` is outside the workspace sandbox, so the write asks for approval to escalate. If the write is refused, for example in `codex exec`, do not route around the sandbox. Print the full block, markers included, and tell the user to paste it into `~/.codex/AGENTS.md`, or into `~/.codex/AGENTS.override.md` when that file exists, replacing any older block.

### 7. Offer a verification skill (optional)

Check whether the project has a way to drive the real app for proof (a `verify-*` skill, or an existing harness). If not, offer once: "want a project-local verification skill, so agents can drive the app the way a user does and prove changes work? I can generate one with $pstack:create-verification-skill." On yes, read `<pstack>/skills/create-verification-skill/SKILL.md` and follow it. On no, move on without pushing.

### 8. Offer a formal verification skill (optional)

Check whether the project already has a formal verification skill (a project skill that runs a model checker, a proof, or another verifier against the code). If not, offer once: "want a formal verification skill, so agents can prove a key property of your code holds in every case in scope, not only the cases tests reach? I can generate one with $pstack:create-formal-verification-skill." On yes, read `<pstack>/skills/create-formal-verification-skill/SKILL.md` and follow it. On no, move on without pushing.
