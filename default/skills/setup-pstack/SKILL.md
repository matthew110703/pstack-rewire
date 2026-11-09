---
name: setup-pstack
description: Configure which models pstack uses per role and at what reasoning budget. Detects your available models and writes a pstack-owned file that overrides the skill defaults. Use for /setup-pstack, "configure pstack models", "pstack budget", or changing pstack's model choices.
---

# Setup pstack

`<skills>` is the folder that holds this skill's folder, one above this SKILL.md. To run another pstack skill, read `<skills>/<name>/SKILL.md` and follow it.

Write `~/.agents/pstack-models.md`, a file pstack owns that sets pstack's model per role. pstack skills read it before each spawn.

## Steps

### 1. Detect available models

Ask the user for the model ids your agent can pass to a subagent, plus the effort values it accepts if it supports effort. If your agent exposes a model list (a models command, a tool schema, or a config file), read it instead and confirm it with the user. Write each detected slug as `<model> <effort>`, or `<model>` when your agent takes no effort. Never write a real slug you have not confirmed is available. The aliases `inherit`, `inherit-parent`, and `auto` are always valid even though they are not detected slugs.

### 2. Load current state

The default role-to-model mapping is the file shape shown in step 5 below. If `~/.agents/pstack-models.md` already exists, read it and treat its `# budget` line and its role values as the current choices. Otherwise start from those defaults. A line whose role is not in step 5, such as `how critics`, is from a retired role. Drop it.

### 3. Budget, map, and confirm

**(a) Ask for a budget.** Ask with your agent's structured-question tool, else in plain text with numbered options, and end the turn. In a headless run, take `large` and say so. Offer these four options with these exact labels, and name the current budget when the file records one. With no file, say that `large` matches the skill defaults. If the tool caps options below four, split the question so every option stays reachable.

- `unlimited — max reasoning`
- `large — xhigh reasoning`
- `medium — high reasoning`
- `small — medium reasoning`

**(b) Apply it.** Build the working table from the skill defaults, and on a re-run keep any role you changed by family, list, or alias (`inherit`, `inherit-parent`, `auto`). `unlimited`, `large`, `medium`, and `small` set the effort token of every real slug, panel entries included, to `max`, `xhigh`, `high`, or `medium`. The effort token is the last token, on the ladder `max` > `xhigh` > `high` > `medium` > `low`. A slug with no effort token does not change. If the result is not a detected slug, use the same family's detected slug with the highest effort at or below the target, else mark the role as needing a choice. Aliases do not change. So `unlimited` turns `<model> xhigh` into `<model> max`, and `small` turns it into `<model> medium`. The defaults are all `inherit`, so the budget changes nothing until a role names a model.

**(c) Show the roles and confirm.** Show every role with its model, marking any real slug not in the detected set as needing a choice. Also list each line step 2 dropped. Ask whether to accept as-is or change specific roles, offering the detected models plus `inherit` (this role runs on the session model, as do `inherit-parent` and `auto`) as the options. Ask with the structured-question tool, else plain-text numbered options. Keep every choice reachable. If the tool caps options, ask the model and the effort as two questions, and name the rest in the question so the user can still pick one. For panel roles (arena runners, architect runners, interrogate reviewers) the value is a list, and one subagent runs per entry, alias entries included, so the list length sets the count. `arena cross-judge pool` is also a list, but Arena runs one judge. It tries only values from a family other than the parent's, in list order, so order it by preference. An alias value never counts as another family. `swarm workers` is the default model for every worker unless a race or comparison assigns another model per arm.

### 4. Validate

Every real slug written must be in the detected set. `inherit`, `inherit-parent`, and `auto` always pass. If a chosen real slug is not available, stop and ask again.

### 5. Write the file

Write `~/.agents/pstack-models.md` with no frontmatter: the comment lines, a `# budget` line with the chosen label and its target effort, and one line per role, using the same labels poteto-mode uses. Overwrite the whole file so re-runs stay idempotent. pstack owns this file, so put nothing else in it. Shape:

```
# pstack model configuration. One line per role. Delete a line to fall back to the skill default.
# `inherit`, `inherit-parent`, or `auto` as a value: the role runs on the session model (omit the subagent's model). Alias entries in a panel list still count toward its fan-out.
# budget: large (xhigh)
feature, refactoring: inherit
bug-fix: inherit
perf-issue: inherit
hillclimb: inherit
judgment and prose: inherit
hardest tasks: inherit
how explorer: inherit
how explainer: inherit
why investigators: inherit
why synthesizer: inherit
reflect tooling: inherit
reflect judgment, divergent, synthesizer: inherit
arena runners: inherit, inherit
arena cross-judge pool: inherit, inherit
swarm workers: inherit
architect runners: inherit, inherit
interrogate reviewers: inherit, inherit
```

### 6. Confirm

Tell the user the file was written and that pstack reads it before each spawn. Re-running this skill updates it. Offer once to add one line to the project's `AGENTS.md`, `pstack model roles: ~/.agents/pstack-models.md`, so agents find the file. Add it only on yes, and never put the role lines in `AGENTS.md`.

### 7. Offer a verification skill (optional)

Check whether the project has a way to drive the real app for proof (a `verify-*` skill, or an existing harness). If not, offer once: "want a project-local verification skill, so agents can drive the app the way a user does and prove changes work? I can generate one with the create-verification-skill skill." On yes, read `<skills>/create-verification-skill/SKILL.md` and follow it. On no, move on without pushing.

### 8. Offer a formal verification skill (optional)

Check whether the project already has a formal verification skill (a project skill that runs a model checker, a proof, or another verifier against the code). If not, offer once: "want a formal verification skill, so agents can prove a key property of your code holds in every case in scope, not only the cases tests reach? I can generate one with the create-formal-verification-skill skill." On yes, read `<skills>/create-formal-verification-skill/SKILL.md` and follow it. On no, move on without pushing.
