# Reproduce task prompt

> Source material for the copied setup workflow. Paraphrase this intent into the prompt of a ChatGPT Scheduled task, after confirming that the copied pack is committed on the default branch of the repository the task's environment checks out.

Read and follow `.agents/automations/benny/skills/reproduce-and-fix-issues/SKILL.md` for this run.

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

The task intent should describe this as a new top-level report in the configured source Slack channel. It should include the configured repository, default branch, issue tracker, control adapter, feature map, and draft pull request capability.

Treat the source channel and root thread timestamp as immutable. If either is missing or does not match configuration, stop without posting. If an earlier event for the same `ts` already acted on this thread, stop silently.

Use the Slack and tracker connectors available to the task, and `gh pr create --draft` in the task's environment. Waits inside the run poll the source thread with `sleep` between reads. If the run's remaining time cannot cover a configured wait or budget, fail closed.

Wait for a configured triage marker from the configured triage identity in this exact thread. Proceed only for `[benny:bug]` or `[benny:performance]`.

Require the configured control-adapter skill before attempting a repro. Reproduce the exact discriminating symptom twice through the real UI. Verify existing pull requests or commits without authoring over them. Attempt a bounded fix only after a confirmed repro and the operational file's fix gate.

The coordinator is the only Slack poster. Every child prompt must forbid `SendSlackMessage`, `PostToSlack`, `chat.postMessage`, every Slack connector or `mcp__*slack*` send, post, update, or reaction tool, and all other Slack writes. Children return findings only.

Never post a root message in the source channel.
