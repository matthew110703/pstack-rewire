# pstack for any agent: port notes

This copy is a harness-neutral port of pstack v0.15.36. It uses only open standards:

- [Agent Skills](https://agentskills.io/specification) `SKILL.md` folders, installed into `.agents/skills/` (project) or `~/.agents/skills/` (user).
- `AGENTS.md` for always-on instructions.
- The [agent-plugins.org](https://agent-plugins.org/) `plugin.json`.

Agents that read `.agents/skills/` include Codex, Gemini CLI, GitHub Copilot, Cursor, OpenCode, Amp, Goose, Junie, Roo, Windsurf, and Factory. Every skill, playbook, principle, agent, and script from the Cursor plugin is here. Only harness primitives changed.

## `<skills>` and running skills

Skills install flat, so `<skills>` is the folder that holds this skill's folder (one above this `SKILL.md`). To run another pstack skill, read `<skills>/<name>/SKILL.md` and follow it. Users invoke a skill the way their agent does (for example `/name`, `$name`, or by asking for it by name).

## Capabilities

Agents differ, so skills name a capability and give a fallback. The fallback is always part of the workflow.

| Capability | Use it when your agent has it | Otherwise |
| --- | --- | --- |
| Spawn a subagent | Your agent's subagent or task tool. Give it the full brief with absolute paths. | Do the work inline, one brief at a time, and keep reviewer separation by re-reading the brief fresh before each role. |
| Read-only subagent | A read-only or explorer agent type. | A normal subagent whose brief says "do not edit files". Check `git status` after it returns. |
| Background subagent | Run it in the background and keep working. | Run it, then continue. |
| Message a running subagent | Your agent's send or follow-up tool. | A fresh subagent with the earlier brief and report pasted in. |
| Isolated worktree | Your agent's worktree option. | The worker runs `git worktree add <repo>/.pstack/worktrees/<slug> -b <branch> <base>` and uses that absolute path for every command and edit. |
| Ask the user | Your agent's structured-question tool. Keep every original choice reachable. | Ask in plain text with numbered options and end the turn. When nobody can answer (a headless run), take the default and say so. |
| Plan list | Your agent's todo or plan tool. | A markdown checklist in the first message, repeated, updated, at the top of the final reply. |
| Repeat until a check passes | Your agent's loop or scheduling feature. | Inside a turn: check, sleep in bounded chunks, check again. |
| Schedule or trigger a run | Your platform's scheduler, cron, or CI. | Run it by hand. |
| Image generation | Your agent's image tool. | A Mermaid or ASCII diagram. |
| Browser or app control | The project's `verify-<app>` skill, else a browser MCP such as chrome-devtools. | A CLI driven through the shell, or tmux. |

## Subagent fields

| Cursor | pstack for any agent |
| --- | --- |
| `Task` | Spawn a subagent. |
| `subagent_type: "generalPurpose"`, `readonly: false` | A general subagent that can edit. |
| `readonly: true` | A read-only subagent. |
| `poteto-agent` | A general subagent whose brief starts "Read `<skills>/poteto-mode/agents/poteto-agent.md` in full and act as that agent." |
| `comment-sicko` | A general subagent whose brief starts "Read `<skills>/no-comments/agents/comment-sicko.md` in full and act as that agent." |
| `environment: "cloud"` | An isolated worktree. |
| `environment: "local"` | Omit. |
| `cloud_base_branch: <b>` | The worktree's base. |
| `run_in_background: true` | A background subagent. |
| `resume` | Message a running subagent. |
| `file_attachments` | List the paths in the brief. |

## Models

Every role defaults to `inherit`, the model your session runs on. Run `setup-pstack` to give roles other models your agent can spawn.

| Cursor | pstack for any agent |
| --- | --- |
| `claude-opus-5-5-xhigh`, `grok-4.7-xhigh-fast` | `inherit` |
| A role value `<model> <effort>` | Pass the model and effort your subagent tool accepts. A value it rejects means omit the model and say so. |
| Panels (`arena runners`, `arena cross-judge pool`, `architect runners`, `interrogate reviewers`) | `inherit, inherit`. A family is a distinct model id. On one model there is no cross-family judge, so the arena judge is a fresh-context subagent on the same model, and you say so. |
| `pstack-models.mdc` | `~/.agents/pstack-models.md`, a file pstack owns. Read it before each spawn. When it is missing, use the defaults. |

## Paths

| Cursor | pstack for any agent |
| --- | --- |
| `.cursor/skills/`, `~/.cursor/skills/` | `.agents/skills/`, `~/.agents/skills/` |
| `~/.cursor/plugins/`, `.cursor-plugin/plugin.json` | `.agents/skills/` (pstack installs flat), `plugin.json` |
| `.cursor/rules/*.mdc`, always-applied rules | `AGENTS.md` |
| `.cursor/worktrees/` | `<repo>/.pstack/worktrees/` |
| `github.com/cursor/plugins/.../pstack/<path>` | `https://github.com/matthew110703/pstack-rewire/blob/main/default/<path>` |
| Transcripts | If your agent stores session transcripts, read this workspace's, newest first. If it does not, say so and skip the step. |
| Agent store, Cursor Project | Repo-local `.pstack/<run>/`. |

## Cursor-only features

Cursor Automations, Bugbot, cloud agents, `cursor-team-kit`, and Cursor's built-in skills have no standard form. Each maps to a capability above, or is skipped with one line, `Skipped in this agent: <step>. <reason>.`, before moving to the next step.

| Cursor | pstack for any agent |
| --- | --- |
| `/deslop` | An inline code-slop pass: remove narrating comments, guards for states that cannot happen, dead compatibility code, and unrelated edits. Then the **unslop** skill. |
| `create-skill` | Your agent's skill-authoring helper if it has one, else the Authoring a skill playbook. |
| `/visualize` | Mermaid or ASCII. |
| Bugbot | GitHub review threads, read through `gh`. |
| Built-in PR tool | `gh pr create`. |
| benny's Cursor Automations | Trigger the triage and repro instructions with your platform's scheduler, a Slack bot, or CI. Otherwise run them by hand. |
