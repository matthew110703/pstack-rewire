# Set up pstack

In this page you install the plugin, pick which models pstack uses, and run your first task. Setup is one command plus a short conversation.

## Install the plugin

Install `pstack` globally into `~/.gemini/config/plugins/pstack` with a single zero-clone command:

- **Windows (PowerShell):**
  ```powershell
  irm https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/install.ps1 | iex
  ```
- **macOS / Linux:**
  ```bash
  curl -fsSL https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/install.sh | bash
  ```

See the [Antigravity harness reference](../harness/antigravity.md) for the full architecture and tool mapping.

## Pick your models

Run:

```text
/setup-pstack
```

[`/setup-pstack`](../../skills/setup-pstack/SKILL.md) checks your subagent model tiers (`pro`, `inherit`, `flash`, `flash_lite`), asks for a reasoning budget via `ask_question`, shows you each role (code delegates, judgment, the review panels), and asks what you want. Answer the questions. It writes `.agents/rules/pstack-models.md` (or `~/.gemini/config/pstack-models.md`), a rule every pstack skill reads.

Because `pro` models may be unavailable in your current Antigravity setup and the parent model (`inherit`, e.g., Gemini 4 Argon) is rate-limited, pstack uses **dynamic fallback chains** (`pro -> inherit -> flash`):
- `large` (default) puts high-fanout/code workers on `flash` to conserve parent quota, and puts judgment/synthesis/hardest tasks on `pro -> inherit -> flash`.
- `unlimited` puts primary code and judgment roles on `pro -> inherit -> flash`.
- `medium` and `small` shift more roles to `flash` and `flash_lite` to spend even less quota.

You only override what you care about. A role with no line in the rule keeps the skill's default. To restore a default, delete that role's line. For a panel role (`arena runners`, `architect runners`, `interrogate reviewers`) the value is a comma-separated list, and one subagent runs per entry, so the list length sets the panel size. When multiple runners resolve to the same model tier, pstack assigns distinct structural priors or adversarial lenses to each runner. Setup also configures `swarm workers`, the default model for every `/swarm` worker unless a race names a model for each arm.

## Accept the verification offers, or don't

At the end of setup, `/setup-pstack` looks for a way to prove app behavior in your project, either a `verify-*` skill or an existing harness. If it finds neither, it offers once to generate one with [`/create-verification-skill`](../../skills/create-verification-skill/SKILL.md).

Say yes and it writes `.agents/skills/verify-<app>/`, a project-local skill that teaches agents to drive your app the way a user does. It proves the skill works once before handing it over. Say no and setup moves on. You can run `/create-verification-skill` yourself any time. [Verify and ship](./06-verify-and-ship.md#create-a-project-verification-skill) covers it in depth.

If you're new to pstack, say yes. An agent that can check its own work keeps going until the check passes. An agent that can't hands every result back to you to check by hand. Of everything in this guide, the verification skill pays off the most.

Then setup offers once to generate a formal verification skill with [`/create-formal-verification-skill`](../../skills/create-formal-verification-skill/SKILL.md), unless the project already has one. Tests check the cases someone thought to write. A formal verification skill checks one key property of your code, such as "a job never runs twice at once", in every case within a stated scope. Say yes when your code has concurrency, retries, a state machine, or a parser, where a bug is costly and tests rarely reach the case that breaks. Otherwise say no, and run it later if that changes. [Verify and ship](./06-verify-and-ship.md#prove-a-property-with-a-formal-verification-skill) covers it.

## Keep quota and cost in check

pstack spends extra tokens on subagents and review panels. That's the price of the rigor. To spend fewer:

- Rerun `/setup-pstack` and pick `large`, `medium`, or `small` so high-volume code/explorer/swarm roles run on `flash` or `flash_lite`.
- Shorten a panel list. Each entry runs one subagent.
- Save `/poteto-mode` for work that needs rigor. A small, obvious edit doesn't.

## Run your first task

Pick something real but small, and describe it the way you'd describe it to a colleague:

```text
/poteto-mode add a --json flag to this command. text output stays byte-identical. verify both.
```

Watch the todo list. Its first items are the matched playbook's steps copied in, the Feature playbook for this prompt. If `/poteto-mode` skips a step, the step stays in the list with `skip: <reason>`, so you can see what it chose not to do.

Next: [Route work through `/poteto-mode`](./02-poteto-mode.md).
