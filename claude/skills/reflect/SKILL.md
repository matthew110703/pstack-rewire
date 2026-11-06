---
name: reflect
description: Spawn three parallel review subagents over the active transcript, surface learnings, and route each to a concrete edit on an existing skill. Use when the user says reflect.
disable-model-invocation: true
---

# Reflect

`<pstack>` is the pstack plugin root, `${CLAUDE_PLUGIN_ROOT}` (two folders above this file when that is not expanded). To run another pstack skill or `/pstack:<name>`, read `<pstack>/skills/<name>/SKILL.md` and follow it. The Skill tool refuses pstack skills.

Mine the current conversation for durable learnings, then route them into skill edits.

Invoke when the user says "reflect" or "/pstack:reflect". Skip when the conversation is trivial, off-topic, or already covered by an existing skill the parent followed correctly. One-offs are not learnings.

## 1. Locate the active transcript

Before fanning out, find this conversation's transcript in `~/.claude/projects/<slug>/`, where `<slug>` is the absolute workspace path with every `/` and `.` replaced by `-` (so `/Users/you/proj` is `-Users-you-proj`). Do not glob across `~/.claude/projects/*/`. That crosses workspace boundaries and reads private chats from unrelated projects.

```bash
ls -t ~/.claude/projects/<slug>/*.jsonl 2>/dev/null | head -10
```

The newest `.jsonl` directly in that folder is the current session. Subagent transcripts sit in `<session>/subagents/` and are not it. Confirm the match by reading the file's first `user` event. Take the file whose `message.content` (a string, or the `text` blocks of an array) contains the conversation's opening user prompt. If none matches, pass a tight digest of the session instead.

## 2. Spawn three reviewers in parallel

One message, three `Agent` calls, `subagent_type: "general-purpose"`. Reviewers need MCP access to look up the tickets, chat threads, and observability traces the transcript references, and `general-purpose` keeps the session's MCP tools.

Each reviewer and the synthesizer name a role line in the `pstack-models.md` rule and a default. Set `model` and `effort` from that line's value (`opus xhigh` is `model: "opus"`, `effort: "xhigh"`), or from the default if the rule or the line is missing. Leave `model` unset when the value is `auto` or `inherit-parent`. `model` takes only `opus`, `sonnet`, `haiku`, or `fable`. If the line names anything else, use the default and say so. Pick each subagent's effort level for the job, per the Subagents section of the **poteto-mode** skill.

| Lens | Role line | Default `model` | Prompt template |
|---|---|---|---|
| Judgment | `reflect judgment, divergent, synthesizer` | `opus xhigh` | `<pstack>/skills/reflect/references/judgment-reviewer.md` |
| Tooling | `reflect tooling` | `inherit-parent` | `<pstack>/skills/reflect/references/tooling-reviewer.md` |
| Divergent | `reflect judgment, divergent, synthesizer` | `opus xhigh` | `<pstack>/skills/reflect/references/divergent-reviewer.md` |

Pass each template verbatim, substituting the transcript path or digest where marked. Reviewers return findings in the `Agent` result.

## 3. Synthesize

One `Agent` call, `subagent_type: "general-purpose"`, `model` and `effort` from the `reflect judgment, divergent, synthesizer` line (default `opus xhigh`). It spot-verifies citations through MCP, and `general-purpose` keeps the session's MCP tools. Pass `<pstack>/skills/reflect/references/synthesizer.md` verbatim, with each reviewer's full output inlined where marked. It returns an Accepted / Rejected / Backlog list.

## 4. Structural enforcement check

Move any Accepted item that a lint rule, script, metadata flag, or runtime check would enforce more reliably to Backlog. See the **encode-lessons-in-structure** principle skill.

## 5. Apply

Present the synthesizer's full Accepted / Rejected / Backlog output and wait for explicit approval before applying any Accepted edit. The user picks the subset and may redirect routings. Skill changes affect every future agent in the org. Do not auto-apply.

File each Backlog item to your team's devex or backlog tracker without waiting. Only the Accepted list waits for approval.

Never edit a skill under `~/.claude/plugins/cache/`. Before approval, show its destination, `.claude/skills/<skill>/` or `~/.claude/skills/<skill>/`. After approval, copy the skill folder there and edit the copy. The copy appears as `/<skill>` beside `/pstack:<skill>`. Never open a PR or push.

Follow each approved row's Routing exactly:

- Trivial existing-skill edit (a one-line bullet, a tightened sentence, a stale fact corrected): the parent does it directly.
- Substantive existing-skill edit (a new section, a new pattern table, more than ~10 lines): hand to the `skill-creator` skill and run its draft / test / iterate loop. When it is not installed, follow `<pstack>/skills/poteto-mode/playbooks/authoring-a-skill.md` instead.
- `tune description: <skill path>` (the skill exists but didn't trigger when it should have): hand to `skill-creator` and run its description-optimization loop, or the authoring playbook when it is not installed.
- `new skill via create-skill: <kebab-name>`: hand creation to `skill-creator`, or the authoring playbook when it is not installed. Do not invent the shape ad hoc.

If your environment ships a SKILL.md validator, run it on every touched skill before declaring done.

## 6. Summarize for the user

Short list, no preamble:

- Edits applied: `<skill path>`. What changed, one line each.
- New skills created: `<skill path>`. One line each (rare).
- Backlog filed to the devex tracker: `<issue title>` (`<tags>`). One line each.
- Dropped: one line per rejected finding + reason from the synthesizer.
