---
name: setup-benny
description: Configure Benny and prepare its triage and repro routines. Use when installing Benny or changing its Slack, tracker, repository, routing, control, model, or budget settings.
disable-model-invocation: true
---

# Set up Benny

pstack's shared skills are vendored in the target repository at `.claude/skills/<name>/` by section 1. To run one, read `.claude/skills/<name>/SKILL.md` and follow it. The Skill tool refuses pstack skills.

Benny ships as a dormant routine pack inside pstack. The plugin manifest exposes only pstack's normal skill root; this file and the two operational files are not slash skills.

The human enters setup by pointing Claude Code at the pack's `FOR_AGENTS.md`. The bootstrap flow copies the whole pack into the target repository, then reads this file directly at `.claude/automations/benny/skills/setup-benny/SKILL.md`.

Benny needs external configuration and two live Claude Code routines.

Do not create or update a routine until the user explicitly asks. Never put a secret value in plugin files, prompts, or committed configuration.

## 1. Copy the pack and enable shared pstack skills

Do this before asking for Benny configuration and before invoking the `schedule` skill.

Ask which repository will run the routines. The source pack is the directory containing `FOR_AGENTS.md`. The destination is `<target-repository>/.claude/automations/benny/`.

Merge the entire source pack into the destination:

1. Create the destination when it is absent.
2. Copy every source file to the same relative path.
3. Preserve destination-only files. Never delete unrelated files during install or refresh.
4. Keep user-owned configuration, feature maps, and routing maps outside the destination. Never overwrite them.
5. When an existing source-managed file differs, inspect the diff and merge without discarding local edits. If ownership is ambiguous, stop and ask before replacing it.
6. Verify that the destination contains `FOR_AGENTS.md`, this setup file, both operational files, their references, and the templates.

If this file is already being read from the target destination, treat the copy as complete and run the same verification before continuing.

Add pstack to the target repository's `.claude/settings.json`. If the file or `.claude` directory does not exist, create it.

Merge these entries into the existing JSON:

```json
{
	"extraKnownMarketplaces": {
		"pstack-rewire": {
			"source": { "source": "github", "repo": "matthew110703/pstack-rewire" }
		}
	},
	"enabledPlugins": {
		"pstack@pstack-rewire": true
	}
}
```

Preserve every unrelated top-level setting, every other marketplace, and every other plugin entry. If `enabledPlugins["pstack@pstack-rewire"]` already exists, change only its value. Validate the file after editing it.

These settings load pstack in local sessions. Routine runs do not install marketplace plugins. They load skills committed in the repository's `.claude/skills/`. Vendor the shared skills below there:

1. Copy each whole skill folder from the installed pstack plugin's `skills/` directory, `${CLAUDE_PLUGIN_ROOT}/skills/` when that is expanded, otherwise the `skills/` directory two folders above the source pack.
2. Also copy any pstack skill that a vendored skill tells the agent to read, such as `poteto-mode`.
3. Record the pstack version from that plugin's `.claude-plugin/plugin.json` and the vendored skill names in `.claude/automations/benny/VENDORED.md`.
4. On refresh, merge each vendored folder by the same rules as the pack merge. Preserve destination-only files and never discard local edits.

Install benny's worker agents. Copy `agents/benny-reader.md` and `agents/benny-coder.md` from the pack to the target repository's `.claude/agents/`, merging by the same rules. Their `tools` allowlists contain no connector or MCP tools, which is what keeps delegated workers away from Slack. Commit them with the pack. In the fresh-session check below, also confirm that both agents are listed.

Start a fresh `claude` session rooted in the target repository. Verify that these shared pstack skills resolve from `.claude/skills/` under their bare names, not as plugin skills such as `pstack:how`:

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

Do not count a skill loaded from the current session or a user-scoped plugin. The check must show that a fresh agent in the target repository receives these skills from `.claude/skills/`. Once the files are committed and the user asks for routines, repeat the check with a manual Run now of a disabled test routine on the target repository. Its prompt only lists each skill and the path it resolved from. Remove the test routine on its routine page afterwards.

If any shared dependency does not resolve from `.claude/skills/`, stop and explain the failure.

The Benny files are read directly from `.claude/automations/benny/`. Do not add that directory to a plugin manifest or expect its `SKILL.md` files to appear in the slash-skill list.

Tell the user that `.claude/settings.json`, the vendored `.claude/skills/` folders, `.claude/agents/benny-reader.md` and `benny-coder.md`, `.claude/automations/benny/`, and any referenced secret-free configuration must be committed before either routine is enabled. Do not commit them unless the user asks.

Once this check passes, live routine prompts may read the committed operational files by their stable repository-relative paths. They must not embed a plugin cache path or copy the file contents.

## 2. Adapt the configuration

Open these copied examples:

- `../../templates/configuration.example.yaml`
- `../reproduce-and-fix-issues/references/feature-map.example.md`

