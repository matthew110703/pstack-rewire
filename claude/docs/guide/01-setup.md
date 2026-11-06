# Set up pstack

In this page you install the plugin, pick which models pstack uses, and run your first task. Setup is one command plus a short conversation.

## Install the plugin

In a Claude Code session, run:

```text
/plugin marketplace add matthew110703/pstack-rewire
/plugin install pstack@pstack-rewire
```

Claude Code confirms the plugin is installed. From a terminal, run `claude plugin marketplace add matthew110703/pstack-rewire && claude plugin install pstack@pstack-rewire` instead, or `./install.sh --target claude` (`./install.ps1 -Target claude` on Windows) from a checkout of this repo.

To update later, run `claude plugin marketplace update pstack-rewire && claude plugin update pstack@pstack-rewire`, or rerun the installer with `--update`, then restart Claude Code or run `/reload-plugins`. To turn on auto-update, run `/plugin`, open **Marketplaces**, select `pstack-rewire`, and enable auto-update.

pstack also needs `gh`, and `bun` or `node` for the `watch-pr` and `statechart` scripts.

Claude Code namespaces plugin commands, so every command is `/pstack:<name>`. The [port notes](../harness/claude-code.md) list how each Cursor name maps.

## Pick your models

Run:

```text
/pstack:setup-pstack
```

[`/pstack:setup-pstack`](../../skills/setup-pstack/SKILL.md) detects the models you have access to, asks for a reasoning budget, shows you each role (code delegates, judgment, the review panels), and asks what you want. Answer the questions. It writes `~/.claude/rules/pstack-models.md`, a small rule every pstack skill reads.

The defaults run at `xhigh` effort, the same as the `large` budget. `unlimited` lifts each model to its highest effort, up to `max`. Opus goes to `max`. `medium` and `small` lower the effort and spend fewer tokens.

You only override what you care about. A role with no line in the rule keeps the skill's default. To restore a default, delete that role's line. A rerun of `/pstack:setup-pstack` keeps any role whose model differs from the default. When a default changes, a rule written before the change still pins the old default, so delete those role lines, or delete the file, then run `/pstack:setup-pstack` again.

You might be wondering how to keep a role on your session model, the one `/model` sets. Set a role to `inherit-parent` or `auto` and pstack omits the subagent `model` field, so the subagent inherits your session model. Both values mean the same thing, and neither is a model. The default code roles already use `inherit-parent`. For a panel role the value is a list, and one subagent runs per entry, so the list length sets the panel size. Setup also configures `swarm workers`, the default model for every `/pstack:swarm` worker unless a race names a model for each arm.

## Accept the verification offers, or don't

At the end of setup, `/pstack:setup-pstack` looks for a way to prove app behavior in your project, either a `verify-*` skill or an existing harness. If it finds neither, it offers once to generate one with [`/pstack:create-verification-skill`](../../skills/create-verification-skill/SKILL.md).

Say yes and it writes `.claude/skills/verify-<app>/`, a project-local skill that teaches agents to drive your app the way a user does. It proves the skill works once before handing it over. Say no and setup moves on. You can run `/pstack:create-verification-skill` yourself any time. [Verify and ship](./06-verify-and-ship.md#create-a-project-verification-skill) covers it in depth.

If you're new to pstack, say yes. An agent that can check its own work keeps going until the check passes. An agent that can't hands every result back to you to check by hand. Of everything in this guide, the verification skill pays off the most.

Then setup offers once to generate a formal verification skill with [`/pstack:create-formal-verification-skill`](../../skills/create-formal-verification-skill/SKILL.md), unless the project already has one. Tests check the cases someone thought to write. A formal verification skill checks one key property of your code, such as "a job never runs twice at once", in every case within a stated scope. Say yes when your code has concurrency, retries, a state machine, or a parser, where a bug is costly and tests rarely reach the case that breaks. Otherwise say no, and run it later if that changes. [Verify and ship](./06-verify-and-ship.md#prove-a-property-with-a-formal-verification-skill) covers it.

After setup, start a new session. The model rule applies to new sessions.

## Keep the cost in check

pstack spends extra tokens on subagents and review panels. That's the price of the rigor. To spend fewer:

- Rerun `/pstack:setup-pstack` and pick a smaller reasoning budget or cheaper models. A strong model in the main session with cheaper, faster models such as `sonnet` or `haiku` in the code roles is a good split.
- Set a role to `auto` or `inherit-parent` so it runs on the session's own model.
- Shorten a panel list. Each entry runs one subagent.
- Save `/pstack:poteto-mode` for work that needs rigor. A small, obvious edit doesn't.

## Run your first task

Pick something real but small, and describe it the way you'd describe it to a colleague:

```text
/pstack:poteto-mode add a --json flag to this command. text output stays byte-identical. verify both.
```

Watch the todo list. Its first items are the matched playbook's steps copied in, the Feature playbook for this prompt. If `/pstack:poteto-mode` skips a step, the step stays in the list with `skip: <reason>`, so you can see what it chose not to do.

From here you can type normal follow-ups. `/pstack:poteto-mode` stays on for the whole session. In Claude Code an invoked [skill](https://code.claude.com/docs/en/skills) stays in context on every turn until the session compacts. After compaction, or in a new session, invoke `/pstack:poteto-mode` again.

Next: [Route work through `/pstack:poteto-mode`](./02-poteto-mode.md).
