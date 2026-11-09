# Set up pstack

In this page you install the skills, pick which models pstack uses, and run your first task. Setup is one command plus a short conversation.

## Install the skills

From your project root, run:

```text
curl -fsSL https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/install.sh | bash -s -- --target default --scope workspace
```

The installer copies the skills into `.agents/skills/`. Drop `--scope workspace` to choose a user install in `~/.agents/skills/` instead. You can also run `npx skills add https://github.com/matthew110703/pstack-rewire/tree/main/default/skills`, or copy the folders under `skills/` by hand. To update later, rerun the installer with `--update`. To remove pstack, run `uninstall.sh --target default`.

pstack also needs `gh`, and `bun` or `node` for the `watch-pr` and `statechart` scripts.

Start a fresh agent session and confirm it lists the pstack skills. Invoke a skill the way your agent does, such as `$setup-pstack` in Codex or `/setup-pstack` in Gemini CLI, GitHub Copilot, or OpenCode, or ask for it by name. This guide writes `/name`. The [port notes](../harness/default.md) list each capability pstack uses and its fallback.

## Pick your models

Run:

```text
/setup-pstack
```

[`/setup-pstack`](../../skills/setup-pstack/SKILL.md) detects the models you have access to, asks for a reasoning budget, shows you each role (code delegates, judgment, the review panels), and asks what you want. Answer the questions. It writes `~/.agents/pstack-models.md`, a small file every pstack skill reads before each spawn.

Every role defaults to `inherit`, the model your session runs on, so the budget changes nothing until a role names a model. Once it does, `large` sets its effort to `xhigh`. `unlimited` lifts each model to its highest effort, up to `max`. `medium` and `small` lower the effort and spend fewer tokens.

You only override what you care about. A role with no line in the file keeps the skill's default. To restore a default, delete that role's line. A rerun of `/setup-pstack` keeps any role whose model differs from the default. When a default changes, a file written before the change still pins the old default, so delete those role lines, or delete the file, then run `/setup-pstack` again.

You might be wondering how to keep a role on your session model. Set a role to `inherit`, `inherit-parent`, or `auto` and pstack omits the subagent's model, so the subagent inherits your session model. All three mean the same thing, and none is a model id. On one model there is no cross-family judge, so the arena judge is a fresh-context subagent on the same model, and pstack says so. For a panel role the value is a list, and one subagent runs per entry, so the list length sets the panel size. Setup also configures `swarm workers`, the default model for every `/swarm` worker unless a race names a model for each arm.

## Accept the verification offers, or don't

At the end of setup, `/setup-pstack` looks for a way to prove app behavior in your project, either a `verify-*` skill or an existing harness. If it finds neither, it offers once to generate one with [`/create-verification-skill`](../../skills/create-verification-skill/SKILL.md).

Say yes and it writes `.agents/skills/verify-<app>/`, a project-local skill that teaches agents to drive your app the way a user does. It proves the skill works once before handing it over. Say no and setup moves on. You can run `/create-verification-skill` yourself any time. [Verify and ship](./06-verify-and-ship.md#create-a-project-verification-skill) covers it in depth.

If you're new to pstack, say yes. An agent that can check its own work keeps going until the check passes. An agent that can't hands every result back to you to check by hand. Of everything in this guide, the verification skill pays off the most.

Then setup offers once to generate a formal verification skill with [`/create-formal-verification-skill`](../../skills/create-formal-verification-skill/SKILL.md), unless the project already has one. Tests check the cases someone thought to write. A formal verification skill checks one key property of your code, such as "a job never runs twice at once", in every case within a stated scope. Say yes when your code has concurrency, retries, a state machine, or a parser, where a bug is costly and tests rarely reach the case that breaks. Otherwise say no, and run it later if that changes. [Verify and ship](./06-verify-and-ship.md#prove-a-property-with-a-formal-verification-skill) covers it.

After setup, start a new session. To help agents find the model file, accept setup's offer to add a one-line pointer to your project's `AGENTS.md`.

## Keep the cost in check

pstack spends extra tokens on subagents and review panels. That's the price of the rigor. To spend fewer:

- Rerun `/setup-pstack` and pick a smaller reasoning budget or cheaper models. A strong model in the main session with cheaper, faster models in the code roles is a good split.
- Set a role to `auto` or `inherit-parent` so it runs on the session's own model.
- Shorten a panel list. Each entry runs one subagent.
- Save `/poteto-mode` for work that needs rigor. A small, obvious edit doesn't.

## Run your first task

Pick something real but small, and describe it the way you'd describe it to a colleague:

```text
/poteto-mode add a --json flag to this command. text output stays byte-identical. verify both.
```

Watch the todo list. Its first items are the matched playbook's steps copied in, the Feature playbook for this prompt. If `/poteto-mode` skips a step, the step stays in the list with `skip: <reason>`, so you can see what it chose not to do.

From here you can type normal follow-ups. Most agents keep an invoked skill in context on every turn until the session compacts. After compaction, or in a new session, invoke `/poteto-mode` again. To keep it on in every session, add a pointer such as `use the poteto-mode skill for any non-trivial task.` to your project's `AGENTS.md`.

Next: [Route work through `/poteto-mode`](./02-poteto-mode.md).
