---
name: setup-benny
description: Configure Benny and prepare its triage and repro Scheduled tasks. Use when installing Benny or changing its Slack, tracker, repository, routing, control, model, or budget settings.
---

# Set up Benny

pstack's shared skills are vendored in the target repository at `.agents/skills/<name>/` by section 1. To run one, read `.agents/skills/<name>/SKILL.md` and follow it. Before section 1 runs, read it from the installed plugin instead, `<pstack>/skills/<name>/SKILL.md`, where `<pstack>` is `ls -d ~/.codex/plugins/cache/*/pstack/*/ | sort -V | tail -1`.

Benny ships as a dormant task pack inside pstack. The plugin manifest exposes only pstack's normal skill root; this file and the two operational files are not `$` skills.

The human enters setup by pointing Codex at the pack's `FOR_AGENTS.md`. The bootstrap flow copies the whole pack into the target repository, then reads this file directly at `.agents/automations/benny/skills/setup-benny/SKILL.md`.

Benny needs external configuration and two live ChatGPT Scheduled tasks, each started by a Slack event trigger.

Do not create or update a task until the user explicitly asks. Never put a secret value in plugin files, prompts, or committed configuration.

## 1. Copy the pack and vendor shared pstack skills

Do this before asking for Benny configuration and before creating any Scheduled task.

Ask which repository will run the tasks. The source pack is the directory containing `FOR_AGENTS.md`. The destination is `<target-repository>/.agents/automations/benny/`.

Merge the entire source pack into the destination:

1. Create the destination when it is absent.
2. Copy every source file to the same relative path.
3. Preserve destination-only files. Never delete unrelated files during install or refresh.
4. Keep user-owned configuration, feature maps, and routing maps outside the destination. Never overwrite them.
5. When an existing source-managed file differs, inspect the diff and merge without discarding local edits. If ownership is ambiguous, stop and ask before replacing it.
6. Verify that the destination contains `FOR_AGENTS.md`, this setup file, both operational files, their references, the templates, and `agents/`.

If this file is already being read from the target destination, treat the copy as complete and run the same verification before continuing.

Scheduled task runs do not install plugins. Codex loads skills committed in the repository's `.agents/skills/`. Vendor these shared pstack skills there:

1. Find the installed plugin with `ls -d ~/.codex/plugins/cache/*/pstack/*/ | sort -V | tail -1`. If it is empty, use the `skills/` directory two folders above the source pack.
2. Copy each whole skill folder from that plugin's `skills/` directory to `<target-repository>/.agents/skills/<name>/`.
3. Also copy `poteto-mode`, which `how` and `why` read, and any other pstack skill a vendored skill tells the agent to read.
4. Record the pstack version from that plugin's `.codex-plugin/plugin.json` and the vendored skill names in `.agents/automations/benny/VENDORED.md`.
5. On install or refresh, merge each vendored folder by the same rules as the pack merge. Preserve destination-only files and never discard local edits. If a same-named skill in `.agents/skills/` did not come from pstack, stop and ask.

Install benny's worker agents. Copy `agents/benny-reader.toml` and `agents/benny-coder.toml` from the pack to `<target-repository>/.codex/agents/`, merging by the same rules. Never overwrite a destination file whose first line lacks `# managed-by: pstack-rewire`. Each sets `[features] apps = false` to turn off connector tools. Codex cannot remove MCP servers per agent, so each brief's Slack-write ban and the coordinator-only posting rule stay the guard. Codex loads project agents only when the project is trusted, so ask the user to trust the target repository in Codex.

Start a fresh Codex session rooted in the target repository. Verify that these shared pstack skills resolve from `.agents/skills/` under their bare names, such as `$how`, not as plugin skills such as `$pstack:how`:

- `how`
- `why`
- `tdd`
- `unslop`
- `principle-separate-before-serializing-shared-state`
- `principle-minimize-reader-load`
- `principle-guard-the-context-window`
- `principle-sequence-verifiable-units`
- `principle-fix-root-causes`
- `principle-prove-it-works`

In the same session, spawn one `benny-reader` and one `benny-coder` with `fork_turns: "none"` and ask each to list every tool it has. Neither may list a Slack, tracker, or other connector tool. If either does, or `agent_type` rejects the name, the workers are not isolated. Tell the user and keep worker delegation off by keeping the work in the coordinator.

Do not count a skill loaded from the current session or a user-scoped plugin. The check must show that a fresh agent in the target repository receives these skills from `.agents/skills/`. Once the files are committed and the user asks for tasks, repeat both checks inside the task environment with a paused test Scheduled task whose prompt only lists each skill with the path it resolved from, and each worker's tools. Delete the test task afterwards.

If any shared dependency does not resolve from `.agents/skills/`, stop and explain the failure.

The Benny files are read directly from `.agents/automations/benny/`. Do not add that directory to a plugin manifest or expect its `SKILL.md` files to appear in the `$` skill list.

Tell the user that the vendored `.agents/skills/` folders, `.codex/agents/benny-reader.toml` and `benny-coder.toml`, `.agents/automations/benny/`, and any referenced secret-free configuration must be committed before either task is enabled. Do not commit them unless the user asks.

