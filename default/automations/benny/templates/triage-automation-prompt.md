# Triage automation prompt

> Source material for the copied setup workflow. Paraphrase this intent into the prompt your platform's automation, Slack bot, or CI job runs, after confirming that the copied pack is committed on the branch that run checks out.

Read and follow `.agents/automations/benny/skills/triage-issue-reports/SKILL.md` for this run.

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

The creation intent should describe this as a new top-level report in the configured source Slack channel.

Treat the source channel and root thread timestamp as immutable. If either is missing or does not match configuration, stop without posting or writing to the issue tracker. If an earlier run for the same `message_ts` already acted on this thread, stop silently.

The committed operational file owns classification, attachment review, cause tracing, routing, dedupe, tracker writes, and the final verdict. Post no progress messages. Never post a root message in the source channel.

The coordinator is the only Slack poster. Any delegated worker must be read-only, return findings only, and receive an explicit ban on every Slack write action, including every Slack send, post, update, or reaction tool from any MCP server.

End the single verdict with exactly one configured marker:

```text
[benny:bug]
[benny:performance]
[benny:other]
```

A bug or performance marker may add `tracker=<URL>`.