Create user-owned copies outside `.claude/automations/benny/`. These are configuration files, not pack files. Example locations:

- Project config, such as `.claude/benny/configuration.yaml`
- Project feature map, such as `.claude/benny/feature-map.md`
- Project routing map, such as `.claude/benny/routing.md`
- User config, such as `~/.config/benny/configuration.yaml`
- User feature map, such as `~/.config/benny/feature-map.md`

Fill one feature-map section for every user-facing feature the routine may reproduce. Keep it at the user point of view. Do not freeze implementation details or current code paths in the map.

Do not edit the copied examples. Pack refreshes may update source-managed files after conflict review, but they must never touch the user-owned copies.

Prefer committed, secret-free files in the target repository when a routine's fresh clone must read them. Otherwise paraphrase the required values into the live prompt. Reference a repository file only after `git` confirms that the file is committed on the default branch of the repository the routine clones.

Use stable repository-relative paths for committed pack and configuration files. Never reference the plugin source directory or a plugin cache path from a live routine.

## 3. Fill the required choices

Ask for or confirm:

- Source Slack channel ID
- Optional operations or status channel ID
- Repository URL and default branch
- Triage identity or Slack user ID, the identity the triage routine's Slack connector posts as
- Issue tracker type, team, project, labels, and intake status
- Tracker adapter skill or MCP actions
- Optional routing map path
- Required control skill name
- Required user-facing feature-map path
- Status emoji strings
- Pull request URL format
- Polling and effort budgets
- Model alias and effort for triage, repro, code work, and media review

Use only aliases the Agent tool accepts: `opus`, `sonnet`, `haiku`, or `fable`. Effort is `low`, `medium`, `high`, `xhigh`, or `max`. The triage and repro values set each routine's model. Do not guess a value and do not carry over a private default.

The source channel, triage identity, repository, tracker adapter, control skill, and feature map must be explicit. Fail setup if any required value stays ambiguous.

Use pstack's `unslop` skill on the final routine names, descriptions, and prompts before saving them.

## 4. Check integration capabilities

The triage routine needs:

- Read access to the configured source Slack channel and its threads
- Thread-reply access in that channel
- Attachment metadata and file download access when reports include media
- Search, read, create, and update access through the configured issue-tracker adapter

The repro routine needs:

- Read access to the source thread
- Thread-reply access in the source channel
- Optional post and edit access in the configured operations channel
- Repository read and history access
- `gh pr create --draft` or a GitHub connector that can open a draft pull request
- The configured control-adapter skill

Prefer the Slack connector attached to each routine for reads and posts. The optional `BENNY_SLACK_BOT_TOKEN` may fill a narrow gap such as editing one operations status message or downloading an attachment. Store the value as a secret on the routine's cloud environment, not in YAML.

Do not use undocumented integration endpoints.

## 5. Prepare the routing map

If the user wants reroutes or owner pings:

1. Copy `../triage-issue-reports/references/routing.example.md` outside `.claude/automations/benny/`.
2. Replace every placeholder with public or organization-local values.
3. Keep owner pings off by default.
4. Allow a ping only for a configured feature owner or a confirmed likely regression author.

If no routing map is configured, triage may classify a report but must not guess a destination or owner.

## 6. Verify the control adapter

Read `../reproduce-and-fix-issues/references/control-adapter.md` and the user's completed feature map.

Confirm that the named skill can:

- Bring up the target app
- Navigate every mapped feature through the real UI
- Exercise mapped states through declared adapter actions
- Inspect state without forcing the result
- Capture screenshots
- Start and stop a recording
- Clean up its processes and temporary data

Run the check in the repro routine's cloud environment. If any capability is missing, leave the repro routine disabled. It must fail closed rather than claim a reproduction it did not perform.

## 7. Prepare the live routines

Ask whether this is first-time creation or configuration of existing routines.

Read `../../FOR_AGENTS.md` from the copied pack as the primary user-intent source for either path. Use it to understand the two triggers, tools, instructions, outcomes, and shared rules.

### First-time creation

Create one routine at a time.

For each routine:

1. Read the matching copied prompt template as secondary internal source material.
2. Turn `FOR_AGENTS.md`, the finished Benny configuration, and the template intent into a complete natural-language routine prompt.
3. Tell the live prompt to read and follow its exact committed operational file under `.claude/automations/benny/`.
4. Use the stable repository-relative path, not a plugin source or cache path. Do not copy the operational file contents into the live prompt.
5. Read and follow the `schedule` skill (`/schedule`).
6. Let `schedule` set the repository and default branch, attach the Slack and tracker connectors, and choose the cloud environment and its secrets.
7. Confirm that the copied pack, the vendored skills, `.claude/settings.json`, and any referenced configuration files are committed on the default branch the routine clones.
8. Let `schedule` add an API trigger and save the prompt with the routine disabled. Then ask the user to review the routine on its claude.ai page.
9. Finish that review for this routine before starting the next one.

