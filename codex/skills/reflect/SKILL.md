---
name: reflect
description: Spawn three parallel review subagents over the active transcript, surface learnings, and route each to a concrete edit on an existing skill. Use when the user says reflect.
---

# Reflect

`<pstack>` is the pstack plugin root, two folders above this SKILL.md (Codex shows each skill's path; if not, run `ls -d ~/.codex/plugins/cache/*/pstack/*/ | sort -V | tail -1`). To run another pstack skill or `$pstack:<name>`, read `<pstack>/skills/<name>/SKILL.md` and follow it.

Mine the current conversation for durable learnings, then route them into skill edits.

Invoke when the user says "reflect" or "$pstack:reflect". Skip when the conversation is trivial, off-topic, or already covered by an existing skill the parent followed correctly. One-offs are not learnings.

## 1. Locate the active transcript

Before fanning out, find this conversation's rollout under `~/.codex/sessions/`. Its id is `$CODEX_THREAD_ID`. Read only rollouts whose first `session_meta` line has this workspace as `payload.cwd`. Reading others crosses workspace boundaries and reads private chats from unrelated projects.

```bash
ls -t ~/.codex/sessions/*/*/*/rollout-*"$CODEX_THREAD_ID"*.jsonl* 2>/dev/null | head -1
ls -t ~/.codex/sessions/*/*/*/rollout-*.jsonl* 2>/dev/null | head -10
```

The first command finds the current session by id. When it finds nothing, take the newest candidates from the second. A `.jsonl.zst` file reads with `zstdcat`. For each candidate, read the first line. A subagent rollout has `parent_thread_id` and is not it. Take the file whose `session_meta.payload.id` is `$CODEX_THREAD_ID`, or whose first user `response_item` (`content[].text`) contains the conversation's opening user prompt. If none matches, pass a tight digest of the session instead.

## 2. Spawn three reviewers in parallel

One message, three `spawn_agent` calls, `agent_type: "worker"`, `fork_turns: "none"`. Reviewers need MCP access to look up the tickets, chat threads, and observability traces the transcript references, and `worker` keeps the session's MCP tools.

Each reviewer and the synthesizer name a role line in the `pstack-models` block and a default. Set `model` and `reasoning_effort` from that line's value (`gpt-6-astra xhigh` is `model: "gpt-6-astra"`, `reasoning_effort: "xhigh"`), or from the default if the block or the line is missing. Leave `model` unset when the value is `auto` or `inherit-parent`. A `model` must be a slug with `visibility: "list"` in `~/.codex/models_cache.json`. Otherwise omit `model` and say so. Never set `ultra`. Pick each subagent's effort level for the job, per the Subagents section of the **poteto-mode** skill.

| Lens | Role line | Default `model` | Prompt template |
|---|---|---|---|
| Judgment | `reflect judgment, divergent, synthesizer` | `gpt-6-astra xhigh` | `<pstack>/skills/reflect/references/judgment-reviewer.md` |
| Tooling | `reflect tooling` | `inherit-parent` | `<pstack>/skills/reflect/references/tooling-reviewer.md` |
| Divergent | `reflect judgment, divergent, synthesizer` | `gpt-6-astra xhigh` | `<pstack>/skills/reflect/references/divergent-reviewer.md` |

Pass each template verbatim, substituting the transcript path or digest where marked. Reviewers return findings in their final message, which `wait_agent` returns.

## 3. Synthesize

One `spawn_agent` call, `agent_type: "worker"`, `model` and `reasoning_effort` from the `reflect judgment, divergent, synthesizer` line (default `gpt-6-astra xhigh`). It spot-verifies citations through MCP, and `worker` keeps the session's MCP tools. Pass `<pstack>/skills/reflect/references/synthesizer.md` verbatim, with each reviewer's full output inlined where marked. It returns an Accepted / Rejected / Backlog list.

## 4. Structural enforcement check

Move any Accepted item that a lint rule, script, metadata flag, or runtime check would enforce more reliably to Backlog. See the **encode-lessons-in-structure** principle skill.

## 5. Apply

Present the synthesizer's full Accepted / Rejected / Backlog output and wait for explicit approval before applying any Accepted edit. The user picks the subset and may redirect routings. Skill changes affect every future agent in the org. Do not auto-apply.

File each Backlog item to your team's devex or backlog tracker without waiting. Only the Accepted list waits for approval.

Never edit a skill under `~/.codex/plugins/cache/`. Before approval, show its destination, `.agents/skills/<skill>/` or `~/.agents/skills/<skill>/`. After approval, copy the skill folder there and edit the copy. The copy appears as `$<skill>` beside `$pstack:<skill>`. Never open a PR or push.

Follow each approved row's Routing exactly:

- Trivial existing-skill edit (a one-line bullet, a tightened sentence, a stale fact corrected): the parent does it directly.
- Substantive existing-skill edit (a new section, a new pattern table, more than ~10 lines): hand to the built-in `$skill-creator` skill and run its draft / test / iterate loop. When it is not installed, follow `<pstack>/skills/poteto-mode/playbooks/authoring-a-skill.md` instead.
- `tune description: <skill path>` (the skill exists but didn't trigger when it should have): hand to `$skill-creator` and run its description-optimization loop, or the authoring playbook when it is not installed.
- `new skill via create-skill: <kebab-name>`: hand creation to `$skill-creator`, or the authoring playbook when it is not installed. Do not invent the shape ad hoc.

If your environment ships a SKILL.md validator, run it on every touched skill before declaring done.

## 6. Summarize for the user

Short list, no preamble:

- Edits applied: `<skill path>`. What changed, one line each.
- New skills created: `<skill path>`. One line each (rare).
- Backlog filed to the devex tracker: `<issue title>` (`<tags>`). One line each.
- Dropped: one line per rejected finding + reason from the synthesizer.