Once this check passes, live task prompts may read the committed operational files by their stable repository-relative paths. They must not embed a plugin cache path or copy the file contents.

## 2. Adapt the configuration

Open these copied examples:

- `.agents/automations/benny/templates/configuration.example.yaml`
- `.agents/automations/benny/skills/reproduce-and-fix-issues/references/feature-map.example.md`

Create user-owned copies outside `.agents/automations/benny/`. These are configuration files, not pack files. Example locations:

- Project config, such as `.agents/benny/configuration.yaml`
- Project feature map, such as `.agents/benny/feature-map.md`
- Project routing map, such as `.agents/benny/routing.md`
- User config, such as `~/.config/benny/configuration.yaml`
- User feature map, such as `~/.config/benny/feature-map.md`

Fill one feature-map section for every user-facing feature the task may reproduce. Keep it at the user point of view. Do not freeze implementation details or current code paths in the map.

Do not edit the copied examples. Pack refreshes may update source-managed files after conflict review, but they must never touch the user-owned copies.

Prefer committed, secret-free files in the target repository when a task's fresh checkout must read them. A task cannot read user-scoped files such as `~/.config/benny/`. Otherwise paraphrase the required values into the live prompt. Reference a repository file only after `git` confirms that the file is committed on the default branch the task's environment checks out.

Use stable repository-relative paths for committed pack and configuration files. Never reference the plugin source directory or a plugin cache path from a live task.

## 3. Fill the required choices

Ask for or confirm:

- Source Slack channel ID
- Optional operations or status channel ID
- Repository URL and default branch
- Triage identity or Slack user ID, the identity the triage task's Slack connector posts as
- Issue tracker type, team, project, labels, and intake status
- Tracker adapter skill, connector, or MCP actions
- Optional routing map path
- Required control skill name
- Required user-facing feature-map path
- Status emoji strings
- Pull request URL format
- Polling and effort budgets
- Model slug and effort for triage, repro, code work, and media review

Use only slugs listed in `~/.codex/models_cache.json` with `visibility: "list"`. For the triage and repro values, which set each task's model, use only models the Scheduled task's model picker offers. Effort is `low`, `medium`, `high`, `xhigh`, or `max`. Never set `ultra`. Do not guess a value and do not carry over a private default.

The source channel, triage identity, repository, tracker adapter, control skill, and feature map must be explicit. Fail setup if any required value stays ambiguous.

Use pstack's `unslop` skill on the final task names, descriptions, and prompts before saving them.

## 4. Check integration capabilities

The triage task needs:

- Read access to the configured source Slack channel and its threads
- Thread-reply access in that channel
- Attachment metadata and file download access when reports include media
- Search, read, create, and update access through the configured issue-tracker adapter

The repro task needs:

- Read access to the source thread
- Thread-reply access in the source channel
- Optional post and edit access in the configured operations channel
- Repository read and history access
- `gh pr create --draft` in the task's environment, with `gh` installed and authenticated and `.git` writable for commits
- The configured control-adapter skill

Prefer the ChatGPT Slack connector available to each task for reads and posts, and the tracker's connector for tracker work. The optional `BENNY_SLACK_BOT_TOKEN` may fill a narrow gap such as editing one operations status message or downloading an attachment. Store the value in the task environment's secret settings, not in YAML.

Do not use undocumented integration endpoints.

## 5. Prepare the routing map

If the user wants reroutes or owner pings:

1. Copy `.agents/automations/benny/skills/triage-issue-reports/references/routing.example.md` outside `.agents/automations/benny/`.
2. Replace every placeholder with public or organization-local values.
3. Keep owner pings off by default.
4. Allow a ping only for a configured feature owner or a confirmed likely regression author.

If no routing map is configured, triage may classify a report but must not guess a destination or owner.

## 6. Verify the control adapter

Read `.agents/automations/benny/skills/reproduce-and-fix-issues/references/control-adapter.md` and the user's completed feature map.

Confirm that the named skill can:

- Bring up the target app
- Navigate every mapped feature through the real UI
- Exercise mapped states through declared adapter actions
- Inspect state without forcing the result
- Capture screenshots
- Start and stop a recording
- Clean up its processes and temporary data

Run the check in the repro task's environment. If any capability is missing, leave the repro task paused. It must fail closed rather than claim a reproduction it did not perform.

## 7. Prepare the live tasks

Ask whether this is first-time creation or configuration of existing tasks.

Read `.agents/automations/benny/FOR_AGENTS.md` from the copied pack as the primary user-intent source for either path. Use it to understand the two triggers, tools, instructions, outcomes, and shared rules.

### First-time creation

Create one task at a time.

For each task:

