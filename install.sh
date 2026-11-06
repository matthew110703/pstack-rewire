#!/usr/bin/env bash
# Multi-harness zero-clone installer & uninstaller for pstack-rewire (https://github.com/matthew110703/pstack-rewire).
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/install.sh | bash -s -- --uninstall
set -euo pipefail

REPO_SLUG="matthew110703/pstack-rewire"
TARGET="${PSTACK_TARGET:-antigravity}"
SCOPE="${PSTACK_SCOPE:-}"
ACTION="${PSTACK_ACTION:-}"
DEST="${PSTACK_DEST:-}"
BRANCH="${PSTACK_BRANCH:-main}"

while [ $# -gt 0 ]; do
    case "$1" in
        -t|--target)    TARGET="$2"; shift 2 ;;
        -s|--scope)     SCOPE="$2"; shift 2 ;;
        -d|--dest)      DEST="$2"; shift 2 ;;
        -b|--branch)    BRANCH="$2"; shift 2 ;;
        -u|--uninstall) ACTION="uninstall"; shift 1 ;;
        --update)       ACTION="install"; shift 1 ;;
        -h|--help)
            printf 'Usage: install.sh [--target antigravity|claude|cursor|codex|<harness>] [--scope global|workspace] [--update|--uninstall] [--dest <path>] [--branch <branch>]\n'
            exit 0
            ;;
        *)
            printf 'error: unknown option: %s\n' "$1" >&2
            exit 2
            ;;
    esac
done

TARGET="$(printf '%s' "$TARGET" | tr '[:upper:]' '[:lower:]')"

preview_dest() {
    local sc="$1"
    if [ "$sc" = "workspace" ]; then
        case "$TARGET" in
            antigravity) printf '%s/.agents/plugins/pstack' "$PWD" ;;
            claude)      printf 'Claude Code project scope (%s)' "$PWD" ;;
            cursor)      printf '%s/.cursor/plugins/pstack' "$PWD" ;;
            codex)       printf '%s/.codex/plugins/pstack' "$PWD" ;;
            *)           printf '%s/.%s/plugins/pstack' "$PWD" "$TARGET" ;;
        esac
        return
    fi
    case "$TARGET" in
        antigravity) printf '%s/.gemini/config/plugins/pstack' "$HOME" ;;
        claude)      printf 'Claude Code user scope' ;;
        cursor)      printf '%s/.cursor/plugins/pstack' "$HOME" ;;
        codex)       printf '%s/.codex/plugins/pstack' "$HOME" ;;
        *)           printf '%s/.%s/plugins/pstack' "$HOME" "$TARGET" ;;
    esac
}

if [ -z "$DEST" ] && [ -z "$SCOPE" ]; then
    GLOBAL_PREVIEW="$(preview_dest global)"
    WORKSPACE_PREVIEW="$(preview_dest workspace)"
    CHOICE=""
    if [ -r /dev/tty ]; then
        printf '\npstack (%s) Setup:\n' "$TARGET" > /dev/tty
        printf '  [1] Install / Update Global    - All projects on this device (%s) [default]\n' "$GLOBAL_PREVIEW" > /dev/tty
        printf '  [2] Install / Update Workspace - Current folder only (%s)\n' "$WORKSPACE_PREVIEW" > /dev/tty
        printf '  [3] Uninstall Global           - Remove from %s\n' "$GLOBAL_PREVIEW" > /dev/tty
        printf '  [4] Uninstall Workspace        - Remove from %s\n' "$WORKSPACE_PREVIEW" > /dev/tty
        printf 'Select [1-4] (press Enter for 1): ' > /dev/tty
        read -r CHOICE < /dev/tty || CHOICE=""
    fi
    CHOICE="$(printf '%s' "$CHOICE" | tr '[:upper:]' '[:lower:]')"
    case "$CHOICE" in
        2|workspace|folder|w) ACTION="install";   SCOPE="workspace" ;;
        3|u|uninstall)        ACTION="uninstall"; SCOPE="global" ;;
        4)                    ACTION="uninstall"; SCOPE="workspace" ;;
        *)                    [ -z "$ACTION" ] && ACTION="install"; SCOPE="global" ;;
    esac
else
    [ -z "$ACTION" ] && ACTION="install"
    ACTION="$(printf '%s' "$ACTION" | tr '[:upper:]' '[:lower:]')"
    case "$ACTION" in remove|delete|rm) ACTION="uninstall" ;; update|upgrade) ACTION="install" ;; esac
    [ -z "$SCOPE" ] && SCOPE="global"
    SCOPE="$(printf '%s' "$SCOPE" | tr '[:upper:]' '[:lower:]')"
    [ "$SCOPE" = "folder" ] && SCOPE="workspace"
    if [ "$SCOPE" != "global" ] && [ "$SCOPE" != "workspace" ]; then
        printf 'error: invalid --scope "%s" (expected global or workspace)\n' "$SCOPE" >&2
        exit 2
    fi
fi

