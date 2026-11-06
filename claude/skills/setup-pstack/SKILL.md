---
name: setup-pstack
description: Configure which models pstack uses per role and at what reasoning budget. Detects your available models and writes an always-applied rule that overrides the skill defaults. Use for /pstack:setup-pstack, "configure pstack models", "pstack budget", or changing pstack's model choices.
---

# Setup pstack

`<pstack>` is the pstack plugin root, `${CLAUDE_PLUGIN_ROOT}` (two folders above this file when that is not expanded). To run another pstack skill or `/pstack:<name>`, read `<pstack>/skills/<name>/SKILL.md` and follow it. The Skill tool refuses pstack skills.

Write `~/.claude/rules/pstack-models.md`, an always-applied rule that sets pstack's model per role.

## Steps

### 1. Detect available models

Enumerate the model slugs you can pass to an `Agent` subagent in this session. The `Agent` tool schema is the dependable source. Each `model` value it lists, with each of its `effort` values, is one detected slug, written `<model> <effort>`, such as `opus xhigh`. If you cannot detect any, ask the user to paste the slugs they have access to. Never write a real slug you have not confirmed is available. The aliases `inherit-parent` and `auto` are always valid even though they are not detected slugs.

### 2. Load current state

The default role-to-model mapping is the rule shape shown in step 5 below. If `~/.claude/rules/pstack-models.md` already exists, read it and treat its `# budget` line and its role values as the current choices. Otherwise start from those defaults. A line whose role is not in step 5, such as `how critics`, is from a retired role. Drop it.

### 3. Budget, map, and confirm

**(a) Ask for a budget.** Prefer AskUserQuestion over free text. Offer these four options with these exact labels, and name the current budget when the rule records one. With no rule, say that `large` matches the skill defaults.

- `unlimited — max reasoning`
- `large — xhigh reasoning`
- `medium — high reasoning`
- `small — medium reasoning`

**(b) Apply it.** Build the working table from the skill defaults, and on a re-run keep any role you changed by family, list, or alias (`inherit-parent`, `auto`). `unlimited`, `large`, `medium`, and `small` set the effort token of every real slug, panel entries included, to `max`, `xhigh`, `high`, or `medium`. The effort token is the last token, on the ladder `max` > `xhigh` > `high` > `medium` > `low`. If the result is not a detected slug, use the same family's detected slug with the highest effort at or below the target, else mark the role as needing a choice. `inherit-parent` and `auto` do not change. So `unlimited` turns `opus xhigh` into `opus max`. `large` keeps the defaults. `small` turns `opus xhigh` into `opus medium`.

**(c) Show the roles and confirm.** Show every role with its model, marking any real slug not in the detected set as needing a choice. Also list each line step 2 dropped. Ask whether to accept as-is or change specific roles, offering the detected models plus `inherit-parent` and `auto` (both mean: this role runs on the session model set by `/model`) as the options. Prefer AskUserQuestion over free text. It takes at most 4 options per question, so offer `inherit-parent` and `auto` as one option, and ask the model and the effort as two questions. When a question still has more than 4 options, list the 4 most likely and name the rest in the question, so the user can pick one through "Other". For panel roles (arena runners, architect runners, interrogate reviewers) the value is a list, and one subagent runs per entry, alias entries included, so the list length sets the count. `arena cross-judge pool` is also a list, but Arena runs one judge. It tries only values from a family other than the parent's, in list order, so order it by preference. An `inherit-parent` or `auto` value never judges. `swarm workers` is the default model for every worker unless a race or comparison assigns another model per arm.

### 4. Validate

Every real slug written must be in the detected set. `inherit-parent` and `auto` always pass. If a chosen real slug is not available, stop and ask again.

### 5. Write the rule

Write `~/.claude/rules/pstack-models.md` with no frontmatter, since Claude Code loads every `.md` file in `~/.claude/rules/` into each new session. Then write the comment lines, a `# budget` line with the chosen label and its target effort, and one line per role, using the same labels poteto-mode uses. Overwrite the whole file so re-runs stay idempotent. Never put the role lines in `CLAUDE.md` or `AGENTS.md`. Shape:

```
# pstack model configuration. One line per role. Delete a line to fall back to the skill default.
# `inherit-parent` or `auto` as a value: the role runs on the session model (omit Agent `model`). Alias entries in a panel list still count toward its fan-out.
# budget: large (xhigh)
feature, refactoring: inherit-parent
bug-fix: inherit-parent
perf-issue: inherit-parent
hillclimb: inherit-parent
judgment and prose: opus xhigh
hardest tasks: opus xhigh
how explorer: inherit-parent
how explainer: opus xhigh
why investigators: inherit-parent
why synthesizer: opus xhigh
reflect tooling: inherit-parent
reflect judgment, divergent, synthesizer: opus xhigh
arena runners: opus xhigh, sonnet xhigh
arena cross-judge pool: opus xhigh, sonnet xhigh
swarm workers: inherit-parent
architect runners: opus xhigh, sonnet xhigh
interrogate reviewers: opus xhigh, sonnet xhigh
```

### 6. Confirm

Tell the user the rule was written and that it applies to new sessions. Re-running this skill updates it. Claude Code guards files under `~/.claude`, so the write asks for approval. If the write is refused, for example in `claude -p`, do not route around the guard. Show the full file content and tell the user to save it as `~/.claude/rules/pstack-models.md`, or to rerun with the write allowed, for example `claude --allowedTools "Edit(~/.claude/rules/**)"` in the default permission mode. `--permission-mode acceptEdits` still refuses `~/.claude`.

### 7. Offer a verification skill (optional)

Check whether the project has a way to drive the real app for proof (a `verify-*` skill, or an existing harness). If not, offer once: "want a project-local verification skill, so agents can drive the app the way a user does and prove changes work? I can generate one with /pstack:create-verification-skill." On yes, read `<pstack>/skills/create-verification-skill/SKILL.md` and follow it. On no, move on without pushing.

### 8. Offer a formal verification skill (optional)

Check whether the project already has a formal verification skill (a project skill that runs a model checker, a proof, or another verifier against the code). If not, offer once: "want a formal verification skill, so agents can prove a key property of your code holds in every case in scope, not only the cases tests reach? I can generate one with /pstack:create-formal-verification-skill." On yes, read `<pstack>/skills/create-formal-verification-skill/SKILL.md` and follow it. On no, move on without pushing.