1. Read the matching copied prompt template as secondary internal source material.
2. Turn `FOR_AGENTS.md`, the finished Benny configuration, and the template intent into a complete natural-language task prompt.
3. Tell the live prompt to read and follow its exact committed operational file under `.agents/automations/benny/`.
4. Use the stable repository-relative path, not a plugin source or cache path. Do not copy the operational file contents into the live prompt.
5. Confirm that the copied pack, the vendored skills, the benny agents, and any referenced configuration files are committed on the default branch the task's environment checks out.
6. Give the user these steps in ChatGPT on the web, one at a time, and wait for each to be done:
   1. Open Scheduled tasks and start a new task with the name below.
   2. Set the trigger to the Slack event for a new message in the configured source channel. Add no schedule. An event trigger cannot be combined with one.
   3. Paste the finished task prompt.
   4. Choose the Codex environment for the target repository on its default branch. Confirm that it has the Slack and tracker connectors, `gh` authenticated, and any `BENNY_SLACK_BOT_TOKEN` in its secret settings.
   5. Set the model and effort from configuration.
   6. Save the task paused.
7. Ask the user to review the saved task. Finish that review before starting the next task.

Use this complete triage intent, filled from configuration:

- Name `benny-triage`.
- Read and follow `.agents/automations/benny/skills/triage-issue-reports/SKILL.md` for every run.
- Trigger on each new message in the configured source Slack channel. The run acts only on a new top-level report and stops silently for a threaded reply.
- Model from `models.triage`, effort from `models.triage_effort`.
- Read the triggering thread and reply only inside it.
- Use the configured issue-tracker connector.
- Classify, inspect evidence, trace cause, dedupe, and create only clear new bugs.
- End one thread-only verdict with the configured `[benny:bug]`, `[benny:performance]`, or `[benny:other]` marker and optional tracker URL.
- Treat a repeated event for a report that already has a verdict as a no-op.
- Never post a source-channel root message.

After the triage review is complete, use this complete repro and fix intent:

- Name `benny-reproduce`.
- Read and follow `.agents/automations/benny/skills/reproduce-and-fix-issues/SKILL.md` for every run.
- Trigger on the same new messages in the configured source Slack channel, through its own event trigger.
- Model from `models.reproduce`, effort from `models.reproduce_effort`.
- Use the configured repository and default branch.
- Read the source thread and reply only inside it.
- Include draft pull request creation and the configured tracker, control-adapter, and feature-map requirements. Paraphrase mapped user paths and states unless the feature map is an eligible committed file in the same repository.
- Wait for a trusted triage marker before acting, polling the thread with `sleep` between reads.
- Reproduce the exact symptom twice through the mapped real UI and capture evidence.
- Verify an existing fix without authoring over it.
- Attempt an optional bounded fix only after confirmed repro, then open a draft pull request when proof and checks pass.
- Treat a repeated event for a report this task already handled as a no-op.
- Never post a source-channel root message.

### Existing tasks

Ask the user to find the existing Benny tasks in Scheduled tasks. Never create a replacement or duplicate.

Finish configuration, routing, control-adapter, and feature-map validation. Then give the user this concise checklist to update each existing task in place in its task editor.

For the existing triage task, update:

- Name and description
- Direct instruction to read `.agents/automations/benny/skills/triage-issue-reports/SKILL.md`
- Slack event trigger for new messages in the source channel
- Slack connector for thread read and reply
- Issue-tracker connector
- Environment and its secret settings
- Model and effort
- Paraphrased triage instructions, thread-only rule, and Benny verdict markers

For the existing repro task, update:

- Name and description
- Direct instruction to read `.agents/automations/benny/skills/reproduce-and-fix-issues/SKILL.md`
- Matching Slack event trigger and source channel
- Repository and default branch
- Slack connector for thread read and reply
- Draft pull request access through `gh` in the task's environment
- Environment and its secret settings
- Model and effort
- Tracker, control-adapter, and feature-map requirements
- Paraphrased marker wait, evidence, verification, and bounded-fix instructions

Do not create replacements or duplicates.

### Creation boundary

Never call an undocumented Scheduled tasks or ChatGPT endpoint. There is no API trigger. Tasks are created and updated only by the user in the Scheduled tasks editor in ChatGPT on the web, from the steps above.

Do not enable either task until the thread-safety test passes after that review.

## 8. Test thread safety

Use a test channel or a harmless test report.

Before testing, confirm that the vendored `.agents/skills/` folders, `.codex/agents/benny-reader.toml` and `benny-coder.toml`, `.agents/automations/benny/`, and every referenced secret-free configuration file are committed on the branch the tasks' environment checks out. Confirm that both live prompts point at their exact committed operational files. If any check fails, stop. Tell the user that the task cannot be enabled yet.

Verify:

1. Triage reads `channel` and `ts` from the Slack event, stores the root `thread_ts`, and posts exactly one verdict as a reply.
2. The verdict contains one configured marker.
3. Repro accepts the marker only from the configured triage identity.
4. Repro keeps the same immutable source coordinates.
5. No source-channel root message appears.
6. A delegated worker cannot use any Slack write action. Workers are `benny-reader` or `benny-coder`, and each one's tool list shows no connector tool.
7. Missing coordinates, a deleted parent, or a failed preflight produces no post and no tracker issue.
8. A second event for the same `ts` posts nothing and creates no tracker issue. If Scheduled tasks offer no way to replay an event, tell the user this check cannot run. Count it as passed only when the user accepts that gap.
9. A threaded reply in the test thread starts runs that post nothing.

Enable normal traffic only after all nine checks pass.
