# pstack in Codex: port notes

This copy is a native Codex port of pstack v0.15.36. Every skill, playbook, principle, agent and script from the Cursor plugin is here. Only harness primitives changed. This file lists every mapping. The facts were checked against Codex CLI 0.167.0 on 2026-11-06.

## `<pstack>` and running skills

`<pstack>` is the plugin root, two folders above a skill's `SKILL.md`. Codex shows each skill's file path, so the path is known. When it is not, `ls -d ~/.codex/plugins/cache/*/pstack/*/ | sort -V | tail -1` finds the newest installed copy. A workspace install puts the skills in `.agents/skills/`, and the same rule then gives `.agents/`.

Every pstack skill except `setup-pstack` ships `agents/openai.yaml` with `policy.allow_implicit_invocation: false`. That is the Codex form of Cursor's `disable-model-invocation: true`. The model never picks those skills on its own. To run another pstack skill, a skill reads `<pstack>/skills/<name>/SKILL.md` and follows it. Users type `$pstack:<name>` (plugin install) or `$<name>` (workspace install).

## Long skills

Codex injects only about the first 7,900 characters of an invoked skill and reports "Skill `pstack:<name>` exceeded the main prompt context limit and was truncated". Raising `skills.max_context_tokens` does not change that. Every SKILL.md over 7,000 bytes therefore starts, right under its title, with "This SKILL.md is longer than the part Codex injects. Before acting, read this whole file from the path Codex shows for it, then follow all of it." `tools/ports/codex-long-skills.mjs` adds the line, and `tools/ports/validate.mjs` checks it.

## Tools

| Cursor | Codex |
| --- | --- |
| `Task` | `spawn_agent` (see Subagent fields) |
| `AskQuestion` | `request_user_input`: 1 to 3 questions, each with `header`, `id`, `question`, and 2 or 3 `options` of `label` and `description`. Codex adds "Other". Keep every original choice reachable by merging or splitting. If the tool is unavailable or refused, ask in plain text with numbered options and end the turn. In `codex exec`, take the default and say so. |
| Open a todolist | `update_plan` when the session has it. Otherwise write the list as a markdown checklist in the first message and repeat it, updated, at the top of the final reply. |
| Run another pstack skill | Read `<pstack>/skills/<name>/SKILL.md` and follow it. |
| `Shell` | `exec_command` (and `write_stdin` for interactive input) |
| `Read`, `Write`, `StrReplace` | Read with `exec_command` (`sed -n`, `cat`); edit with `apply_patch` |
| `Grep`, `Glob` | `exec_command` with `rg` |
| `/loop` | No `/loop`. Inside a turn: check, `clock.sleep` (or `sleep` in `exec_command`) in bounded chunks, check again. A goal that spans turns: `create_goal` (only when the user asked for one). A recurring check: a Scheduled task in the ChatGPT desktop app. |
| Plan Mode | Codex Plan mode (`/plan`, or Shift+Tab) |
| `create-skill` | The built-in `$skill-creator`, else the Authoring a skill playbook |
| `/deslop` (`cursor-team-kit`) | An inline code-slop pass on the diff: remove narrating comments, guards for states that cannot happen, dead compatibility code, and unrelated edits. Then the **unslop** skill on prose. |
| `control-ui` (`cursor-team-kit`) | The project's `verify-<app>` skill, else chrome-devtools MCP (`codex mcp add chrome-devtools -- npx chrome-devtools-mcp@latest`) |
| `control-cli` (`cursor-team-kit`) | The project's `verify-<app>` skill, else `exec_command` with `write_stdin`, or tmux |
| `/visualize` | A Mermaid or ASCII diagram, or a chart rendered to a file whose path you give |
| Image generation tool | `image_gen__imagegen` |
| Built-in PR tool | `gh pr create` (omit `--draft` when the step says not draft) |
| Cursor's built-in babysit skill | None. Use the Babysit playbook. |

## Subagent fields

Codex 0.167 with `gpt-6.1-sol` or `gpt-6-astra` exposes the `collaboration` tools: `spawn_agent`, `wait_agent`, `send_message`, `followup_task`, `interrupt_agent`, `list_agents`. `gpt-6-luna` has none, so a session on luna does the work inline.

| Cursor | Codex |
| --- | --- |
| A `Task` call | `spawn_agent{task_name, message, agent_type?, model?, reasoning_effort?, fork_turns?}`. `task_name` is a short kebab-case label. Put the whole brief in `message`, with absolute paths. Use `fork_turns: "none"` for a fresh agent, the default for pstack. |
| Wait for results | `wait_agent{timeout_ms}` returns mailbox updates. A timeout means still running, not done, so wait again or do other work. |
| `run_in_background: true` | Omit. Spawns run in the background. |
| `subagent_type: "generalPurpose"`, `readonly: false` | `agent_type: "worker"` |
| `readonly: true` | `agent_type: "explorer"`. Codex has no read-only sandbox per agent, so the brief also says "do not edit files", and you check `git status` after it returns. |
| `poteto-agent`, `comment-sicko` | `agent_type: "poteto-agent"`, `"comment-sicko"`, the TOML agents the installer puts in `~/.codex/agents/`. `agent_type` appears only when a custom agent is installed. Without them, use `worker` and start the brief with "Read `<pstack>/agents/<name>.md` in full and act as that agent." |
| `environment: "cloud"` | Subagents share your checkout. Tell the worker to create its own worktree first: `git worktree add <repo>/.pstack/worktrees/<slug> -b <branch> <base>`, and to use that absolute path for every command and edit. `.codex/` is read-only in the sandbox, so never put worktrees there. |
| `environment: "local"` | Omit. |
| `cloud_base_branch: <b>` | The `<base>` above. |
| resume, steer, or queue a follow-up | `followup_task{target, message}` starts a turn on an idle agent. `send_message{target, message}` queues without a turn. |
| Stop an agent | `interrupt_agent{target}` |
| `file_attachments` | List the paths in `message`. |
| Nested spawns | A subagent can spawn its own. Older multi-agent v1 models stop at `agents.max_depth` (default 1) with "Agent depth limit reached. Solve the task yourself." Then do the work inline and keep reviewer separation. |

