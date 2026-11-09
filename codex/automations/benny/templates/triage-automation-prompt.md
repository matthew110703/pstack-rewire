# Triage task prompt

> Source material for the copied setup workflow. Paraphrase this intent into the prompt of a ChatGPT Scheduled task, after confirming that the copied pack is committed on the default branch of the repository the task's environment checks out.

Read and follow `.agents/automations/benny/skills/triage-issue-reports/SKILL.md` for this run.

Configuration source. Include this repository-relative path only when it is committed in the same target repository. Otherwise paraphrase the configured values. Never use a plugin source or cache path:

```text
{{BENNY_CONFIG_PATH}}
```

Trigger. The new Slack message from the task's event trigger, a new message in the source channel:

```json
{
	"channel": "<source channel ID>",
	"ts": "<message timestamp>",
	"thread_ts": "<thread timestamp, or empty>"
}
```

The Slack event fills these values on each run. The task prompt names the fields and fixes no values. If `thread_ts` is present and differs from `ts`, the message is a reply, not a top-level report. Stop silently.

The task intent should describe this as a new top-level report in the configured source Slack channel.

Treat the source channel and root thread timestamp as immutable. If either is missing or does not match configuration, stop without posting or writing to the issue tracker. If an earlier event for the same `ts` already acted on this thread, stop silently.

Use the Slack and tracker connectors available to the task. Waits inside the run poll the source thread with `sleep` between reads. If the run's remaining time cannot cover a configured wait, fail closed.

The committed operational file owns classification, attachment review, cause tracing, routing, dedupe, tracker writes, and the final verdict. Post no progress messages. Never post a root message in the source channel.

The coordinator is the only Slack poster. Any delegated worker must be read-only, return findings only, and receive an explicit ban on every Slack write action, including every Slack connector or `mcp__*slack*` send, post, update, or reaction tool.

End the single verdict with exactly one configured marker:

```text
[benny:bug]
[benny:performance]
[benny:other]
```

A bug or performance marker may add `tracker=<URL>`.