# Claude Code loads plugins only from marketplaces, so the claude target installs
# through the `claude plugin` CLI instead of copying files.
if [ "$TARGET" = "claude" ] && [ -z "$DEST" ]; then
    MARKETPLACE="pstack-rewire"
    PLUGIN_ID="pstack@${MARKETPLACE}"
    if [ "$SCOPE" = "workspace" ]; then CLAUDE_SCOPE="project"; else CLAUDE_SCOPE="user"; fi
    if [ "$SCOPE" = "workspace" ]; then LEGACY_DIR="$PWD/.claude/plugins/pstack"; else LEGACY_DIR="$HOME/.claude/plugins/pstack"; fi
    if [ -d "$LEGACY_DIR" ]; then
        rm -rf "$LEGACY_DIR"
        printf 'Removed legacy folder copy at %s\n' "$LEGACY_DIR"
    fi
    if ! command -v claude >/dev/null 2>&1; then
        printf 'The claude CLI was not found on PATH. In a Claude Code session, run:\n'
        if [ "$ACTION" = "uninstall" ]; then
            printf '  /plugin uninstall %s\n  /plugin marketplace remove %s\n' "$PLUGIN_ID" "$MARKETPLACE"
        else
            printf '  /plugin marketplace add %s\n  /plugin install %s\n' "$REPO_SLUG" "$PLUGIN_ID"
        fi
        exit 0
    fi
    if [ "$ACTION" = "uninstall" ]; then
        if claude plugin uninstall "$PLUGIN_ID" --scope "$CLAUDE_SCOPE" >/dev/null 2>&1; then
            printf 'Uninstalled pstack (claude, %s scope)\n' "$CLAUDE_SCOPE"
        else
            printf 'pstack (claude, %s scope) is not installed\n' "$CLAUDE_SCOPE"
        fi
        # Drop this scope's marketplace declaration, and the marketplace itself once no scope still has pstack.
        claude plugin marketplace remove "$MARKETPLACE" --scope "$CLAUDE_SCOPE" >/dev/null 2>&1 || true
        if ! claude plugin list 2>/dev/null | grep -q "$PLUGIN_ID"; then
            claude plugin marketplace remove "$MARKETPLACE" >/dev/null 2>&1 && printf 'Removed marketplace %s (no pstack install remains)\n' "$MARKETPLACE"
        fi
        exit 0
    fi
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" 2>/dev/null && pwd || true)"
    if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/.claude-plugin/marketplace.json" ] && [ -d "$SCRIPT_DIR/claude" ]; then
        SOURCE="$SCRIPT_DIR"
    else
        SOURCE="$REPO_SLUG"
    fi
    # `marketplace add` is idempotent and records the declaration in the chosen scope's settings.
    claude plugin marketplace add "$SOURCE" --scope "$CLAUDE_SCOPE"
    claude plugin marketplace update "$MARKETPLACE"
    # `plugin install` is idempotent and records enabledPlugins in the chosen scope; `update` then pulls a newer version.
    claude plugin install "$PLUGIN_ID" --scope "$CLAUDE_SCOPE"
    claude plugin update "$PLUGIN_ID" --scope "$CLAUDE_SCOPE" || true
    printf 'Installed or updated pstack (claude, %s scope) from %s. Restart Claude Code or run /reload-plugins, then run /pstack:poteto-help.\n' "$CLAUDE_SCOPE" "$SOURCE"
    exit 0
fi

if [ -n "$DEST" ]; then
    TARGET_DIR="$DEST"
else
    TARGET_DIR="$(preview_dest "$SCOPE")"
fi

if [ "$ACTION" = "uninstall" ]; then
    if [ -d "$TARGET_DIR" ]; then
        rm -rf "$TARGET_DIR"
        printf 'Uninstalled pstack (%s, %s) from %s\n' "$TARGET" "$SCOPE" "$TARGET_DIR"
    else
        printf 'pstack (%s, %s) is not installed at %s\n' "$TARGET" "$SCOPE" "$TARGET_DIR"
    fi
    exit 0
fi

mkdir -p "$(dirname "$TARGET_DIR")"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" 2>/dev/null && pwd || true)"
if [ -n "$SCRIPT_DIR" ] && [ -d "$SCRIPT_DIR/$TARGET" ] && { [ -f "$SCRIPT_DIR/$TARGET/plugin.json" ] || [ -d "$SCRIPT_DIR/$TARGET/skills" ]; }; then
    rm -rf "$TARGET_DIR"
    cp -R "$SCRIPT_DIR/$TARGET" "$TARGET_DIR"
    printf 'Installed pstack (%s, %s, local checkout) -> %s\n' "$TARGET" "$SCOPE" "$TARGET_DIR"
else
    TARBALL_URL="https://github.com/${REPO_SLUG}/archive/refs/heads/${BRANCH}.tar.gz"
    TMP_DIR="$(mktemp -d)"
    trap 'rm -rf "$TMP_DIR"' EXIT
    printf 'Downloading pstack (%s) from GitHub (%s@%s)...\n' "$TARGET" "$REPO_SLUG" "$BRANCH"
    curl -fsSL "$TARBALL_URL" | tar -xz -C "$TMP_DIR"
    ROOT_DIR="$(find "$TMP_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
    if [ ! -d "$ROOT_DIR/$TARGET" ]; then
        AVAILABLE="$(find "$ROOT_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | tr '\n' ' ')"
        printf 'error: harness "%s" not found in %s. Available harnesses: %s\n' "$TARGET" "$REPO_SLUG" "$AVAILABLE" >&2
        exit 1
    fi
    rm -rf "$TARGET_DIR"
    cp -R "$ROOT_DIR/$TARGET" "$TARGET_DIR"
    printf 'Installed pstack (%s, %s) -> %s\n' "$TARGET" "$SCOPE" "$TARGET_DIR"
fi
