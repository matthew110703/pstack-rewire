# Reproduce routine prompt

> Source material for the copied setup workflow. Paraphrase this intent into the routine prompt the `schedule` skill saves, after confirming that the copied pack is committed on the default branch of the repository the routine clones.

Read and follow `.claude/automations/benny/skills/reproduce-and-fix-issues/SKILL.md` for this run.

Configuration source. Include this repository-relative path only when it is committed in the same target repository. Otherwise paraphrase the configured values. Never use a plugin source or cache path:

```text
{{BENNY_CONFIG_PATH}}
```

Trigger. The text of this run's API fire body, posted by the Slack workflow for each message in the source channel:

```json
{
	"source_channel_id": "<source channel ID>",
	"message_ts": "<message timestamp>",
	"thread_ts": "<thread timestamp, or empty>"
}
```

The Slack workflow fills these values on each fire. The routine prompt names the fields and fixes no values. If `thread_ts` is present and differs from `message_ts`, the message is a reply, not a top-level report. Stop silently.

The routine intent should describe this as a new top-level report in the configured source Slack channel. It should include the configured repository, default branch, issue tracker, control adapter, feature map, and draft pull request capability.

Treat the source channel and root thread timestamp as immutable. If either is missing or does not match configuration, stop without posting. If an earlier fire for the same `message_ts` already acted on this thread, stop silently.

Wait for a configured triage marker from the configured triage identity in this exact thread. Proceed only for `[benny:bug]` or `[benny:performance]`.

Require the configured control-adapter skill before attempting a repro. Reproduce the exact discriminating symptom twice through the real UI. Verify existing pull requests or commits without authoring over them. Attempt a bounded fix only after a confirmed repro and the operational file's fix gate.

The coordinator is the only Slack poster. Every child prompt must forbid `SendSlackMessage`, `PostToSlack`, `chat.postMessage`, every `mcp__*slack*` send, post, update, or reaction tool, and all other Slack writes. Children return findings only.

Never post a root message in the source channel.
