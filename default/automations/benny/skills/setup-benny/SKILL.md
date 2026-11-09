---
name: setup-benny
description: Configure Benny and prepare its triage and repro automations. Use when installing Benny or changing its Slack, tracker, repository, routing, control, model, or budget settings.
disable-model-invocation: true
---

# Set up Benny

pstack's shared skills are installed in the target repository at `.agents/skills/<name>/` by section 1. To run one, read `.agents/skills/<name>/SKILL.md` and follow it.

Benny ships as a dormant automation pack inside pstack. The plugin manifest exposes only pstack's normal skill root; this file and the two operational files are not slash skills.

The human enters setup by pointing their agent at the pack's `FOR_AGENTS.md`. The bootstrap flow copies the whole pack into the target repository, then reads this file directly at `.agents/automations/benny/skills/setup-benny/SKILL.md`.

Benny needs external configuration and two live automations. Benny has no standard automation platform. Run triage and repro with your platform's automation or scheduler, a Slack bot that runs a headless agent, or CI. Each run receives the Slack message (channel, `ts`, `thread_ts`).

Do not create or update an automation until the user explicitly asks. Never put a secret value in plugin files, prompts, or committed configuration.

## 1. Copy the pack and enable shared pstack skills

Do this before asking for Benny configuration and before creating any automation.

Ask which repository will run the automations. The source pack is the directory containing `FOR_AGENTS.md`. The destination is `<target-repository>/.agents/automations/benny/`.

Merge the entire source pack into the destination:

1. Create the destination when it is absent.
2. Copy every source file to the same relative path.
3. Preserve destination-only files. Never delete unrelated files during install or refresh.
4. Keep user-owned configuration, feature maps, and routing maps outside the destination. Never overwrite them.
5. When an existing source-managed file differs, inspect the diff and merge without discarding local edits. If ownership is ambiguous, stop and ask before replacing it.
6. Verify that the destination contains `FOR_AGENTS.md`, this setup file, both operational files, their references, and the templates.

If this file is already being read from the target destination, treat the copy as complete and run the same verification before continuing.

Install pstack's shared skills into the target repository's `.agents/skills/`. Either run the installer from the target repository root:

```sh
curl -fsSL https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/install.sh | bash -s -- --target default --scope workspace
```

or vendor the skill folders:

1. Copy each whole skill folder below from pstack's `skills/` directory, the `skills/` directory two folders above the source pack, to `.agents/skills/<name>/`.
2. Also copy any pstack skill that a vendored skill tells the agent to read, such as `poteto-mode`.
3. Record the pstack version from pstack's `plugin.json` and the vendored skill names in `.agents/automations/benny/VENDORED.md`.
4. On refresh, merge each vendored folder by the same rules as the pack merge. Preserve destination-only files and never discard local edits.

Benny's worker agents ship in the pack at `agents/benny-reader.md` and `agents/benny-coder.md`. If your agent supports per-agent tool allowlists, register them so `benny-reader` gets only read, search, and shell tools, `benny-coder` also gets edit tools, and neither gets connector or MCP tools. That is what keeps delegated workers away from Slack. If it does not, the operational files keep all work in the coordinator.

Start a fresh agent session rooted in the target repository. Verify that it lists these shared pstack skills from `.agents/skills/`:

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

Do not count a skill loaded from the current session or a user-scoped install such as `~/.agents/skills/`. The check must show that a fresh agent in the target repository receives these skills from `.agents/skills/`. Once the files are committed and the user asks for automations, repeat the check with one manual run of the chosen trigger on the target repository. Its prompt only lists each skill and the path it resolved from.

If any shared dependency does not resolve from `.agents/skills/`, stop and explain the failure.

The Benny files are read directly from `.agents/automations/benny/`. Do not add that directory to a plugin manifest or expect its `SKILL.md` files to appear in the slash-skill list.

Tell the user that the `.agents/skills/` folders, `.agents/automations/benny/`, and any referenced secret-free configuration must be committed before either automation is enabled. Do not commit them unless the user asks.

Once this check passes, live automation prompts may read the committed operational files by their stable repository-relative paths. They must not embed a plugin cache path or copy the file contents.

## 2. Adapt the configuration

Open these copied examples:

- `../../templates/configuration.example.yaml`
- `../reproduce-and-fix-issues/references/feature-map.example.md`

Create user-owned copies outside `.agents/automations/benny/`. These are configuration files, not pack files. Example locations:

- Project config, such as `.agents/benny/configuration.yaml`
- Project feature map, such as `.agents/benny/feature-map.md`
- Project routing map, such as `.agents/benny/routing.md`
- User config, such as `~/.config/benny/configuration.yaml`
- User feature map, such as `~/.config/benny/feature-map.md`

Fill one feature-map section for every user-facing feature the automation may reproduce. Keep it at the user point of view. Do not freeze implementation details or current code paths in the map.

Do not edit the copied examples. Pack refreshes may update source-managed files after conflict review, but they must never touch the user-owned copies.

Prefer committed, secret-free files in the target repository when a fresh automation checkout must read them. Otherwise paraphrase the required values into the live prompt. Reference a repository file only after `git` confirms that the file is committed on the branch the automation checks out.

Use stable repository-relative paths for committed pack and configuration files. Never reference the plugin source directory or a plugin cache path from a live automation.

## 3. Fill the required choices

Ask for or confirm:

- Source Slack channel ID
- Optional operations or status channel ID
- Repository URL and default branch
- Triage identity or Slack user ID, the identity the triage automation posts as
- Issue tracker type, team, project, labels, and intake status
- Tracker adapter skill or MCP actions
- Optional routing map path
- Required control skill name
- Required user-facing feature-map path
- Status emoji strings
- Pull request URL format
- Polling and effort budgets
- Model and effort for triage, repro, code work, and media review

Use only model ids your agent accepts. The default is `inherit`, the model the run starts on. Do not guess an id and do not carry over a private default.

The source channel, triage identity, repository, tracker adapter, control skill, and feature map must be explicit. Fail setup if any required value stays ambiguous.

Use pstack's `unslop` skill on the final automation names, descriptions, and prompt shims before saving them.

## 4. Check integration capabilities

The triage automation needs:

- Read access to the configured source Slack channel and its threads
- Thread-reply access in that channel
- Attachment metadata and file download access when reports include media
- Search, read, create, and update access through the configured issue-tracker adapter

The repro automation needs:

- Read access to the source thread
- Thread-reply access in the source channel
- Optional post and edit access in the configured operations channel
- Repository read and history access
- `gh pr create --draft` or a pull request action that can open a draft pull request
- The configured control-adapter skill

Prefer the Slack actions or MCP tools configured for each automation for reads and posts. The optional `BENNY_SLACK_BOT_TOKEN` may fill a narrow gap such as editing one operations status message or downloading an attachment. Store the value in a secret manager or the run's environment, not in YAML.

Do not use undocumented integration endpoints.

## 5. Prepare the routing map

If the user wants reroutes or owner pings:

1. Copy `../triage-issue-reports/references/routing.example.md` outside `.agents/automations/benny/`.
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

Run the check in the environment where the repro automation runs. If any capability is missing, leave the repro automation disabled. It must fail closed rather than claim a reproduction it did not perform.

## 7. Prepare the live automations

Ask whether this is first-time creation or configuration of existing automations.

Read `../../FOR_AGENTS.md` from the copied pack as the primary user-intent source for either path. Use it to understand the two triggers, tools, instructions, outcomes, and shared rules.

### First-time creation

Create one automation at a time.

For each automation:

1. Read the matching copied prompt template as secondary internal source material.
2. Turn `FOR_AGENTS.md`, the finished Benny configuration, and the template intent into a complete natural-language request.
3. Tell the live prompt to read and follow its exact committed operational file under `.agents/automations/benny/`.
4. Use the stable repository-relative path, not a plugin source or cache path. Do not copy the operational file contents into the live prompt.
5. Create it on the platform the user chose: an automation or scheduler on their agent platform, a Slack bot that runs a headless agent, or a CI job.
6. Set the repository and branch it checks out, the Slack and tracker access it needs, and the secrets in its environment.
7. Confirm that the copied pack, the `.agents/skills/` folders, and any referenced configuration files are committed on the branch the run checks out.
8. Wire the trigger so each run receives the Slack message (channel, `ts`, `thread_ts`). Save the prompt with the automation disabled. Then ask the user to review it on its platform.
9. Finish that review for this automation before starting the next one.

