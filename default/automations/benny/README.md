# benny

benny gives you two automations for slack issue reports. one triages each report. the other reproduces confirmed bugs and may prepare a small draft fix.

the files in this directory are dormant setup and automation sources. they do not appear as slash skills.

## set it up

1. point your agent at [`FOR_AGENTS.md`](./FOR_AGENTS.md) and name the target repository.
2. let setup merge this whole directory into the target at `.agents/automations/benny/`. it must preserve destination-only files and review conflicts instead of overwriting local edits.
3. let setup install the shared pstack skills into the target repository's `.agents/skills/`, either from the target root:

```sh
curl -fsSL https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/install.sh | bash -s -- --target default --scope workspace
```

or as vendored copies of the skill folders benny needs. a fresh agent session rooted in the target repository must list them.

4. keep user-owned configuration outside the copied pack, for example in `.agents/benny/`. adapt [`configuration.example.yaml`](./templates/configuration.example.yaml) and [`feature-map.example.md`](./skills/reproduce-and-fix-issues/references/feature-map.example.md).
5. commit the `.agents/skills/` folders, `.agents/automations/benny/`, and any secret-free configuration before enabling either automation.
6. run triage and repro with your platform's automation or scheduler, a slack bot that runs a headless agent, or ci. each run receives the slack message (channel, ts, thread_ts). create each automation disabled, or update the existing ones in place. then send a harmless test report and verify every source-channel post stays in the original thread.
