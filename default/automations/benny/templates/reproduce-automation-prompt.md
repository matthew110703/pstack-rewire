# Reproduce automation prompt

> Source material for the copied setup workflow. Paraphrase this intent into the prompt your platform's automation, Slack bot, or CI job runs, after confirming that the copied pack is committed on the branch that run checks out.

Read and follow `.agents/automations/benny/skills/reproduce-and-fix-issues/SKILL.md` for this run.

Configuration source. Include this repository-relative path only when it is committed in the same target repository. Otherwise paraphrase the configured values. Never use a plugin source or cache path:

```text
{{BENNY_CONFIG_PATH}}
```

Trigger. The Slack message this run receives, passed in by the automation, bot, or CI job for each message in the source channel:

```json
{
	"source_channel_id": "{{SLACK_CHANNEL_ID}}",
	"message_ts": "{{SLACK_MESSAGE_TS}}",
	"thread_ts": "{{SLACK_THREAD_TS_OR_EMPTY}}"
}
```

The trigger fills these values on each run. If `thread_ts` is present and differs from `message_ts`, the message is a reply, not a top-level report. Stop silently.

The creation intent should describe this as a new top-level report in the configured source Slack channel. It should include the configured repository, default branch, issue tracker, control adapter, feature map, and draft pull request capability.

Treat the source channel and root thread timestamp as immutable. If either is missing or does not match configuration, stop without posting. If an earlier run for the same `message_ts` already acted on this thread, stop silently.

Wait for a configured triage marker from the configured triage identity in this exact thread. Proceed only for `[benny:bug]` or `[benny:performance]`.

Require the configured control-adapter skill before attempting a repro. Reproduce the exact discriminating symptom twice through the real UI. Verify existing pull requests or commits without authoring over them. Attempt a bounded fix only after a confirmed repro and the operational file's fix gate.

The coordinator is the only Slack poster. Every child prompt must forbid `SendSlackMessage`, `PostToSlack`, `chat.postMessage`, every Slack send, post, update, or reaction tool from any MCP server, and all other Slack writes. Children return findings only.

Never post a root message in the source channel.
