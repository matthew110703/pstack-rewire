#!/usr/bin/env bash
# Multi-harness uninstaller for pstack-rewire (https://github.com/matthew110703/pstack-rewire).
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/uninstall.sh | bash
#   ./uninstall.sh [--target antigravity] [--scope global|workspace|all]
set -euo pipefail

TARGET="${PSTACK_TARGET:-antigravity}"
SCOPE="${PSTACK_SCOPE:-}"
DEST="${PSTACK_DEST:-}"

while [ $# -gt 0 ]; do
    case "$1" in
        -t|--target) TARGET="$2"; shift 2 ;;
        -s|--scope)  SCOPE="$2"; shift 2 ;;
        -d|--dest)   DEST="$2"; shift 2 ;;
        -h|--help)
            printf 'Usage: uninstall.sh [--target antigravity|claude|cursor|codex|<harness>] [--scope global|workspace|all] [--dest <path>]\n'
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
            claude)      printf '%s/.claude/plugins/pstack' "$PWD" ;;
            cursor)      printf '%s/.cursor/plugins/pstack' "$PWD" ;;
            codex)       printf '%s/.codex/plugins/pstack' "$PWD" ;;
            *)           printf '%s/.%s/plugins/pstack' "$PWD" "$TARGET" ;;
        esac
        return
    fi
    case "$TARGET" in
        antigravity) printf '%s/.gemini/config/plugins/pstack' "$HOME" ;;
        claude)      printf '%s/.claude/plugins/pstack' "$HOME" ;;
        cursor)      printf '%s/.cursor/plugins/pstack' "$HOME" ;;
        codex)       printf '%s/.codex/plugins/pstack' "$HOME" ;;
        *)           printf '%s/.%s/plugins/pstack' "$HOME" "$TARGET" ;;
    esac
}

remove_dir() {
    local dir="$1"
    local label="$2"
    if [ -d "$dir" ]; then
        rm -rf "$dir"
        printf 'Uninstalled pstack (%s, %s) from %s\n' "$TARGET" "$label" "$dir"
    else
        printf 'pstack (%s, %s) not found at %s\n' "$TARGET" "$label" "$dir"
    fi
}

if [ -n "$DEST" ]; then
    remove_dir "$DEST" "custom"
    exit 0
fi

GLOBAL_PREVIEW="$(preview_dest global)"
WORKSPACE_PREVIEW="$(preview_dest workspace)"

if [ -z "$SCOPE" ]; then
    CHOICE=""
    if [ -r /dev/tty ]; then
        printf '\nWhere would you like to uninstall pstack (%s) from?\n' "$TARGET" > /dev/tty
        printf '  [1] Global    - %s [default]\n' "$GLOBAL_PREVIEW" > /dev/tty
        printf '  [2] Workspace - %s\n' "$WORKSPACE_PREVIEW" > /dev/tty
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
    all)
        remove_dir "$GLOBAL_PREVIEW" "global"
        remove_dir "$WORKSPACE_PREVIEW" "workspace"
        ;;
    workspace)
        remove_dir "$WORKSPACE_PREVIEW" "workspace"
        ;;
    *)
        remove_dir "$GLOBAL_PREVIEW" "global"
        ;;
esac
