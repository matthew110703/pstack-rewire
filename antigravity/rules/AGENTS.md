# pstack dynamic model routing & fallback rule

When `pstack` skills or `/poteto-mode` playbooks spawn subagents via `invoke_subagent`, they resolve each role's model tier from `.agents/rules/pstack-models.md` (workspace override) or `~/.gemini/config/pstack-models.md` (user override), falling back to the defaults below.

## Dynamic Fallback Protocol (`pro` -> `inherit` / `flash` -> `flash_lite`)

In Antigravity environments where `pro` models are removed or unavailable, or where the parent session model (such as Gemini 4 Argon) is strictly quota-limited, `pstack` uses dynamic model fallback:

1. **`pro` fallback**: When a role requests `pro` and `pro` is unavailable or rejected by `invoke_subagent`, automatically fall back to `inherit` for judgment, synthesis, and hardest tasks, or to `flash` for parallel runners and code delegates so parent quota is preserved.
2. **Quota conservation (`flash` & `flash_lite`)**: High-fanout roles (`how explorer`, `why investigators`, `swarm workers`, `reflect tooling`, transcript slice miners) default to `flash` (falling back to `flash_lite`) so parallel subagents do not exhaust the parent session's Argon quota.
3. **`inherit` / `auto`**: Runs the subagent on the parent conversation's selected model (`Model: "inherit"`).
4. **Multi-agent diversity on a single model tier**: When a panel role (`arena runners`, `architect runners`, `interrogate reviewers`) runs multiple subagents that resolve to the same model tier (such as two `flash` runners or `inherit` + `flash`), differentiate them by assigning distinct structural priors or adversarial lenses in their `Prompt` and `Role` arguments.

## Antigravity Subagent Execution & Reactive Wakeup Rules

1. **Reactive Wakeup (Never Poll After `invoke_subagent`)**: Subagents run asynchronously and automatically resume your turn when they complete. Once you have launched all subagents for the current wave, **immediately end your turn (call no more tools)**. Never call `schedule(...)` or `manage_subagents(Action: "list")` in a loop to wait for a freshly spawned subagent.
2. **Read-Only Subagents from Nested Agents (`poteto-explorer` vs `research`)**: Built-in `TypeName: "research"` is available to the root session agent, whereas custom subagents defined via `define_subagent` cannot invoke `TypeName: "research"` or pass `Name: "research"` to `define_subagent`. When running inside a nested subagent (`poteto-agent`), or if `invoke_subagent(TypeName: "research")` returns a not-found/not-allowed error, immediately call `define_subagent(Name: "poteto-explorer", Description: "Read-only exploration and review subagent", SystemPrompt: "You are a read-only exploration and review subagent. Do not modify files.", EnableWriteTools: false, EnableMCPTools: false, EnableSubagentTools: false)` and invoke `TypeName: "poteto-explorer"`.

## Default Role Mapping

```text
# budget: large (dynamic pro -> inherit/flash fallback)
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
arena cross-judge pool: pro -> inherit, flash
swarm workers: flash
architect runners: pro -> inherit, flash
interrogate reviewers: pro -> inherit, flash
```