Give `schedule` this complete triage intent, filled from configuration:

- Name `benny-triage`.
- Read and follow `.claude/automations/benny/skills/triage-issue-reports/SKILL.md` for every run.
- Trigger through an API trigger. The Slack workflow fires it for each message in the configured source Slack channel. The run acts only on a new top-level report.
- Routine model from `models.triage`.
- Read the triggering thread and reply only inside it.
- Use the configured issue-tracker connector.
- Classify, inspect evidence, trace cause, dedupe, and create only clear new bugs.
- End one thread-only verdict with the configured `[benny:bug]`, `[benny:performance]`, or `[benny:other]` marker and optional tracker URL.
- Never post a source-channel root message.

After the triage review is complete, give `schedule` this complete repro and fix intent:

- Name `benny-reproduce`.
- Read and follow `.claude/automations/benny/skills/reproduce-and-fix-issues/SKILL.md` for every run.
- Trigger through its own API trigger, fired by the same Slack workflow for the same messages.
- Routine model from `models.reproduce`.
- Use the configured repository and default branch.
- Read the source thread and reply only inside it.
- Include draft pull request creation and the configured tracker, control-adapter, and feature-map requirements. Paraphrase mapped user paths and states unless the feature map is an eligible committed file in the same repository.
- Wait for a trusted triage marker before acting.
- Reproduce the exact symptom twice through the mapped real UI and capture evidence.
- Verify an existing fix without authoring over it.
- Attempt an optional bounded fix only after confirmed repro, then open a draft pull request when proof and checks pass.
- Never post a source-channel root message.

Do not duplicate `schedule`'s repository, connector, environment, trigger, or review work.

### Slack workflow

After both routines exist, ask the user to build one Slack Workflow Builder workflow that starts when a message is posted in the configured source channel. Give it one web request step per routine. Each step sends a `POST` to that routine's fire URL with `Authorization: Bearer <token>`, `anthropic-beta: experimental-cc-routine-2026-04-01`, and this body:

```json
{ "source_channel_id": "<channel>", "message_ts": "<message timestamp>", "thread_ts": "<thread timestamp, or empty>" }
```

The user copies each bearer token from its routine page into the workflow. Never write a token into the repository, a prompt, or configuration. API fires are rate limited per routine, so confirm the channel's report volume fits. Keep the workflow unpublished until the thread-safety test passes.

### Existing routines

Use the `schedule` skill to list routines and find the existing Benny routines. Never create a replacement or duplicate.

Finish configuration, routing, control-adapter, and feature-map validation. Then update each existing routine through `schedule` with this concise checklist.

For the existing triage routine, update:

- Name and description
- Direct instruction to read `.claude/automations/benny/skills/triage-issue-reports/SKILL.md`
- API trigger and the Slack workflow that fires it for the source channel
- Slack connector for thread read and reply
- Issue-tracker connector
- Cloud environment secrets
- Paraphrased triage instructions, thread-only rule, and Benny verdict markers

For the existing repro routine, update:

- Name and description
- Direct instruction to read `.claude/automations/benny/skills/reproduce-and-fix-issues/SKILL.md`
- Matching API trigger and the same Slack workflow
- Repository and default branch
- Slack connector for thread read and reply
- Draft pull request access through `gh` or a GitHub connector
- Cloud environment secrets
- Tracker, control-adapter, and feature-map requirements
- Paraphrased marker wait, evidence, verification, and bounded-fix instructions

Ask the user to review each updated routine on its claude.ai page. Do not create replacements or duplicates.

### Creation boundary

Never call an undocumented routines endpoint. Create and update routines only through the `schedule` skill or the routine page. For new routines, the only finish path is the `schedule` skill's creation followed by the user's review on the routine page.

Do not enable either routine or publish the Slack workflow until the thread-safety test passes after that review.

## 8. Test thread safety

Use a test channel or a harmless test report.

Before testing, confirm that the target repository's `.claude/settings.json`, the vendored `.claude/skills/` folders, `.claude/automations/benny/`, and every referenced secret-free configuration file are committed on the branch the routines clone. Confirm that both live prompts point at their exact committed operational files. If any check fails, stop. Tell the user that the routine cannot be enabled yet.

Verify:

1. Triage reads `source_channel_id` and `message_ts` from the API fire body, stores the root `thread_ts`, and posts exactly one verdict as a reply.
2. The verdict contains one configured marker.
3. Repro accepts the marker only from the configured triage identity.
4. Repro keeps the same immutable source coordinates.
5. No source-channel root message appears.
6. A delegated worker cannot use any Slack write action. Workers are `benny-reader` or `benny-coder`, and their tool lists show no connector or MCP tools.
7. Missing coordinates, a deleted parent, or a failed preflight produces no post and no tracker issue.
8. A second fire with the same `message_ts` posts nothing and creates no tracker issue.
9. A fire for a threaded reply posts nothing.

Enable normal traffic only after all nine checks pass.
