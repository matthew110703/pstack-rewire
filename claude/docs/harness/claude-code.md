# pstack in Claude Code: port notes

This copy is a native Claude Code port of pstack v0.15.36. Upstream ships a runtime adapter that maps Cursor names at read time. This port applies those mappings statically in every file, so no skill needs this page at run time. It records how each Cursor name maps, for maintainers and for anyone diffing against upstream. `<pstack>` means the plugin root, `${CLAUDE_PLUGIN_ROOT}`, the folder that holds `skills/` and `docs/`.

## Tools

| Cursor | Claude Code |
| --- | --- |
| `Task` | `Agent` |
| `AskQuestion` | `AskUserQuestion`, with 1 to 4 questions, 2 to 4 options each, and `multiSelect` for multiple selection. The user can always pick "Other". A longer list is merged or split so every choice stays reachable. In `-p` mode it is absent, so ask in plain text. |
| Open a todolist | `TodoWrite` or `TaskCreate`, whichever the session has. `claude -p` has neither, so keep the list as a checklist at the top of each reply. |
| Run another pstack skill (`/name` or "the **name** skill") | `Read` `<pstack>/skills/<name>/SKILL.md` and follow it. Every pstack skill has `disable-model-invocation: true`, so the `Skill` tool refuses it. Text addressed to the user says `/pstack:<name>`. |
| `Grep`, `Glob` | The same, or `Bash` with `rg`. |
| `/deslop` (cursor-team-kit) | The built-in `/simplify` on changed code, then the **unslop** skill on prose. |
| `control-ui`, `control-cli` (cursor-team-kit) | The project's `verify-<app>` skill when present. Otherwise chrome-devtools MCP or claude-in-chrome for browser and Electron UIs, and `Bash` or tmux for CLIs and TUIs. |
| `/create-skill`, create-skill | The `skill-creator` skill when installed, otherwise poteto-mode's Authoring or modifying a skill playbook. |
| `/visualize`, the image-generation tool | A Mermaid or ASCII diagram, or a chart or image rendered to a file whose path you give. |
| Cursor's built-in PR tool | `gh pr create`, without `--draft` when the step says not draft. |
| Cursor's `/loop` | Claude Code's `/loop`. "until X" becomes a self-paced `/loop` with a check that stops when it passes. It is session-scoped. |
| Plan Mode | Claude Code plan mode (Shift+Tab). |

## Subagent fields

| Cursor | Claude Code |
| --- | --- |
| `subagent_type: generalPurpose` | `subagent_type: "general-purpose"` |
| `poteto-agent`, `comment-sicko` | `pstack:poteto-agent`, `pstack:comment-sicko` |
| `readonly: true` | `subagent_type: "Explore"`. It keeps `Bash`, so the brief also says "do not edit files", and you check `git status` afterward. |
| `readonly: false`, agent mode | `general-purpose`. It keeps the session's MCP tools. |
| `environment: "cloud"` | `isolation: "worktree"`. Name the branch or commit the worker checks out. |
| `environment: "local"` | Omit. |
| `cloud_base_branch: <b>` | Tell the worker to check out `<b>` first. |
| `run_in_background: true`, `is_background` | Omit on calls. Subagents run in the background and notify you when they finish. Agent frontmatter uses `background: true`. |
| Resume, steer, or message a running agent | `SendMessage`. Stop is `TaskStop`. |
| `file_attachments` | List the paths in the brief. |

## Models

| Cursor | Claude Code |
| --- | --- |
| `claude-<family>-<version>-<effort>[-fast]`, such as `claude-opus-5-5-xhigh` | `model: "opus"` and `effort: "xhigh"`. `model` takes only `opus`, `sonnet`, `haiku`, `fable`. `effort` takes `low`, `medium`, `high`, `xhigh`, `max`. |
| Reasoning level and fast or standard speed | The `effort` param. Fast mode is a session toggle (`/fast`), so no spawn sets it. |
| `grok-*`, `gpt-*`, `composer-*`, or another non-Claude slug | Omit `model` so the agent runs on the session model. The default code roles are `inherit-parent`. |
| `auto`, `inherit-parent`, the Auto model picker | Omit `model`. The session model is the one `/model` sets. |
| "Different model family" | A family is a Claude alias. A judge or verifier uses a different alias from the parent or author. |
| A rejected slug, "closest valid slug from the error" | The value must be one of the four aliases. Otherwise omit `model` and say so. |
| `~/.cursor/rules/pstack-models.mdc` | `~/.claude/rules/pstack-models.md`. Claude Code loads it into every new session. |
| A role value `<model> <effort>`, such as `opus high` | `model: "opus"` and `effort: "high"`. |

