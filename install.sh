#!/usr/bin/env bash
# Multi-harness zero-clone installer for pstack-rewire (https://github.com/matthew110703/pstack-rewire).
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/install.sh | bash -s -- --target claude --scope global
set -euo pipefail

REPO_SLUG="matthew110703/pstack-rewire"
TARGET="${PSTACK_TARGET:-antigravity}"
SCOPE="${PSTACK_SCOPE:-global}"
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

resolve_dest() {
    if [ -n "$DEST" ]; then
        printf '%s' "$DEST"
        return
    fi
    if [ "$SCOPE" = "workspace" ]; then
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

TARGET_DIR="$(resolve_dest)"
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
