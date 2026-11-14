---
name: setup-pstack
description: Configure which models pstack uses per role and at what reasoning budget. Detects your available Antigravity subagent tiers, live concrete models, and quotas, then writes an always-applied rule with multi-hop fallbacks that overrides the skill defaults. Use for /setup-pstack, "configure pstack models", "pstack budget", or changing pstack's model choices.
---

# Setup pstack

Write `.agents/rules/pstack-models.md` (workspace-scoped) or `~/.gemini/config/pstack-models.md` (user-scoped), a rule that sets pstack's model per role and universal multi-hop fallback chains across both `invoke_subagent` / `run_workflow` tiers and native `swarm` concrete slugs.

## Steps

### 1. Detect available models and live quotas

1. **Subagent & workflow tier enum**: Inspect the `Model` enum of `invoke_subagent` (`inherit`, `pro`, `flash`, `flash_lite`). Note that `run_workflow` `agent(model=...)` uses the same four tier values.
2. **Concrete model roster & live quotas**: Call `swarm{action: "models", all: true}` (read-only; does not create a swarm) to inspect the live `models` list, `display_names`, and `quotas` (`quota_remaining` and `quota_resets`) across all Antigravity model families:
   - **Orchestrator Mode**: `gemini-pro-orchestrator-g1-pro` (*Orchestrator (Argon)* — Argon plan/review + Hydrogen execute)
   - **Gemini 4 Argon / Carbon**: `gemini-4-argon-{high,medium,low}`
   - **Gemini 4 Hydrogen**: `gemini-4-hydrogen-{xhigh,high,medium,low}`
   - **Gemini 3.8 Flash**: `gemini-3.8-flash-{high,medium,low}`
   - **Claude 5.5**: `claude-opus-5-5-{high,medium,low}`, `claude-sonnet-5-5-{high,medium,low}`
   - **Open-Weight**: `gpt-oss-120b-medium`
3. **Always require fallbacks**: Never write a single bare model slug or `"pro"` without a `->` fallback chain ending in always-available tiers (`inherit`, `flash`, or `flash_lite`). If `swarm{action: "models", all: true}` is unavailable in the current environment or shows `0%` quota on a family, automatically mark its next hop in the fallback chain as active and inform the user.

### 2. Load current state

The default role-to-model mapping is the rule shape shown in step 5 below. If `.agents/rules/pstack-models.md` or `~/.gemini/config/pstack-models.md` already exists, read it and treat its `# budget` line, role values, and `@swarm` lines as the current choices. Otherwise start from those defaults. A line whose role is not in step 5, such as `how critics`, is from a retired role. Drop it. Upgrade any legacy bare role value (such as bare `pro` or bare `flash`) to include its multi-hop fallback chain.

### 3. Budget, map, and confirm

First, print a compact summary table of the detected model families and their live `quota_remaining` / `quota_resets` from step 1.

**(a) Ask for a budget.** Use the `ask_question` tool (`Prefer ask_question over free text`). Offer these four options with these exact labels, and name the current budget when the rule records one. With no rule, say that `large` matches the skill defaults and conserves rate-limited parent (`inherit` / Argon) quota while guaranteeing multi-hop fallbacks on every role:

- `(Recommended) large — xhigh reasoning (flash -> inherit -> flash_lite for code/fanout, pro -> inherit -> flash -> flash_lite for judgment)`
- `unlimited — max reasoning (pro -> inherit -> flash -> flash_lite across primary code and judgment roles)`
- `medium — high reasoning (flash -> inherit -> flash_lite for code/fanout, inherit -> flash -> flash_lite for synthesis/hardest tasks)`
- `small — medium reasoning (flash_lite -> flash -> inherit for explorers/parsing, flash -> flash_lite -> inherit for code/judgment)`

**(b) Apply it.** Build the working table from the skill defaults, and on a re-run keep any role the user explicitly customized:
- `unlimited`: sets primary code and judgment roles (`feature, refactoring`, `bug-fix`, `perf-issue`, `hillclimb`, `judgment and prose`, `hardest tasks`, `how explainer`, `why synthesizer`, `reflect judgment, divergent, synthesizer`) to `pro -> inherit -> flash -> flash_lite`, keeping high-volume explorers/swarm on `flash -> inherit -> flash_lite` unless requested otherwise. `@swarm` concrete chains prioritize `gemini-4-argon-high`, `claude-opus-5-5-high`, and `gemini-4-hydrogen-xhigh`.
- `large` (default): sets code/implementation/swarm roles (`feature, refactoring`, `bug-fix`, `perf-issue`, `hillclimb`, `swarm workers`) to `flash -> inherit -> flash_lite`, explorers/investigators/tooling (`how explorer`, `why investigators`, `reflect tooling`) to `flash -> flash_lite -> inherit`, and judgment/synthesis/hardest roles (`judgment and prose`, `hardest tasks`, `how explainer`, `why synthesizer`, `reflect judgment, divergent, synthesizer`) to `pro -> inherit -> flash -> flash_lite`. Panel roles (`arena runners`, `architect runners`, `interrogate reviewers`) use `pro -> inherit -> flash, flash -> inherit -> flash_lite`.
- `medium`: sets code/workers to `flash -> inherit -> flash_lite`, explorers/tooling to `flash -> flash_lite -> inherit`, and judgment/synthesis/hardest roles to `inherit -> flash -> flash_lite`. Panel roles use `inherit -> flash, flash -> inherit -> flash_lite`. `@swarm` concrete chains step down to `high`/`medium` effort (`gemini-4-hydrogen-high`, `claude-sonnet-5-5-high`, `gemini-4-argon-medium`).
- `small`: sets `how explorer`, `why investigators`, and `reflect tooling` to `flash_lite -> flash -> inherit`, and all other roles to `flash -> flash_lite -> inherit`. Panel roles use `flash -> flash_lite, flash -> inherit` (with distinct structural priors per runner). `@swarm` concrete chains prioritize `gemini-3.8-flash-high`, `gemini-4-hydrogen-medium`, and `gpt-oss-120b-medium`.