## setup-pstack

- Detect. The detected models are the `model` values the `Agent` tool schema lists, each with an effort from its `effort` values. A real model is written as `<alias> <effort>`, such as `opus xhigh`. The effort is the last token, so the budget ladder edits it as written.
- Defaults. `claude-opus-5-5-xhigh` is `opus xhigh`, and `grok-4.7-xhigh-fast` is `inherit-parent`, except in the multi-model panels (`arena runners`, `arena cross-judge pool`, `architect runners`, `interrogate reviewers`). There the Grok seat is `sonnet xhigh`, so each panel keeps two families and an `opus` parent always has a cross-family judge.
- Write. `~/.claude/rules/pstack-models.md` with no frontmatter, then the comment lines, the `# budget` line, and one line per role. It overwrites the whole file and never touches `CLAUDE.md` or `AGENTS.md`.
- The verification handoff tells the user to run `/pstack:create-verification-skill`, or reads that skill by path.

## Paths

| Cursor | Claude Code |
| --- | --- |
| `.cursor/skills/`, `~/.cursor/skills/` | `.claude/skills/`, `~/.claude/skills/` |
| `~/.cursor/plugins/` | `~/.claude/plugins/cache/`, versioned folders. An update replaces them, so never edit there. Copy a skill to `.claude/skills/<name>/` (it runs as `/<name>`) or fork the marketplace. |
| `.cursor-plugin/plugin.json` | `.claude-plugin/plugin.json` |
| `.cursor/worktrees` | `.claude/worktrees` |
| `.cursor/rules/*.mdc`, always-applied rules, the agent instruction file | `CLAUDE.md`, or `AGENTS.md` when no `CLAUDE.md` exists. Plugins cannot ship rules. The model rule is the exception. See Models. |
| `.cursor/automations/benny/`, `.cursor/benny/` | `.claude/automations/benny/`, `.claude/benny/` |
| `github.com/cursor/plugins/.../pstack/<path>` links | Relative links to the local file. |
| Cursor app data dirs | `~/.claude/projects`, `~/.claude/plugins/cache`, `~/.claude/file-history`, `~/.claude/shell-snapshots` |

## Transcripts

- Location. `~/.claude/projects/<slug>/<session-id>.jsonl`. `<slug>` is the absolute workspace path with every `/` and `.` changed to `-`, so `/Users/you/proj` is `-Users-you-proj`. The newest `.jsonl` directly in that folder is the current session. `<session-id>/subagents/*.jsonl` holds subagent transcripts. A session started inside a worktree has its own slug.
- The system prompt names no transcripts folder. Derive the path from the cwd.
- Schema. Each line is a JSON event with `type` user, assistant, system, summary, and others. Message text is in `message.content`, a string or an array of `text`, `tool_use`, and `tool_result` blocks. A skill run shows up as a `Skill` tool_use or a user turn with `<command-name>/pstack:x</command-name>`, not as a `Read` of SKILL.md. pstack skills never sit in the model's skill catalog.

## MCP

- Tools are `mcp__<server>__<tool>`. Many are deferred and load through ToolSearch (`select:<name>`) before use.
- Auth uses that server's `mcp__<server>__authenticate` tool or `/mcp`.
- Cursor's `mcps/` folder and available-tools map become the session's tool list and deferred-tool list.

## External dependencies

- `gh` stays the default forge CLI. The Origin CLI stays the optional branch.
- `bun` or `node` runs the `watch-pr`, `check-plan`, and `statechart` scripts. `bootstrap.ts` installs `node_modules` next to the scripts in the plugin cache, so it reinstalls once after each plugin update.
- chrome-devtools MCP covers CDP traces, eval, heap snapshots, and screencasts.
- Bugbot is a GitHub app, so its comments are ordinary review threads read through `gh`. `watch-pr` keeps the Bugbot and `cursor` login detection and also counts `claude-review` / `claude code review` checks as review automation.

