# benny

benny gives you two claude code routines for slack issue reports. one triages each report. the other reproduces confirmed bugs and may prepare a small draft fix.

the files in this directory are dormant setup and routine sources. they do not appear as slash skills.

## set it up

1. point claude code at [`FOR_AGENTS.md`](./FOR_AGENTS.md) and name the target repository.
2. let setup merge this whole directory into the target at `.claude/automations/benny/`. it must preserve destination-only files and review conflicts instead of overwriting local edits.
3. let setup enable pstack in the target repository's `.claude/settings.json` for local sessions:

```json
{
	"extraKnownMarketplaces": {
		"pstack-rewire": {
			"source": { "source": "github", "repo": "matthew110703/pstack-rewire" }
		}
	},
	"enabledPlugins": {
		"pstack@pstack-rewire": true
	}
}
```

routine runs do not install plugins, so setup also vendors the shared pstack skills benny needs into `.claude/skills/`.

4. keep user-owned configuration outside the copied pack, for example in `.claude/benny/`. adapt [`configuration.example.yaml`](./templates/configuration.example.yaml) and [`feature-map.example.md`](./skills/reproduce-and-fix-issues/references/feature-map.example.md).
5. commit `.claude/settings.json`, the vendored `.claude/skills/` folders, `.claude/automations/benny/`, and any secret-free configuration before enabling either routine.
6. create each routine with `/schedule`, or update the existing ones there, and review it on its claude.ai page. wire a slack workflow that fires both routines' api triggers for each message in the source channel. then send a harmless test report and verify every source-channel post stays in the original thread.