**(c) Show the roles and confirm.** Show every role with its multi-hop fallback chain (plus the `@swarm` concrete cross-family chains and any retired line step 2 dropped). Ask via `ask_question` whether to accept as-is or change specific roles (including pinning concrete slugs from `swarm{action: "models", all: true}` for native `swarm` panels), and whether to save to the workspace (`.agents/rules/pstack-models.md`) or globally (`~/.gemini/config/pstack-models.md`). For panel roles (`arena runners`, `architect runners`, `interrogate reviewers`) the value is a comma-separated list, and one subagent runs per entry, so the list length sets the count. When multiple panel entries resolve to the same tier after fallback (e.g., both resolve to `flash` or `inherit`), pstack assigns distinct structural priors / adversarial lenses to each runner. `arena cross-judge pool` is also a list, and Arena picks a tier or family different from the primary runner where possible. `swarm workers` is the default model for every worker unless a race or comparison assigns another model per arm.

### 4. Validate

- Every tier chain entry must consist solely of valid `invoke_subagent` `Model` values (`pro`, `inherit`, `flash`, `flash_lite`) joined by `->`, and must end with an always-valid fallback (`inherit`, `flash`, or `flash_lite`).
- Every `@swarm` concrete fallback chain entry must use slugs confirmed in `swarm{action: "models", all: true}` (or known effort variants) and end with `inherit`. If a requested concrete slug is missing or has `0%` quota, confirm that an available, non-zero-quota fallback exists in the chain before it reaches `inherit`.

### 5. Write the rule

Write `.agents/rules/pstack-models.md` (or `~/.gemini/config/pstack-models.md`) with a `# budget` line, one line per role using the same labels `poteto-mode` uses, and `@swarm` concrete model fallback chains. Overwrite the whole file so re-runs stay idempotent. Shape:

```markdown
---
description: pstack per-role model choices, live concrete swarm chains, and multi-hop fallbacks (overrides skill defaults)
---
# pstack model configuration for Antigravity. One line per role. Delete a line to fall back to the skill default.
# Tier values map to invoke_subagent / run_workflow `Model` ("pro", "inherit", "flash", "flash_lite").
# A `->` chain tries left-to-right and automatically falls back when any tier or concrete model is unavailable, rejected, or out of quota.
# Panel lists (arena, architect, interrogate) spawn one subagent per comma-separated entry.
# budget: large (xhigh)
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
@swarm frontier: gemini-4-argon-high -> claude-opus-5-5-high -> gemini-4-hydrogen-xhigh -> gemini-4-argon-medium -> claude-sonnet-5-5-high -> gemini-3.8-flash-high -> inherit
@swarm code: gemini-4-hydrogen-xhigh -> gemini-4-hydrogen-high -> claude-sonnet-5-5-high -> gemini-3.8-flash-high -> gemini-4-hydrogen-medium -> gpt-oss-120b-medium -> inherit
@swarm panel-seat-1: gemini-4-argon-high -> gemini-4-hydrogen-xhigh -> gemini-4-hydrogen-high -> gemini-3.8-flash-high -> inherit
@swarm panel-seat-2: claude-opus-5-5-high -> claude-sonnet-5-5-high -> gpt-oss-120b-medium -> gemini-4-hydrogen-high -> gemini-3.8-flash-high -> inherit
```

### 6. Confirm

Tell the user the rule was written and that pstack skills will read it automatically. Re-running `/setup-pstack` updates it.

### 7. Offer a verification skill (optional)

Check whether the project has a way to drive the real app for proof (a `.agents/skills/verify-*/SKILL.md` skill, or an existing harness). If not, offer once: "want a project-local verification skill, so agents can drive the app the way a user does and prove changes work? I can generate one with `/create-verification-skill`." On yes, invoke `/create-verification-skill`. On no, move on without pushing.

### 8. Offer a formal verification skill (optional)

Check whether the project already has a formal verification skill (a project skill that runs a model checker, a proof, or another verifier against the code). If not, offer once: "want a formal verification skill, so agents can prove a key property of your code holds in every case in scope, not only the cases tests reach? I can generate one with `/create-formal-verification-skill`." On yes, invoke `/create-formal-verification-skill`. On no, move on without pushing.