Use this complete triage intent, filled from configuration:

- Name `benny-triage`.
- Read and follow `.agents/automations/benny/skills/triage-issue-reports/SKILL.md` for every run.
- Trigger on each new top-level report in the configured source Slack channel.
- Model from `models.triage`.
- Read the triggering thread and reply only inside it.
- Use the configured issue-tracker integration.
- Classify, inspect evidence, trace cause, dedupe, and create only clear new bugs.
- End one thread-only verdict with the configured `[benny:bug]`, `[benny:performance]`, or `[benny:other]` marker and optional tracker URL.
- Never post a source-channel root message.

After the triage review is complete, use this complete repro and fix intent:

- Name `benny-reproduce`.
- Read and follow `.agents/automations/benny/skills/reproduce-and-fix-issues/SKILL.md` for every run.
- Trigger on the same new top-level reports in the configured source Slack channel.
- Model from `models.reproduce`.
- Use the configured repository and default branch.
- Read the source thread and reply only inside it.
- Include draft pull request creation and the configured tracker, control-adapter, and feature-map requirements. Paraphrase mapped user paths and states unless the feature map is an eligible committed file in the same repository.
- Wait for a trusted triage marker before acting.
- Reproduce the exact symptom twice through the mapped real UI and capture evidence.
- Verify an existing fix without authoring over it.
- Attempt an optional bounded fix only after confirmed repro, then open a draft pull request when proof and checks pass.
- Never post a source-channel root message.

A trigger may fire for every message in the channel, including threaded replies, and may deliver one message more than once. The operational files stop on threaded replies and make duplicate runs a no-op. Confirm the platform keeps each run alive long enough for the in-run polling waits in `budgets`.

Skipped in this agent: platform-specific creation steps. Benny has no standard automation platform, so follow the chosen platform's own creation and review flow.

### Existing automations

Find the existing Benny automations on the user's platform. Never create a replacement or duplicate.

Finish configuration, routing, control-adapter, and feature-map validation. Then give the user this concise checklist.

For the existing triage automation, update:

- Name and description
- Direct instruction to read `.agents/automations/benny/skills/triage-issue-reports/SKILL.md`
- New top-level Slack report trigger and source channel
- Slack thread read and reply capabilities
- Issue-tracker integration
- Environment secrets
- Paraphrased triage instructions, thread-only rule, and Benny verdict markers

For the existing repro automation, update:

- Name and description
- Direct instruction to read `.agents/automations/benny/skills/reproduce-and-fix-issues/SKILL.md`
- Matching Slack trigger and source channel
- Repository and default branch
- Slack thread read and reply capabilities
- Draft pull request access through `gh` or the configured pull request action
- Environment secrets
- Tracker, control-adapter, and feature-map requirements
- Paraphrased marker wait, evidence, verification, and bounded-fix instructions

Ask the user to update each existing automation directly on its platform. Do not create replacements or duplicates.

### Creation boundary

Never call an undocumented automation endpoint. Create and update automations only through the platform's documented tools or editor. Never put a secret value in a prompt, a URL, or the repository.

Do not enable either automation until the thread-safety test passes after the save.

## 8. Test thread safety

Use a test channel or a harmless test report.

Before testing, confirm that the target repository's `.agents/skills/` folders, `.agents/automations/benny/`, and every referenced secret-free configuration file are committed on the branch the automation checks out. Confirm that both live prompts point at their exact committed operational files. If any check fails, stop. Tell the user that the automation cannot be enabled yet.

Verify:

1. Triage reads the channel, `ts`, and `thread_ts` of the Slack message the run receives, stores the root `thread_ts`, and posts exactly one verdict as a reply.
2. The verdict contains one configured marker.
3. Repro accepts the marker only from the configured triage identity.
4. Repro keeps the same immutable source coordinates.
5. No source-channel root message appears.
6. A delegated worker cannot use any Slack write action. Workers are `benny-reader` or `benny-coder` with no connector or MCP tools, or the coordinator does the work.
7. Missing coordinates, a deleted parent, or a failed preflight produces no post and no tracker issue.
8. A second run for the same message posts nothing and creates no tracker issue.
9. A run for a threaded reply posts nothing.

Enable normal traffic only after all nine checks pass.