## State and UI

| Cursor | Claude Code |
| --- | --- |
| Agent store (path in the system prompt), Project tracker, Project store | Repo-local `.pstack/<run>/`, gitignored unless the step commits it. |
| PR and CI event subscriptions | `watch-pr` or `gh` run as background `Bash` or Monitor, which notify on exit. |
| Cloud agent, its VM, its own machine | A worktree-isolated subagent with its own port. "The VM dies" is "the session dies". |
| Cursor Project, one coordinator thread | A long-lived coordinator session resumed with `claude --resume`, worktree subagents, notes in `.pstack/<program>/`, and an optional `/schedule` routine as heartbeat. |
| Custom Mode, Option+Enter | An invoked skill stays in context until compaction. Re-invoke `/pstack:poteto-mode` after compaction or in a new session. |
| Pinned chats, the sidebar | Ask the user, or use recent sessions by mtime. |
| Restart Cursor | Restart Claude Code. |
| Cursor Memories | Claude Code memory, `CLAUDE.md`. |
| cursor.com docs links | `https://code.claude.com/docs/en/<page>` |

## The `<pstack>` convention

Every SKILL.md that runs another pstack skill carries this line under its title:

`` `<pstack>` is the pstack plugin root, `${CLAUDE_PLUGIN_ROOT}` (two folders above this file when that is not expanded). To run another pstack skill or `/pstack:<name>`, read `<pstack>/skills/<name>/SKILL.md` and follow it. The Skill tool refuses pstack skills. ``

Reference files, playbooks, and subagent prompts do not carry it. Where one briefs a subagent with no context, the parent substitutes the absolute path.

## benny

The classification, dedupe, gates, markers, double repro, bounded fix, fail-closed rules, and worker Slack ban are unchanged. Only the wiring changed.

- Two routines, `benny-triage` and `benny-reproduce`, each with an API trigger. A Slack Workflow Builder workflow fires on each new top-level message in the source channel and POSTs `{source_channel_id, message_ts}` to both `/fire` endpoints. The bearer tokens live in Slack workflow secrets, never in the repo. The body is the run's immutable trigger. A duplicate fire for the same `message_ts` is a no-op.
- Routines do not install marketplace plugins. Setup vendors the shared skills (`how`, `why`, `tdd`, `unslop`, the principles benny lists, and `poteto-mode`, which `how` and `why` read) into the target repo at `.claude/skills/<name>/` and records the source version. Project `.claude/settings.json` gets `extraKnownMarketplaces` and `enabledPlugins: {"pstack@pstack-rewire": true}` for local sessions. A fresh `claude` session in a clean clone, then a disabled test routine's run, lists the resolved skills in place of the fresh-agent check.
- Setup creates each routine through the `schedule` skill, one at a time, disabled. The user reviews, wires the Slack workflow, then enables. Existing routines are updated, never duplicated.
- Slack and the tracker go through routine connectors. `prefer_cursor_actions` is `prefer_connector_actions`. Draft PRs use `gh pr create --draft`. `BENNY_SLACK_BOT_TOKEN` is a cloud-environment secret. Workers get no Slack tools, and the coordinator is the only poster.
- In-run waits stay in one run, with sleeps between connector polls. A run that would pass the routine time limit fails closed.
- Setup checks that the routine environment can drive the app headless (chrome-devtools MCP) before it enables repro, and fails closed otherwise.

## make-bot-ui

- The `schedule` skill creates a routine with an API trigger, in place of the `update_state` routine call.
- The user copies the routine's bearer token into the bot server's own secret store, in place of the `SendToUser` secret card.
- The server POSTs to the routine's `/fire` URL with `Authorization: Bearer <token>` and the beta header, in place of the `api2.cursor.sh` webhook and `X-Automation-Key`.
- The routine prompt receives the POST body as its input text. The claude.ai routines page replaces the Cursor routines panel.

## Residual skips

When a step needs a Cursor-only thing, the skill writes `Skipped in Claude Code: <step>. <reason>.` and goes on.

- Bugbot start, wait, and configure steps when the PR has no Bugbot check or comment.
- Cursor cloud agent dashboards and status pages.
