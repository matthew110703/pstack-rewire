# pstack-rewire

**Multi-harness ports of [`pstack`](https://github.com/cursor/plugins/tree/main/pstack) (`v0.15.36`) across modern agentic coding platforms.**

> *"If you want to go fast, go deep first. pstack helps you write less, higher-quality code with rigorous agent workflows, 23 playbooks, and 24 engineering principles."*

`pstack-rewire` maintains the upstream [`cursor/`](./cursor) plugin alongside native, zero-compromise ports for **Google Antigravity** ([`antigravity/`](./antigravity)), **Claude Code** ([`claude/`](./claude)), **OpenAI Codex** ([`codex/`](./codex)), and a harness-neutral **default** port ([`default/`](./default)) for any agent that reads open-standard Agent Skills. Each harness folder is a complete, standalone plugin bundle adapted to that platform's native subagent, scheduling, verification, and transcript primitives.

---

## Harness Matrix

| Harness Directory | Target Flag (`-Target` / `--target`) | Default Global Install Path | Status | Documentation |
| :--- | :--- | :--- | :--- | :--- |
| **[`antigravity/`](./antigravity)** | `antigravity` *(default)* | `~/.gemini/config/plugins/pstack` | **Ready (`v0.15.36`)** | [Antigravity README](./antigravity/README.md) · [Harness Spec](./antigravity/docs/harness/antigravity.md) · [User Guide](./antigravity/docs/guide/README.md) |
| **[`cursor/`](./cursor)** | `cursor` | `~/.cursor/plugins/pstack` | **Upstream Baseline (`v0.15.36`)** | [Cursor README](./cursor/README.md) · [User Guide](./cursor/docs/guide/README.md) |
| **[`claude/`](./claude)** | `claude` | Claude Code marketplace `pstack-rewire` (user scope) | **Ready (`v0.15.36`)** | [Claude Code README](./claude/README.md) · [Port Notes](./claude/docs/harness/claude-code.md) · [User Guide](./claude/docs/guide/README.md) |
| **[`codex/`](./codex)** | `codex` | Codex plugin `pstack@pstack-rewire-codex` | **Ready (`v0.15.36`)** | [Codex README](./codex/README.md) · [Port Notes](./codex/docs/harness/codex.md) · [User Guide](./codex/docs/guide/README.md) |
| **[`default/`](./default)** | `default` | `~/.agents/skills` (any agent that reads Agent Skills) | **Ready (`v0.15.36`)** | [README](./default/README.md) · [Port Notes](./default/docs/harness/default.md) · [User Guide](./default/docs/guide/README.md) |

---

## Zero-Clone Installation (No `git clone` Required)

One command installs, updates, or removes pstack for every agent on your machine. With no `--target`, the installer detects which agents you have and asks:

```bash
curl -fsSL https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/install.sh | bash
```
```powershell
irm https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/install.ps1 | iex
```

```text
pstack: [1] Install / update  [2] Uninstall  (Enter = 1): 1

pstack: choose agents (detected ones are checked)
  [x] 1  Claude Code                        claude, ~/.claude
  [x] 2  OpenAI Codex                       codex, ~/.codex
  [x] 3  Google Antigravity                 agy, ~/.gemini/antigravity
  [ ] 4  Cursor                             not found
  [x] 5  Other agents via .agents/skills    gemini, opencode
Enter = checked ones, or type numbers (e.g. 1,3), "a" = all, "q" = quit:
Install for: [1] All projects on this device (global)  [2] This folder only (...)  (Enter = 1):
```

- **Detection:** `claude`, `codex`, `agy`/`antigravity`, and `cursor` on `PATH` or their home folders (`~/.claude`, `~/.codex`, `~/.gemini/antigravity`, `~/.cursor`). "Other agents" means Gemini CLI, OpenCode, Copilot, Amp, Goose, Factory, Junie, or Kiro, which all read the open-standard [`default/`](./default) skills from `.agents/skills`.
- **Uninstall** lists only the agents pstack is installed for. With one, it removes it directly; with several, it asks which (all checked).
- **No terminal** (CI, a piped install with no TTY): it installs into every detected agent at global scope, or uninstalls from every agent pstack is installed for. `--yes` does the same on purpose.
- **Skip the questions** with flags: `--target claude,codex` (or `all`), `--scope global|workspace`, `--update`, `--uninstall`, `--force`, and `--list` to see detection and install status. PowerShell takes `-Target`, `-Scope`, `-Update`, `-Uninstall`, `-Force`, `-Yes`, `-List`, or the `PSTACK_TARGET` / `PSTACK_SCOPE` / `PSTACK_ACTION` env vars for `irm | iex`.

```bash
curl -fsSL https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/install.sh | bash -s -- --list
curl -fsSL https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/install.sh | bash -s -- --target claude,codex --scope global
curl -fsSL https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/install.sh | bash -s -- --uninstall
```

The sections below show each agent's specifics and its non-interactive command.

### 1. Install for Google Antigravity

```bash
curl -fsSL https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/install.sh | bash -s -- --target antigravity
```
```powershell
$env:PSTACK_TARGET="antigravity"; irm https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/install.ps1 | iex
```

Global installs go to `~/.gemini/config/plugins/pstack`, workspace installs to `.agents/plugins/pstack`.

---

### 2. Install for Claude Code

Claude Code loads plugins only from a marketplace, so this repository is also a Claude Code marketplace ([`.claude-plugin/marketplace.json`](./.claude-plugin/marketplace.json), name `pstack-rewire`, serving [`claude/`](./claude)). For `--target claude`, the installers run the `claude` CLI instead of copying files: `claude plugin marketplace add` then `claude plugin install pstack@pstack-rewire`, at `--scope user` (Global) or `--scope project` (Workspace). Re-running updates the marketplace and the plugin.

**Inside Claude Code (any OS):**
```text
/plugin marketplace add matthew110703/pstack-rewire
/plugin install pstack@pstack-rewire
```

**From a terminal:**
```bash
# macOS / Linux
curl -fsSL https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/install.sh | bash -s -- --target claude
curl -fsSL https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/install.sh | bash -s -- --target claude --scope workspace

# Or directly with the claude CLI
claude plugin marketplace add matthew110703/pstack-rewire
claude plugin install pstack@pstack-rewire --scope user
```
```powershell
# Windows (PowerShell)
$env:PSTACK_TARGET="claude"; irm https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/install.ps1 | iex
```

**Update:**
```bash
# Re-run the installer (same scope as before)
curl -fsSL https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/install.sh | bash -s -- --target claude --update
# or directly with the claude CLI
claude plugin marketplace update pstack-rewire && claude plugin update pstack@pstack-rewire
```
```powershell
$env:PSTACK_TARGET="claude"; $env:PSTACK_ACTION="update"; irm https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/install.ps1 | iex
```
Then restart Claude Code or run `/reload-plugins`. To update automatically, run `/plugin`, open **Marketplaces**, select `pstack-rewire`, and enable auto-update.

Uninstalling the claude target removes the plugin and that scope's marketplace declaration, then the `pstack-rewire` marketplace itself once no scope still has pstack installed. If the `claude` CLI is not on `PATH`, the installer prints the `/plugin` commands instead. Start a new session after installing, then run `/pstack:setup-pstack` and `/pstack:poteto-help`. Claude Code namespaces plugin commands, so every pstack command is `/pstack:<name>`. Prerequisites: `gh`, plus `bun` and `node` for the `watch-pr` and `statechart` scripts.

**Uninstall:**
```bash
curl -fsSL https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/uninstall.sh | bash -s -- --target claude --scope all
# or: claude plugin uninstall pstack@pstack-rewire --scope user && claude plugin marketplace remove pstack-rewire
```
```powershell
$env:PSTACK_TARGET="claude"; $env:PSTACK_SCOPE="all"; irm https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/uninstall.ps1 | iex
```

---

### 3. Install for OpenAI Codex

This repository is also a Codex marketplace ([`.agents/plugins/marketplace.json`](./.agents/plugins/marketplace.json), name `pstack-rewire-codex`, serving [`codex/`](./codex)). Codex plugins install per user, so `--scope global` installs the plugin with the `codex` CLI, and `--scope workspace` copies the skills into the current project's `.agents/skills/`. Both copy pstack's two agents (`poteto-agent`, `comment-sicko`) into Codex's agents folder and offer to set `[agents] max_depth = 2`.

```bash
# Inside a terminal with the codex CLI (npm i -g @openai/codex)
codex plugin marketplace add matthew110703/pstack-rewire
codex plugin add pstack@pstack-rewire-codex

# Or with the installer (also installs the agents)
curl -fsSL https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/install.sh | bash -s -- --target codex
curl -fsSL https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/install.sh | bash -s -- --target codex --scope workspace
```
```powershell
$env:PSTACK_TARGET="codex"; irm https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/install.ps1 | iex
```

Start a new Codex session and type `$pstack:poteto-help` (or `$poteto-help` for a workspace install). **Update:** rerun the installer with `--update`, or `codex plugin marketplace upgrade pstack-rewire-codex && codex plugin add pstack@pstack-rewire-codex`. **Uninstall:** `uninstall.sh --target codex`, which also removes pstack's agents, the `pstack-models` block in `~/.codex/AGENTS.md`, and any `max_depth` change it made.

---

### 4. Install for any agent (default port)

[`default/`](./default) uses only open standards: [Agent Skills](https://agentskills.io) folders in `.agents/skills/`, `AGENTS.md`, and an [agent-plugins.org](https://agent-plugins.org) `plugin.json`. Codex, Gemini CLI, GitHub Copilot, Cursor, OpenCode, Amp, Goose, Junie, Roo, Windsurf, and Factory read `.agents/skills/`. The installer copies the skills there and records them in `.agents/.pstack-manifest-default`, so uninstall removes only what pstack installed. It refuses to replace a same-named skill you already have unless you pass `--force`, which backs yours up first.

```bash
curl -fsSL https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/install.sh | bash -s -- --target default                    # ~/.agents/skills
curl -fsSL https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/install.sh | bash -s -- --target default --scope workspace  # ./.agents/skills

# Or with the skills CLI (point it at default/skills, not the repo root, which holds every port)
npx skills add https://github.com/matthew110703/pstack-rewire/tree/main/default/skills
```
```powershell
$env:PSTACK_TARGET="default"; irm https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/install.ps1 | iex
```

**Update:** rerun with `--update`. **Uninstall:** `uninstall.sh --target default`.

---

### 5. Install for Other Harnesses or Workspace Scope

Both `install.ps1` and `install.sh` are **target-aware** (`antigravity`, `claude`, `cursor`, `codex`, `default`, or any future `<harness>/` directory added to this repository) and support `global` or `workspace` scope:

**Windows (PowerShell):**
```powershell
# Remote one-liner for a specific target or workspace scope:
$env:PSTACK_TARGET="antigravity"; $env:PSTACK_SCOPE="workspace"; irm https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/install.ps1 | iex

# Or from a local checkout:
.\install.ps1 -Target antigravity -Scope global
.\install.ps1 -Target claude -Scope global   # runs the claude CLI (see section 2)
```

**macOS / Linux:**
```bash
# Remote one-liner with flags:
curl -fsSL https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/install.sh | bash -s -- --target antigravity --scope workspace
curl -fsSL https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/install.sh | bash -s -- --target claude --scope global

# Or from a local checkout:
./install.sh --target antigravity --scope global
```

---

### 6. Uninstall / Removal

`install.sh --uninstall` (or `install.ps1 -Uninstall`) removes pstack. With no `--target` it lists the agents pstack is installed for and asks which to remove when there are several. `uninstall.sh` / `uninstall.ps1` are kept as shortcuts that run the same thing:

**Windows (PowerShell):**
```powershell
# Interactive uninstaller (asks Global, Workspace, or Both):
irm https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/uninstall.ps1 | iex

# Or from a local checkout:
.\uninstall.ps1 -Target antigravity -Scope global
.\uninstall.ps1 -Target all -Scope all   # every harness, global and workspace
.\install.ps1 -Uninstall -Scope workspace
```

**macOS / Linux:**
```bash
# Interactive uninstaller (asks Global, Workspace, or Both):
curl -fsSL https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/uninstall.sh | bash

# Non-interactive one-liner:
curl -fsSL https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/uninstall.sh | bash -s -- --target antigravity --scope all

# Remove pstack from every harness (antigravity, claude, cursor, codex, default), global and workspace:
curl -fsSL https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/uninstall.sh | bash -s -- --target all --scope all
```

---

## Adding a Future Harness Port

This repository is designed so new agentic workflow ports drop in cleanly without breaking existing harnesses or installers:

1. **Create a top-level `<harness>/` folder** at the repository root containing that platform's manifest, `skills/` (all 58 skills + 23 playbooks), `agents/` (`poteto-agent`, `comment-sicko`, and read-only explorer equivalents), `rules/`, and `automations/benny/`.
2. **Add a harness mapping specification** at `<harness>/docs/harness/<harness>.md` documenting how subagent spawning, model routing, worktree isolation, recurring loops, and transcript paths map to that harness.
3. **Register it in the installers**: add the id to `HARNESSES` in `install.sh` (and `$Harnesses` in `install.ps1`), with a label, detection evidence, and install-status check. A folder-copy harness needs nothing else, because `run_folder` / `Invoke-Folder` copies the `<harness>/` folder.

The `claude/` and `codex/` ports are the exceptions to plain folder copies: both harnesses install plugins from a marketplace, so `--target claude` goes through `claude plugin` and the root `.claude-plugin/marketplace.json`, and `--target codex` through `codex plugin` and the root `.agents/plugins/marketplace.json`. The ports are regenerated from `cursor/` with the scripts in [`tools/ports/`](./tools/ports) plus hand edits recorded in each port's `docs/harness/` notes.

---

## License

MIT — Original `pstack` authored by [Lauren Tan (poteto)](https://github.com/cursor/plugins/tree/main/pstack). Antigravity, Claude Code, Codex & multi-harness rewire maintained by [matthew110703](https://github.com/matthew110703/pstack-rewire).
