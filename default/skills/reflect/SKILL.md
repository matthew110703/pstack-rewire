---
name: reflect
description: Spawn three parallel review subagents over the active transcript, surface learnings, and route each to a concrete edit on an existing skill. Use when the user says reflect.
disable-model-invocation: true
---

# Reflect

`<skills>` is the folder that holds this skill's folder, one above this SKILL.md. To run another pstack skill, read `<skills>/<name>/SKILL.md` and follow it.

Mine the current conversation for durable learnings, then route them into skill edits.

Invoke when the user says "reflect" or "/reflect". Skip when the conversation is trivial, off-topic, or already covered by an existing skill the parent followed correctly. One-offs are not learnings.

## 1. Locate the active transcript

Before fanning out, find this conversation's transcript. If your agent stores session transcripts, read this workspace's, newest first (many agents keep them as JSONL under their home dir, e.g. `~/.<agent>/...`). Do not glob across every workspace's transcripts. That crosses workspace boundaries and reads private chats from unrelated projects.

```bash
ls -t <transcripts>/*.jsonl <transcripts>/*/*.jsonl 2>/dev/null | head -10
```

Identify the current session by the newest file or by its opening prompt. For each candidate, read its first user message. Take the file that contains the conversation's opening user prompt. Subagent transcripts are not it. If your agent keeps no transcripts, or none matches, say so and pass a tight digest of the session instead.

## 2. Spawn three reviewers in parallel

Spawn three subagents at once. Use general subagents that can edit and keep MCP access, not read-only ones. Reviewers need MCP access to look up the tickets, chat threads, and observability traces the transcript references, and read-only agent types can strip MCP tools. If your agent cannot spawn subagents, run each lens inline, one at a time, re-reading its template fresh before each.

Each reviewer and the synthesizer name a role line in the `~/.agents/pstack-models.md` file and a default. Pass the model and effort from that line's value, or from the default if the file or the line is missing. Leave the model unset when the value is `inherit`, `inherit-parent`, or `auto`. If your subagent tool rejects the value, omit the model and say so. Pick each subagent's effort level for the job, per the Subagents section of the **poteto-mode** skill.

| Lens | Role line | Default `model` | Prompt template |
|---|---|---|---|
| Judgment | `reflect judgment, divergent, synthesizer` | `inherit` | `<skills>/reflect/references/judgment-reviewer.md` |
| Tooling | `reflect tooling` | `inherit` | `<skills>/reflect/references/tooling-reviewer.md` |
| Divergent | `reflect judgment, divergent, synthesizer` | `inherit` | `<skills>/reflect/references/divergent-reviewer.md` |

Pass each template verbatim, substituting the transcript path or digest where marked. Reviewers return findings in their final report.

## 3. Synthesize

Spawn one subagent the same way (can edit, keeps MCP access), with model and effort from the `reflect judgment, divergent, synthesizer` line (default `inherit`). It spot-verifies citations through MCP. Pass `<skills>/reflect/references/synthesizer.md` verbatim, with each reviewer's full output inlined where marked. It returns an Accepted / Rejected / Backlog list.

## 4. Structural enforcement check

Move any Accepted item that a lint rule, script, metadata flag, or runtime check would enforce more reliably to Backlog. See the **encode-lessons-in-structure** principle skill.

## 5. Apply

Present the synthesizer's full Accepted / Rejected / Backlog output and wait for explicit approval before applying any Accepted edit. The user picks the subset and may redirect routings. Skill changes affect every future agent in the org. Do not auto-apply.

File each Backlog item to your team's devex or backlog tracker without waiting. Only the Accepted list waits for approval.

Never edit a skill inside a plugin cache your agent manages. Before approval, show its destination, `.agents/skills/<skill>/` or `~/.agents/skills/<skill>/`. After approval, copy the skill folder there (unless it already lives there) and edit that copy. Never open a PR or push.

Follow each approved row's Routing exactly:

- Trivial existing-skill edit (a one-line bullet, a tightened sentence, a stale fact corrected): the parent does it directly.
- Substantive existing-skill edit (a new section, a new pattern table, more than ~10 lines): hand to your agent's skill-authoring helper and run its draft / test / iterate loop. If it has none, follow `<skills>/poteto-mode/playbooks/authoring-a-skill.md` instead.
- `tune description: <skill path>` (the skill exists but didn't trigger when it should have): hand to the skill-authoring helper and run its description-optimization loop, or the authoring playbook when there is none.
- `new skill via create-skill: <kebab-name>`: hand creation to the skill-authoring helper, or the authoring playbook when there is none. Do not invent the shape ad hoc.

If your environment ships a SKILL.md validator, run it on every touched skill before declaring done.

## 6. Summarize for the user

Short list, no preamble:

- Edits applied: `<skill path>`. What changed, one line each.
- New skills created: `<skill path>`. One line each (rare).
- Backlog filed to the devex tracker: `<issue title>` (`<tags>`). One line each.
- Dropped: one line per rejected finding + reason from the synthesizer.
