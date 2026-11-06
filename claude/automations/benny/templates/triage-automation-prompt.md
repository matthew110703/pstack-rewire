# Triage routine prompt

> Source material for the copied setup workflow. Paraphrase this intent into the routine prompt the `schedule` skill saves, after confirming that the copied pack is committed on the default branch of the repository the routine clones.

Read and follow `.claude/automations/benny/skills/triage-issue-reports/SKILL.md` for this run.

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

The routine intent should describe this as a new top-level report in the configured source Slack channel.

Treat the source channel and root thread timestamp as immutable. If either is missing or does not match configuration, stop without posting or writing to the issue tracker. If an earlier fire for the same `message_ts` already acted on this thread, stop silently.

The committed operational file owns classification, attachment review, cause tracing, routing, dedupe, tracker writes, and the final verdict. Post no progress messages. Never post a root message in the source channel.

The coordinator is the only Slack poster. Any delegated worker must be read-only, return findings only, and receive an explicit ban on every Slack write action, including every `mcp__*slack*` send, post, update, or reaction tool.

End the single verdict with exactly one configured marker:

```text
[benny:bug]
[benny:performance]
[benny:other]
```

A bug or performance marker may add `tracker=<URL>`.