## Models

| Cursor | Codex |
| --- | --- |
| `claude-opus-5-5-xhigh` (prose, judgment, hardest tasks) | `gpt-6-astra xhigh`: `model: "gpt-6-astra"`, `reasoning_effort: "xhigh"` |
| `grok-4.7-xhigh-fast` (code delegates, explorers, swarm workers) | `inherit-parent`: omit `model`. setup-pstack offers `gpt-6.1-terra` as the fast code model. |
| Panels: `arena runners`, `arena cross-judge pool`, `architect runners`, `interrogate reviewers` | `gpt-6-astra xhigh, gpt-6.1-sol xhigh`. A family is a model slug, so each panel keeps two families and a judge from another family exists for either parent. |
| Effort ladder | `low < medium < high < xhigh < max < ultra`. `unlimited` means `max`. Never set `ultra`, which spawns its own parallel agents. `gpt-6-luna` tops out at `max`. |
| `-fast` slugs and fast mode | Drop. |
| Slug rejected | A role value must be a slug in `~/.codex/models_cache.json` with `visibility: "list"`. Otherwise omit `model` and say so. |
| `auto` or `inherit-parent` | Omit `model`. |
| `~/.cursor/rules/pstack-models.mdc` | The `pstack-models` block in `~/.codex/AGENTS.md`, or in `~/.codex/AGENTS.override.md` when that file exists. The block sits between `<!-- pstack-models:begin -->` and `<!-- pstack-models:end -->`. Codex loads the global AGENTS.md into every session, so the role lines are in context. If they are not, read the file. |

## setup-pstack

- Detect: read `~/.codex/models_cache.json`. Each model with `visibility: "list"` and each of its `supported_reasoning_levels[].effort` values is a detected slug, written `<model> <effort>`.
- Write: replace only the text between the two markers, or append the block when it is missing. Never touch the rest of the file. Never write to `~/.codex/rules/`, which holds exec-policy rules.

## Paths

| Cursor | Codex |
| --- | --- |
| `.cursor/skills/`, `~/.cursor/skills/` | `.agents/skills/`, `~/.agents/skills/` |
| `~/.cursor/plugins/`, `.cursor-plugin/plugin.json` | `~/.codex/plugins/cache/<marketplace>/<plugin>/<version>/`, `.codex-plugin/plugin.json` |
| `.cursor/rules/*.mdc`, always-applied rules, "agent instruction file" | `AGENTS.md` (repo), `~/.codex/AGENTS.md` (global) |
| `.cursor/worktrees/` | `$CODEX_HOME/worktrees/` (app chats) and `<repo>/.pstack/worktrees/` (pstack workers) |
| `github.com/cursor/plugins/.../pstack/<path>` | The local file under `<pstack>/` |
| Transcripts in `~/.cursor/projects/<slug>/agent-transcripts/` | `~/.codex/sessions/YYYY/MM/DD/rollout-<timestamp>-<id>.jsonl`. Older ones may be `.jsonl.zst` (read with `zstdcat`). Each line is `{timestamp, type, payload}`. The first `session_meta` line has `id`, `cwd`, and, for subagents, `parent_thread_id`. Select this workspace's sessions by `payload.cwd`. The current session's id is `$CODEX_THREAD_ID` in any command. Messages are `response_item` payloads (`role`, `content[].text`). A skill run shows as a user message with `$pstack:<name>` or a read of its `SKILL.md`. |
| Agent store, Cursor Project, Project tracker | Repo-local `.pstack/<run>/` (gitignored unless a step commits it). Resume a chat with `codex resume`. |
| `~/Library/Application Support/Cursor` | `~/.codex/sessions`, `~/.codex/archived_sessions`, `~/.codex/worktrees`, `~/.codex/plugins/cache` |

## Sandbox

`--sandbox workspace-write` makes `.git` and `.codex` read-only. Commits fail with `Operation not permitted` on `.git/index.lock`. Interactive Codex asks to escalate. For headless runs, add `.git` as a writable root: `-c 'sandbox_workspace_write.writable_roots=["<repo>/.git"]'`. pstack workers put worktrees in `.pstack/worktrees/`, not `.codex/`.

## MCP

Codex lists MCP tools as `mcp__<server>__<tool>`. Some load lazily, so search with `tool_search` first. Authenticate with `codex mcp login <server>`.

## Bugbot and review bots

Bugbot comments on a GitHub PR are ordinary review threads, so triage them with `gh`. `watch-pr` also counts Codex's GitHub review (`chatgpt-codex-connector`) as review automation. Skip a step that starts or configures Bugbot when the PR has no Bugbot check.

## benny

benny runs as two ChatGPT Scheduled tasks with Slack channel-message triggers (ChatGPT web, eligible plans). Each task invokes the committed operational file for triage or repro. The shared pstack skills are vendored into the target repo's `.agents/skills/`. The worker agents `benny-reader` and `benny-coder` go into `.codex/agents/`. See `automations/benny/`.

## Residual skips

Use one line, `Skipped in Codex: <step>. <reason>.`, then continue. That covers Cursor cloud-agent dashboards and machines, Bugbot steps on a PR without Bugbot, and webhook-triggered routines (no Codex API trigger).
