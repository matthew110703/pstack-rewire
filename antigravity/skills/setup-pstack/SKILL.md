---
name: setup-pstack
description: Configure which models pstack uses per role and at what reasoning budget. Detects your available Antigravity subagent models and writes an always-applied rule that overrides the skill defaults. Use for /setup-pstack, "configure pstack models", "pstack budget", or changing pstack's model choices.
---

# Setup pstack

Write `.agents/rules/pstack-models.md` (workspace-scoped) or `~/.gemini/config/pstack-models.md` (user-scoped), a rule that sets pstack's model per role and dynamic fallback chain.

## Steps

### 1. Detect available models

Inspect the `Model` enum of `invoke_subagent` (`inherit`, `pro`, `flash`, `flash_lite`) and the user's current environment:
- Note that in Antigravity environments where `pro` models are disabled or unavailable and the parent model (`inherit`, e.g., Gemini 4 Argon) is rate-limited, pstack uses **dynamic fallback chains** written as `pro -> inherit -> flash` (or `pro -> flash`) so high-reasoning roles automatically fall back without failing.
- Never write a model value without a valid fallback if `pro` is unavailable in the environment. `inherit`, `flash`, and `flash_lite` are always valid.

### 2. Load current state

The default role-to-model mapping is the rule shape shown in step 5 below. If `.agents/rules/pstack-models.md` or `~/.gemini/config/pstack-models.md` already exists, read it and treat its `# budget` line and its role values as the current choices. Otherwise start from those defaults. A line whose role is not in step 5, such as `how critics`, is from a retired role. Drop it.

### 3. Budget, map, and confirm

**(a) Ask for a budget.** Use the `ask_question` tool (`Prefer ask_question over free text`). Offer these four options with these exact labels, and name the current budget when the rule records one. With no rule, say that `large` matches the skill defaults and conserves rate-limited parent (`inherit` / Argon) quota by running high-fanout/code workers on `flash` and judgment/synthesis on `pro -> inherit -> flash`.

- `(Recommended) large — xhigh reasoning (flash for code/fanout, pro -> inherit -> flash for judgment)`
- `unlimited — max reasoning (pro -> inherit -> flash across all primary roles)`
- `medium — high reasoning (flash for most roles, inherit -> flash for synthesis/hardest tasks)`
- `small — medium reasoning (flash across roles, flash_lite for explorers/parsing)`

**(b) Apply it.** Build the working table from the skill defaults, and on a re-run keep any role the user explicitly customized:
- `unlimited`: sets code and judgment roles to `pro -> inherit -> flash`, keeping high-volume explorers/swarm on `flash` unless requested otherwise.
- `large` (default): sets code/implementation/explorer/swarm roles (`feature, refactoring`, `bug-fix`, `perf-issue`, `hillclimb`, `how explorer`, `why investigators`, `reflect tooling`, `swarm workers`) to `flash`, and judgment/synthesis/hardest roles (`judgment and prose`, `hardest tasks`, `how explainer`, `why synthesizer`, `reflect judgment, divergent, synthesizer`) to `pro -> inherit -> flash`. Panel roles (`arena runners`, `architect runners`, `interrogate reviewers`) use `pro -> inherit, flash`.
- `medium`: sets all roles to `flash` except `judgment and prose`, `hardest tasks`, `how explainer`, `why synthesizer`, which use `inherit -> flash`. Panel roles use `inherit -> flash, flash`.
- `small`: sets `how explorer`, `why investigators`, and `reflect tooling` to `flash_lite`, and all other roles to `flash`. Panel roles use `flash, flash` (with distinct structural priors per runner).

**(c) Show the roles and confirm.** Show every role with its model/fallback chain, plus each retired line step 2 dropped. Ask via `ask_question` whether to accept as-is or change specific roles, and whether to save to the workspace (`.agents/rules/pstack-models.md`) or globally (`~/.gemini/config/pstack-models.md`). For panel roles (`arena runners`, `architect runners`, `interrogate reviewers`) the value is a comma-separated list, and one subagent runs per entry, so the list length sets the count. When multiple panel entries resolve to the same model tier (e.g., both resolve to `flash`), pstack assigns distinct structural priors / adversarial lenses to each runner. `arena cross-judge pool` is also a list, and Arena picks a tier different from the primary runner where possible. `swarm workers` is the default model for every worker unless a race or comparison assigns another model per arm.

### 4. Validate

Every entry must resolve to a valid `invoke_subagent` `Model` value (`pro`, `inherit`, `flash`, `flash_lite`) or a `->` fallback chain of them.

### 5. Write the rule

Write `.agents/rules/pstack-models.md` (or `~/.gemini/config/pstack-models.md`) with a `# budget` line and one line per role, using the same labels `poteto-mode` uses. Overwrite the whole file so re-runs stay idempotent. Shape:

```markdown
---
description: pstack per-role model choices and dynamic fallback chain (overrides skill defaults)
---
# pstack model configuration for Antigravity. One line per role. Delete a line to fall back to the skill default.
# Values map to invoke_subagent `Model` ("pro", "inherit", "flash", "flash_lite").
# A `->` chain (e.g. `pro -> inherit -> flash`) tries the left tier first and falls back dynamically when `pro` is unavailable or `inherit` (e.g. Argon) is rate-limited.
# Panel lists (arena, architect, interrogate) spawn one subagent per comma-separated entry.
# budget: large (xhigh)
feature, refactoring: flash
bug-fix: flash
perf-issue: flash
hillclimb: flash
judgment and prose: pro -> inherit -> flash
hardest tasks: pro -> inherit -> flash
how explorer: flash
how explainer: pro -> inherit -> flash
why investigators: flash
why synthesizer: pro -> inherit -> flash
reflect tooling: flash
reflect judgment, divergent, synthesizer: pro -> inherit -> flash
arena runners: pro -> inherit, flash
arena cross-judge pool: flash, pro -> inherit
swarm workers: flash
architect runners: pro -> inherit, flash
interrogate reviewers: pro -> inherit, flash
```

### 6. Confirm

Tell the user the rule was written and that pstack skills will read it automatically. Re-running `/setup-pstack` updates it.

### 7. Offer a verification skill (optional)

Check whether the project has a way to drive the real app for proof (a `.agents/skills/verify-*/SKILL.md` skill, or an existing harness). If not, offer once: "want a project-local verification skill, so agents can drive the app the way a user does and prove changes work? I can generate one with `/create-verification-skill`." On yes, invoke `/create-verification-skill`. On no, move on without pushing.

### 8. Offer a formal verification skill (optional)

Check whether the project already has a formal verification skill (a project skill that runs a model checker, a proof, or another verifier against the code). If not, offer once: "want a formal verification skill, so agents can prove a key property of your code holds in every case in scope, not only the cases tests reach? I can generate one with `/create-formal-verification-skill`." On yes, invoke `/create-formal-verification-skill`. On no, move on without pushing.
