#!/usr/bin/env bash
# pstack-rewire uninstaller. Kept for existing one-liners; it runs `install.sh --uninstall`.
# With no --target it lists the agents pstack is installed for and, when there are several, asks which to remove.
#   curl -fsSL https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/uninstall.sh | bash
#   ./uninstall.sh [--target claude,codex|all] [--scope global|workspace|all]
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" 2>/dev/null && pwd || true)"
if [ -n "$HERE" ] && [ -f "$HERE/install.sh" ]; then
    exec bash "$HERE/install.sh" --uninstall "$@"
fi
curl -fsSL "https://raw.githubusercontent.com/matthew110703/pstack-rewire/${PSTACK_BRANCH:-main}/install.sh" | bash -s -- --uninstall "$@"
