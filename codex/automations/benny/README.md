# benny

benny gives you two chatgpt scheduled tasks for slack issue reports. one triages each report. the other reproduces confirmed bugs and may prepare a small draft fix. each task starts from a slack event trigger for new messages in your issue channel.

the files in this directory are dormant setup and task sources. they do not appear as `$` skills.

## set it up

1. point codex at [`FOR_AGENTS.md`](./FOR_AGENTS.md) and name the target repository.
2. let setup merge this whole directory into the target at `.agents/automations/benny/`. it must preserve destination-only files and review conflicts instead of overwriting local edits.
3. task runs do not install plugins, so let setup vendor the shared pstack skills benny needs into the target repository's `.agents/skills/`, record the pstack version in `.agents/automations/benny/VENDORED.md`, and copy the `benny-reader` and `benny-coder` worker agents into `.codex/agents/`. trust the target repository in codex so it loads them.
4. keep user-owned configuration outside the copied pack, for example in `.agents/benny/`. adapt [`configuration.example.yaml`](./templates/configuration.example.yaml) and [`feature-map.example.md`](./skills/reproduce-and-fix-issues/references/feature-map.example.md).
5. commit the vendored `.agents/skills/` folders, `.codex/agents/benny-*.toml`, `.agents/automations/benny/`, and any secret-free configuration before enabling either task.
6. create each task in chatgpt on the web under scheduled tasks, paused, with a slack event trigger for the source channel, or update the existing ones in place. then send a harmless test report and verify every source-channel post stays in the original thread.
