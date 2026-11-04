# pstack-rewire

**Multi-harness ports of [`pstack`](https://github.com/cursor/plugins/tree/main/pstack) (`v0.15.36`) across modern agentic coding platforms.**

> *"If you want to go fast, go deep first. pstack helps you write less, higher-quality code with rigorous agent workflows, 23 playbooks, and 24 engineering principles."*

`pstack-rewire` maintains the upstream [`cursor/`](./cursor) plugin alongside native, zero-compromise ports for **Google Antigravity** ([`antigravity/`](./antigravity)) and future agentic harnesses (`claude/`, `codex/`, etc.). Each harness folder is a complete, standalone plugin bundle adapted to that platform's native subagent, scheduling, verification, and transcript primitives.

---

## Harness Matrix

| Harness Directory | Target Flag (`-Target` / `--target`) | Default Global Install Path | Status | Documentation |
| :--- | :--- | :--- | :--- | :--- |
| **[`antigravity/`](./antigravity)** | `antigravity` *(default)* | `~/.gemini/config/plugins/pstack` | **Ready (`v0.15.36`)** | [Antigravity README](./antigravity/README.md) · [Harness Spec](./antigravity/docs/harness/antigravity.md) · [User Guide](./antigravity/docs/guide/README.md) |
| **[`cursor/`](./cursor)** | `cursor` | `~/.cursor/plugins/pstack` | **Upstream Baseline (`v0.15.36`)** | [Cursor README](./cursor/README.md) · [User Guide](./cursor/docs/guide/README.md) |
| **`claude/`** *(planned)* | `claude` | `~/.claude/plugins/pstack` | Planned | [Claude Code Harness Spec](./antigravity/docs/harness/claude-code.md) |
| **`codex/`** *(planned)* | `codex` | `~/.codex/plugins/pstack` | Planned | — |

---

## Zero-Clone Installation (No `git clone` Required)

You can install `pstack` on any device with a single command. The installer prompts you interactively to choose between **Global** (`~/.gemini/config/plugins/pstack`) or **Workspace / Current Folder** (`.agents/plugins/pstack`), downloads the repository archive to a temporary directory, extracts **only** the target harness folder (`antigravity` by default), installs it, and cleans up automatically.

### 1. Install for Google Antigravity (Default)

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/install.ps1 | iex
```

**macOS / Linux (Bash / Zsh):**
```bash
curl -fsSL https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/install.sh | bash
```

**Or ask Antigravity Chat directly on any new machine:**
```text
Run `irm https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/install.ps1 | iex` (or `curl -fsSL https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/install.sh | bash` on macOS/Linux) to install the pstack plugin into ~/.gemini/config/plugins/pstack.
```

---

### 2. Install for Other Harnesses or Workspace Scope

Both `install.ps1` and `install.sh` are **target-aware** (`antigravity`, `claude`, `cursor`, `codex`, or any future `<harness>/` directory added to this repository) and support `global` or `workspace` scope:

**Windows (PowerShell):**
```powershell
# Remote one-liner for a specific target or workspace scope:
$env:PSTACK_TARGET="antigravity"; $env:PSTACK_SCOPE="workspace"; irm https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/install.ps1 | iex

# Or from a local checkout:
.\install.ps1 -Target antigravity -Scope global
.\install.ps1 -Target claude -Scope global
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

### 3. Uninstall / Removal

You can uninstall `pstack` interactively (using options `[3]` / `[4]` in `install.ps1` / `install.sh`, or via the dedicated `uninstall.ps1` / `uninstall.sh` scripts):

**Windows (PowerShell):**
```powershell
# Interactive uninstaller (asks Global, Workspace, or Both):
irm https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/uninstall.ps1 | iex

# Or from a local checkout:
.\uninstall.ps1 -Target antigravity -Scope global
.\install.ps1 -Uninstall -Scope workspace
```

**macOS / Linux:**
```bash
# Interactive uninstaller (asks Global, Workspace, or Both):
curl -fsSL https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/uninstall.sh | bash

# Non-interactive one-liner:
curl -fsSL https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/uninstall.sh | bash -s -- --target antigravity --scope all
```

---

## Adding a Future Harness Port (e.g., `claude/`, `codex/`)

This repository is designed so new agentic workflow ports drop in cleanly without breaking existing harnesses or installers:

1. **Create a top-level `<harness>/` folder** (e.g., `claude/`) at the repository root containing that platform's manifest, `skills/` (all 58 skills + 23 playbooks), `agents/` (`poteto-agent`, `comment-sicko`, and read-only explorer equivalents), `rules/`, and `automations/benny/`.
2. **Add a harness mapping specification** at `<harness>/docs/harness/<harness>.md` documenting how subagent spawning, model routing, worktree isolation, recurring loops, and transcript paths map to that harness.
3. **Zero installer changes required**: `install.ps1` and `install.sh` automatically resolve any top-level `<harness>/` directory when invoked with `-Target <harness>` / `--target <harness>`.

---

## License

MIT — Original `pstack` authored by [Lauren Tan (poteto)](https://github.com/cursor/plugins/tree/main/pstack). Antigravity & multi-harness rewire maintained by [matthew110703](https://github.com/matthew110703/pstack-rewire).
