#!/usr/bin/env bash
# Multi-harness uninstaller for pstack-rewire (https://github.com/matthew110703/pstack-rewire).
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/uninstall.sh | bash
#   ./uninstall.sh [--target antigravity|claude|cursor|codex|all|<harness>] [--scope global|workspace|all]
set -euo pipefail

TARGET="${PSTACK_TARGET:-antigravity}"
SCOPE="${PSTACK_SCOPE:-}"
DEST="${PSTACK_DEST:-}"
ALL_TARGETS="antigravity claude cursor codex"

while [ $# -gt 0 ]; do
    case "$1" in
        -t|--target) TARGET="$2"; shift 2 ;;
        -s|--scope)  SCOPE="$2"; shift 2 ;;
        -d|--dest)   DEST="$2"; shift 2 ;;
        -h|--help)
            printf 'Usage: uninstall.sh [--target antigravity|claude|cursor|codex|all|<harness>] [--scope global|workspace|all] [--dest <path>]\n'
            exit 0
            ;;
        *)
            printf 'error: unknown option: %s\n' "$1" >&2
            exit 2
            ;;
    esac
done

TARGET="$(printf '%s' "$TARGET" | tr '[:upper:]' '[:lower:]')"

if [ -n "$DEST" ] && [ "$TARGET" = "all" ]; then
    printf 'error: --dest needs a single --target, not all\n' >&2
    exit 2
fi

preview_dest() {
    local harness="$1" sc="$2"
    if [ "$sc" = "workspace" ]; then
        case "$harness" in
            antigravity) printf '%s/.agents/plugins/pstack' "$PWD" ;;
            claude)      printf '%s/.claude/plugins/pstack' "$PWD" ;;
            cursor)      printf '%s/.cursor/plugins/pstack' "$PWD" ;;
            codex)       printf '%s/.codex/plugins/pstack' "$PWD" ;;
            *)           printf '%s/.%s/plugins/pstack' "$PWD" "$harness" ;;
        esac
        return
    fi
    case "$harness" in
        antigravity) printf '%s/.gemini/config/plugins/pstack' "$HOME" ;;
        claude)      printf '%s/.claude/plugins/pstack' "$HOME" ;;
        cursor)      printf '%s/.cursor/plugins/pstack' "$HOME" ;;
        codex)       printf '%s/.codex/plugins/pstack' "$HOME" ;;
        *)           printf '%s/.%s/plugins/pstack' "$HOME" "$harness" ;;
    esac
}

preview_label() {
    local harness="$1" sc="$2"
    if [ "$harness" = "claude" ]; then
        if [ "$sc" = "workspace" ]; then printf 'Claude Code project scope (%s)' "$PWD"; else printf 'Claude Code user scope'; fi
    elif [ "$harness" = "all" ]; then
        if [ "$sc" = "workspace" ]; then printf 'every harness, current folder (%s)' "$PWD"; else printf 'every harness, this device'; fi
    else
        preview_dest "$harness" "$sc"
    fi
}

# Claude Code loads plugins only from marketplaces, so the claude target uninstalls through the
# `claude plugin` CLI: the plugin, then that scope's marketplace declaration, then the marketplace
# itself once no scope still has pstack installed. It also removes a legacy folder copy.
remove_claude() {
    local label="$1"
    local plugin_id="pstack@pstack-rewire" marketplace="pstack-rewire" claude_scope="user"
    [ "$label" = "workspace" ] && claude_scope="project"
    local legacy_dir
    legacy_dir="$(preview_dest claude "$label")"
    if [ -d "$legacy_dir" ]; then
        rm -rf "$legacy_dir"
        printf 'Removed legacy folder copy at %s\n' "$legacy_dir"
    fi
    if ! command -v claude >/dev/null 2>&1; then
        printf 'The claude CLI was not found on PATH. In a Claude Code session, run: /plugin uninstall %s, then /plugin marketplace remove %s\n' "$plugin_id" "$marketplace"
        return
    fi
    if claude plugin uninstall "$plugin_id" --scope "$claude_scope" >/dev/null 2>&1; then
        printf 'Uninstalled pstack (claude, %s scope)\n' "$claude_scope"
    else
        printf 'pstack (claude, %s scope) is not installed\n' "$claude_scope"
    fi
    claude plugin marketplace remove "$marketplace" --scope "$claude_scope" >/dev/null 2>&1 || true
    if ! claude plugin list 2>/dev/null | grep -q "$plugin_id"; then
        if claude plugin marketplace remove "$marketplace" >/dev/null 2>&1; then
            printf 'Removed marketplace %s (no pstack install remains)\n' "$marketplace"
        fi
    fi
}

remove_target() {
    local harness="$1" label="$2"
    if [ "$harness" = "claude" ]; then
        remove_claude "$label"
        return
    fi
    local dir
    dir="$(preview_dest "$harness" "$label")"
    if [ -d "$dir" ]; then
        rm -rf "$dir"
        printf 'Uninstalled pstack (%s, %s) from %s\n' "$harness" "$label" "$dir"
    else
        printf 'pstack (%s, %s) not found at %s\n' "$harness" "$label" "$dir"
    fi
}

if [ -n "$DEST" ]; then
    if [ -d "$DEST" ]; then
        rm -rf "$DEST"
        printf 'Uninstalled pstack (%s, custom) from %s\n' "$TARGET" "$DEST"
    else
        printf 'pstack (%s, custom) not found at %s\n' "$TARGET" "$DEST"
    fi
    exit 0
fi

if [ -z "$SCOPE" ]; then
    CHOICE=""
    if [ -r /dev/tty ]; then
        printf '\nWhere would you like to uninstall pstack (%s) from?\n' "$TARGET" > /dev/tty
        printf '  [1] Global    - %s [default]\n' "$(preview_label "$TARGET" global)" > /dev/tty
        printf '  [2] Workspace - %s\n' "$(preview_label "$TARGET" workspace)" > /dev/tty
        printf '  [3] Both      - Remove from both Global and Workspace\n' > /dev/tty
        printf 'Select [1/2/3] (press Enter for 1): ' > /dev/tty
        read -r CHOICE < /dev/tty || CHOICE=""
    fi
    CHOICE="$(printf '%s' "$CHOICE" | tr '[:upper:]' '[:lower:]')"
    case "$CHOICE" in
        2|workspace|folder) SCOPE="workspace" ;;
        3|both|all)         SCOPE="all" ;;
        *)                  SCOPE="global" ;;
    esac
else
    SCOPE="$(printf '%s' "$SCOPE" | tr '[:upper:]' '[:lower:]')"
    [ "$SCOPE" = "folder" ] && SCOPE="workspace"
    [ "$SCOPE" = "both" ] && SCOPE="all"
fi

case "$SCOPE" in
    all)       LABELS="global workspace" ;;
    workspace) LABELS="workspace" ;;
    global)    LABELS="global" ;;
    *)
        printf 'error: invalid --scope "%s" (expected global, workspace, or all)\n' "$SCOPE" >&2
        exit 2
        ;;
esac

if [ "$TARGET" = "all" ]; then TARGETS="$ALL_TARGETS"; else TARGETS="$TARGET"; fi

for harness in $TARGETS; do
    for label in $LABELS; do
        remove_target "$harness" "$label"
    done
done
