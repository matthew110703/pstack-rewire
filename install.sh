#!/usr/bin/env bash
# Multi-harness zero-clone installer for pstack-rewire (https://github.com/matthew110703/pstack-rewire).
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/install.sh | bash -s -- --target claude --scope global
# Prompts interactively for installation scope (Global vs Workspace/Folder) unless --scope or PSTACK_SCOPE is set.
set -euo pipefail

REPO_SLUG="matthew110703/pstack-rewire"
TARGET="${PSTACK_TARGET:-antigravity}"
SCOPE="${PSTACK_SCOPE:-}"
DEST="${PSTACK_DEST:-}"
BRANCH="${PSTACK_BRANCH:-main}"

while [ $# -gt 0 ]; do
    case "$1" in
        -t|--target) TARGET="$2"; shift 2 ;;
        -s|--scope)  SCOPE="$2"; shift 2 ;;
        -d|--dest)   DEST="$2"; shift 2 ;;
        -b|--branch) BRANCH="$2"; shift 2 ;;
        -h|--help)
            printf 'Usage: install.sh [--target antigravity|claude|cursor|codex|<harness>] [--scope global|workspace] [--dest <path>] [--branch <branch>]\n'
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

if [ -z "$DEST" ] && [ -z "$SCOPE" ]; then
    GLOBAL_PREVIEW="$(preview_dest global)"
    WORKSPACE_PREVIEW="$(preview_dest workspace)"
    CHOICE=""
    if [ -r /dev/tty ]; then
        printf '\nWhere would you like to install pstack (%s)?\n' "$TARGET" > /dev/tty
        printf '  [1] Global    - All projects on this device (%s) [default]\n' "$GLOBAL_PREVIEW" > /dev/tty
        printf '  [2] Workspace - Current folder only (%s)\n' "$WORKSPACE_PREVIEW" > /dev/tty
        printf 'Select [1/2] (press Enter for 1): ' > /dev/tty
        read -r CHOICE < /dev/tty || CHOICE=""
    fi
    CHOICE="$(printf '%s' "$CHOICE" | tr '[:upper:]' '[:lower:]')"
    case "$CHOICE" in
        2|workspace|folder|w) SCOPE="workspace" ;;
        *)                    SCOPE="global" ;;
    esac
elif [ -z "$SCOPE" ]; then
    SCOPE="global"
else
    SCOPE="$(printf '%s' "$SCOPE" | tr '[:upper:]' '[:lower:]')"
    [ "$SCOPE" = "folder" ] && SCOPE="workspace"
    if [ "$SCOPE" != "global" ] && [ "$SCOPE" != "workspace" ]; then
        printf 'error: invalid --scope "%s" (expected global or workspace)\n' "$SCOPE" >&2
        exit 2
    fi
fi

if [ -n "$DEST" ]; then
    TARGET_DIR="$DEST"
else
    TARGET_DIR="$(preview_dest "$SCOPE")"
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
