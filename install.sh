#!/usr/bin/env bash
# pstack-rewire installer, updater, and uninstaller for every supported agent
# (https://github.com/matthew110703/pstack-rewire).
#
# With no --target it detects the agents on this machine and asks which to use:
#   curl -fsSL https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/install.sh | bash -s -- --uninstall
#   ./install.sh --target claude,codex --scope global
#   ./install.sh --list
set -euo pipefail

REPO_SLUG="matthew110703/pstack-rewire"
TARGET="${PSTACK_TARGET:-}"
SCOPE="${PSTACK_SCOPE:-}"
ACTION="${PSTACK_ACTION:-}"
DEST="${PSTACK_DEST:-}"
BRANCH="${PSTACK_BRANCH:-main}"
FORCE="${PSTACK_FORCE:-}"
YES="${PSTACK_YES:-}"
LIST=""

HARNESSES="claude codex antigravity cursor default"

usage() {
    cat <<'EOF'
Usage: install.sh [options]

  -t, --target <ids>   Comma list of agents, or "all": claude, codex, antigravity, cursor, default.
                       Without it, detected agents are offered in a menu.
  -s, --scope <scope>  global (all projects) or workspace (this folder). Uninstall also accepts all.
      --update         Install or update (the default action).
  -u, --uninstall      Remove pstack. With several installs, a menu asks which to remove.
  -y, --yes            Accept the detected agents and defaults without prompting.
      --list           Show detected agents and where pstack is installed, then exit.
  -f, --force          Back up and replace same-named skills pstack did not install.
  -d, --dest <path>    Copy one --target to a custom folder.
  -b, --branch <name>  GitHub branch to install from (default main).
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        -t|--target)    TARGET="$2"; shift 2 ;;
        -s|--scope)     SCOPE="$2"; shift 2 ;;
        -d|--dest)      DEST="$2"; shift 2 ;;
        -b|--branch)    BRANCH="$2"; shift 2 ;;
        -u|--uninstall) ACTION="uninstall"; shift 1 ;;
        --update)       ACTION="install"; shift 1 ;;
        -f|--force)     FORCE="1"; shift 1 ;;
        -y|--yes)       YES="1"; shift 1 ;;
        --list)         LIST="1"; shift 1 ;;
        -h|--help)      usage; exit 0 ;;
        *)              printf 'error: unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
done

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }
TARGET="$(lower "$TARGET" | tr ' ' ',')"
SCOPE="$(lower "$SCOPE")"
ACTION="$(lower "$ACTION")"
case "$ACTION" in remove|delete|rm) ACTION="uninstall" ;; update|upgrade) ACTION="install" ;; esac
case "$SCOPE" in folder) SCOPE="workspace" ;; both) SCOPE="all" ;; esac

# True only when a terminal can actually be opened (not just when /dev/tty exists).
have_tty() { [ -z "$YES" ] && (exec < /dev/tty) 2>/dev/null; }
ask() { local reply=""; printf '%s' "$1" > /dev/tty; read -r reply < /dev/tty || reply=""; printf '%s' "$reply" | tr -d '\r'; }
on_path() { command -v "$1" >/dev/null 2>&1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" 2>/dev/null && pwd || true)"

# ---------------------------------------------------------------------------
# Harness registry: label, detection, and install status.
# ---------------------------------------------------------------------------
label_of() {
    case "$1" in
        claude)      printf 'Claude Code' ;;
        codex)       printf 'OpenAI Codex' ;;
        antigravity) printf 'Google Antigravity' ;;
        cursor)      printf 'Cursor' ;;
        default)     printf 'Other agents via .agents/skills' ;;
    esac
}

# Prints the evidence for an agent being present (empty when not found).
evidence_of() {
    local found="" c
    case "$1" in
        claude)
            on_path claude && found="claude"
            [ -d "$HOME/.claude" ] && found="${found:+$found, }~/.claude" ;;
        codex)
            on_path codex && found="codex"
            [ -d "$HOME/.codex" ] && found="${found:+$found, }~/.codex" ;;
        antigravity)
            for c in agy antigravity; do on_path "$c" && found="${found:+$found, }$c"; done
            [ -d "$HOME/.gemini/antigravity" ] && found="${found:+$found, }~/.gemini/antigravity"
            [ -d "/Applications/Antigravity.app" ] && found="${found:+$found, }Antigravity.app" ;;
        cursor)
            on_path cursor && found="cursor"
            [ -d "$HOME/.cursor" ] && found="${found:+$found, }~/.cursor"
            [ -d "/Applications/Cursor.app" ] && found="${found:+$found, }Cursor.app" ;;
        default)
            for c in gemini opencode copilot amp goose droid junie kiro; do on_path "$c" && found="${found:+$found, }$c"; done
            [ -d "$HOME/.agents/skills" ] && found="${found:+$found, }~/.agents/skills" ;;
    esac
    printf '%s' "$found"
}

folder_dest() {
    local harness="$1" sc="$2"
    if [ "$sc" = "workspace" ]; then
        case "$harness" in
            antigravity) printf '%s/.agents/plugins/pstack' "$PWD" ;;
            cursor)      printf '%s/.cursor/plugins/pstack' "$PWD" ;;
            *)           printf '%s/.%s/plugins/pstack' "$PWD" "$harness" ;;
        esac
        return
    fi
    case "$harness" in
        antigravity) printf '%s/.gemini/config/plugins/pstack' "$HOME" ;;
        cursor)      printf '%s/.cursor/plugins/pstack' "$HOME" ;;
        *)           printf '%s/.%s/plugins/pstack' "$HOME" "$harness" ;;
    esac
}

# Is pstack installed for this harness at this scope?
installed_at() {
    local harness="$1" sc="$2"
    case "$harness" in
        claude)
            if [ "$sc" = "workspace" ]; then
                [ -d "$PWD/.claude/plugins/pstack" ] && return 0
                [ -f "$PWD/.claude/settings.json" ] && grep -q 'pstack@pstack-rewire' "$PWD/.claude/settings.json" && return 0
            else
                [ -d "$HOME/.claude/plugins/pstack" ] && return 0
                on_path claude && claude plugin list 2>/dev/null | grep -A3 'pstack@pstack-rewire' | grep -q 'Scope: user' && return 0
            fi
            return 1 ;;
        codex)
            if [ "$sc" = "workspace" ]; then
                [ -f "$PWD/.agents/.pstack-manifest-codex" ]
            else
                [ -d "$HOME/.codex/plugins/cache/pstack-rewire-codex/pstack" ] || [ -d "$HOME/.codex/plugins/pstack" ]
            fi ;;
        default)
            if [ "$sc" = "workspace" ]; then [ -f "$PWD/.agents/.pstack-manifest-default" ]; else [ -f "$HOME/.agents/.pstack-manifest-default" ]; fi ;;
        *)
            [ -d "$(folder_dest "$harness" "$sc")" ] ;;
    esac
}

where_installed() {
    local out=""
    installed_at "$1" global && out="global"
    installed_at "$1" workspace && out="${out:+$out + }workspace"
    printf '%s' "$out"
}

valid_harness() { case " $HARNESSES " in *" $1 "*) return 0 ;; esac; return 1; }

if [ -n "$LIST" ]; then
    printf '%-4s %-44s %-20s %s\n' "" "agent" "pstack" "detected via"
    i=0
    for h in $HARNESSES; do
        i=$((i + 1))
        ev="$(evidence_of "$h")"; inst="$(where_installed "$h")"
        printf '%-4s %-44s %-20s %s\n' "$i" "$(label_of "$h") ($h)" "${inst:--}" "${ev:-not found}"
    done
    exit 0
fi

# ---------------------------------------------------------------------------
# Choose the action, the agents, and the scope.
# ---------------------------------------------------------------------------
if [ -z "$ACTION" ]; then
    ACTION="install"
    if [ -z "$TARGET" ] && [ -z "$DEST" ] && have_tty; then
        reply="$(ask $'\npstack: [1] Install / update  [2] Uninstall  (Enter = 1): ')"
        case "$(lower "$reply")" in 2|u|uninstall|remove) ACTION="uninstall" ;; q|quit) exit 0 ;; esac
    fi
fi

SELECTED=""
if [ -n "$TARGET" ]; then
    if [ "$TARGET" = "all" ]; then
        SELECTED="$HARNESSES"
    else
        for h in $(printf '%s' "$TARGET" | tr ',' ' '); do
            if ! valid_harness "$h"; then
                printf 'error: unknown target "%s". Valid targets: %s, all\n' "$h" "$(printf '%s' "$HARNESSES" | sed 's/ /, /g')" >&2
                exit 2
            fi
            case " $SELECTED " in *" $h "*) ;; *) SELECTED="${SELECTED:+$SELECTED }$h" ;; esac
        done
    fi
else
    CANDIDATES="" CHECKED=""
    for h in $HARNESSES; do
        if [ "$ACTION" = "uninstall" ]; then
            [ -n "$(where_installed "$h")" ] || continue
            CANDIDATES="${CANDIDATES:+$CANDIDATES }$h"; CHECKED="${CHECKED:+$CHECKED }$h"
        else
            CANDIDATES="${CANDIDATES:+$CANDIDATES }$h"
            [ -n "$(evidence_of "$h")" ] && CHECKED="${CHECKED:+$CHECKED }$h"
        fi
    done
    if [ "$ACTION" = "uninstall" ] && [ -z "$CANDIDATES" ]; then
        printf 'pstack is not installed for any agent (global or in %s).\n' "$PWD"
        exit 0
    fi
    if [ "$ACTION" = "install" ] && [ -z "$CHECKED" ] && ! have_tty; then
        printf 'No supported agent was detected. Pick one explicitly, for example:\n' >&2
        printf '  install.sh --target claude      # or codex, antigravity, cursor, default\n' >&2
        exit 0
    fi
    count=0; for h in $CANDIDATES; do count=$((count + 1)); done
    if [ "$ACTION" = "uninstall" ] && [ "$count" -eq 1 ]; then
        SELECTED="$CANDIDATES"
    elif have_tty; then
        if [ "$ACTION" = "uninstall" ]; then
            printf '\npstack is installed for these agents (all checked):\n' > /dev/tty
        else
            printf '\npstack: choose agents (detected ones are checked)\n' > /dev/tty
        fi
        i=0
        for h in $CANDIDATES; do
            i=$((i + 1))
            case " $CHECKED " in *" $h "*) mark="x" ;; *) mark=" " ;; esac
            if [ "$ACTION" = "uninstall" ]; then info="$(where_installed "$h")"; else info="$(evidence_of "$h")"; info="${info:-not found}"; fi
            printf '  [%s] %-2s %-34s %s\n' "$mark" "$i" "$(label_of "$h")" "$info" > /dev/tty
        done
        reply="$(ask 'Enter = checked ones, or type numbers (e.g. 1,3), "a" = all, "q" = quit: ')"
        reply="$(lower "$reply" | tr -d ' ')"
        case "$reply" in
            q|quit) printf 'Nothing changed.\n'; exit 0 ;;
            "")     SELECTED="$CHECKED" ;;
            a|all)  SELECTED="$CANDIDATES" ;;
            *)
                for n in $(printf '%s' "$reply" | tr ',' ' '); do
                    case "$n" in *[!0-9]*|"") printf 'error: "%s" is not a number from the list\n' "$n" >&2; exit 2 ;; esac
                    pick="$(printf '%s' "$CANDIDATES" | tr ' ' '\n' | sed -n "${n}p")"
                    [ -n "$pick" ] || { printf 'error: %s is not in the list\n' "$n" >&2; exit 2; }
                    case " $SELECTED " in *" $pick "*) ;; *) SELECTED="${SELECTED:+$SELECTED }$pick" ;; esac
                done ;;
        esac
    else
        SELECTED="$CHECKED"
        if [ "$ACTION" = "uninstall" ]; then
            printf 'pstack: uninstalling from every agent it is installed for: %s\n' "$SELECTED"
        else
            printf 'pstack: installing for detected agents: %s\n' "$SELECTED"
        fi
    fi
    if [ -z "$SELECTED" ]; then printf 'No agents selected. Nothing changed.\n'; exit 0; fi
fi

if [ -n "$DEST" ]; then
    case "$SELECTED" in *" "*|"") printf 'error: --dest needs exactly one --target\n' >&2; exit 2 ;; esac
fi

if [ -z "$SCOPE" ] && [ -z "$DEST" ]; then
    if have_tty; then
        if [ "$ACTION" = "uninstall" ]; then
            reply="$(ask $'Remove from: [1] Global  [2] This folder ('"$PWD"$')  [3] Both  (Enter = 3): ')"
            case "$(lower "$reply")" in 1|global|g) SCOPE="global" ;; 2|workspace|folder|w) SCOPE="workspace" ;; *) SCOPE="all" ;; esac
        else
            reply="$(ask $'Install for: [1] All projects on this device (global)  [2] This folder only ('"$PWD"$')  (Enter = 1): ')"
            case "$(lower "$reply")" in 2|workspace|folder|w) SCOPE="workspace" ;; *) SCOPE="global" ;; esac
        fi
    elif [ "$ACTION" = "uninstall" ]; then
        SCOPE="all"
    else
        SCOPE="global"
    fi
fi
[ -z "$SCOPE" ] && SCOPE="global"
case "$SCOPE" in
    global|workspace) ;;
    all) [ "$ACTION" = "uninstall" ] || { printf 'error: --scope all only applies to --uninstall\n' >&2; exit 2; } ;;
    *) printf 'error: invalid --scope "%s" (expected global or workspace%s)\n' "$SCOPE" "$([ "$ACTION" = uninstall ] && printf ', or all')" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# Shared helpers.
# ---------------------------------------------------------------------------
REPO_ROOT=""
TMP_DIR=""
cleanup() { [ -n "$TMP_DIR" ] && rm -rf "$TMP_DIR"; return 0; }
trap cleanup EXIT

# Sets REPO_ROOT to a checkout holding every harness folder in $*: this script's
# checkout when it has them, otherwise one GitHub tarball for the whole run.
resolve_repo_root() {
    local h ok=1
    if [ -n "$SCRIPT_DIR" ]; then
        for h in "$@"; do [ -d "$SCRIPT_DIR/$h" ] || ok=0; done
        if [ "$ok" = 1 ]; then REPO_ROOT="$SCRIPT_DIR"; return; fi
    fi
    TMP_DIR="$(mktemp -d)"
    printf 'Downloading pstack from GitHub (%s@%s)...\n' "$REPO_SLUG" "$BRANCH"
    curl -fsSL "https://github.com/${REPO_SLUG}/archive/refs/heads/${BRANCH}.tar.gz" | tar -xz -C "$TMP_DIR"
    REPO_ROOT="$(find "$TMP_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
}

manifest_skills() { [ -f "$1" ] && sed -n 's/^skill=//p' "$1" || true; }

# Copies every skill folder from $1 into $2, tracking ownership in manifest $3.
# A same-named skill that pstack did not install aborts the copy unless --force,
# which first backs it up next to the skills folder.
flat_install() {
    local src="$1" dest="$2" manifest="$3" label="$4"
    mkdir -p "$dest"
    local owned collisions="" name
    owned="$(manifest_skills "$manifest")"
    for dir in "$src"/*/; do
        name="$(basename "$dir")"
        if [ -e "$dest/$name" ] && ! printf '%s\n' "$owned" | grep -qx "$name"; then
            collisions="$collisions $name"
        fi
    done
    if [ -n "$collisions" ]; then
        if [ -z "$FORCE" ]; then
            printf 'error: these skills already exist in %s and were not installed by pstack:%s\n' "$dest" "$collisions" >&2
            printf 'Rerun with --force to back them up and replace them.\n' >&2
            exit 1
        fi
        local backup
        backup="$(dirname "$dest")/.pstack-backup-$(date +%Y%m%d%H%M%S)"
        mkdir -p "$backup"
        for name in $collisions; do mv "$dest/$name" "$backup/$name"; done
        printf 'Backed up%s to %s\n' "$collisions" "$backup"
    fi
    for name in $owned; do rm -rf "${dest:?}/$name"; done
    {
        printf 'target=%s\n' "$label"
        printf 'version=%s\n' "$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$src/../plugin.json" | head -n 1)"
        printf 'installed_at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        for dir in "$src"/*/; do printf 'skill=%s\n' "$(basename "$dir")"; done
    } > "$manifest.tmp"
    for dir in "$src"/*/; do cp -R "${dir%/}" "$dest/"; done
    mv "$manifest.tmp" "$manifest"
}

flat_uninstall() {
    local dest="$1" manifest="$2" label="$3" n=0 name
    if [ ! -f "$manifest" ]; then
        printf 'pstack (%s) is not installed in %s\n' "$label" "$dest"
        return
    fi
    for name in $(manifest_skills "$manifest"); do rm -rf "${dest:?}/$name"; n=$((n + 1)); done
    rm -f "$manifest"
    printf 'Uninstalled pstack (%s): removed %s skills from %s\n' "$label" "$n" "$dest"
    local b
    for b in "$(dirname "$dest")"/.pstack-backup-*; do
        [ -d "$b" ] && printf 'Skills pstack replaced are backed up in %s. Move them back into %s to restore them.\n' "$b" "$dest"
    done
    return 0
}

# Codex custom agents: copy pstack's TOML agents, never overwriting a file without the managed-by header.
install_codex_agents() {
    local src="$1" dest="$2" f name
    ls "$src"/*.toml >/dev/null 2>&1 || return 0
    mkdir -p "$dest"
    for f in "$src"/*.toml; do
        [ -f "$f" ] || continue
        name="$(basename "$f")"
        if [ -f "$dest/$name" ] && ! head -n 1 "$dest/$name" | grep -q 'managed-by: pstack-rewire'; then
            printf 'Kept your edited %s (no pstack header)\n' "$dest/$name"
            continue
        fi
        cp "$f" "$dest/$name"
    done
    printf 'Installed Codex agents (poteto-agent, comment-sicko) -> %s\n' "$dest"
}

remove_codex_agents() {
    local dest="$1" f
    for f in "$dest"/poteto-agent.toml "$dest"/comment-sicko.toml; do
        if [ -f "$f" ] && head -n 1 "$f" | grep -q 'managed-by: pstack-rewire'; then rm -f "$f"; fi
    done
    return 0
}

# Offers [agents] max_depth = 2 so pstack delegates can spawn their own helpers on
# multi-agent v1 models. Records what it changed so uninstall can revert it.
offer_max_depth() {
    local cfg="$1" record="$2" answer=""
    have_tty || return 0
    if grep -qE '^[[:space:]]*max_depth[[:space:]]*=[[:space:]]*[2-9]' "$cfg" 2>/dev/null; then return 0; fi
    answer="$(ask "Allow pstack subagents to spawn their own helpers? Sets [agents] max_depth = 2 in $cfg [y/N]: ")"
    case "$answer" in y|Y|yes|YES) ;; *) return 0 ;; esac
    mkdir -p "$(dirname "$cfg")"
    touch "$cfg"
    local previous="absent"
    if grep -q '^\[agents\]' "$cfg"; then
        previous="$(awk '/^\[agents\]/{a=1;next} /^\[/{a=0} a && /^[[:space:]]*max_depth[[:space:]]*=/{sub(/.*=[[:space:]]*/,"");print;exit}' "$cfg")"
        [ -z "$previous" ] && previous="absent"
        awk 'BEGIN{d=0} /^\[agents\]/{print; a=1; next} /^\[/{if(a&&!d){print "max_depth = 2"; d=1} a=0} a && /^[[:space:]]*max_depth[[:space:]]*=/{if(!d){print "max_depth = 2"; d=1}; next} {print} END{if(a&&!d) print "max_depth = 2"}' "$cfg" > "$cfg.pstack.tmp" && mv "$cfg.pstack.tmp" "$cfg"
    else
        printf '\n[agents]\nmax_depth = 2\n' >> "$cfg"
    fi
    printf 'max_depth_set=1\nmax_depth_previous=%s\n' "$previous" > "$record"
    printf 'Set [agents] max_depth = 2 in %s\n' "$cfg"
}

revert_max_depth() {
    local cfg="$1" record="$2"
    [ -f "$record" ] && grep -q '^max_depth_set=1' "$record" || { rm -f "$record"; return 0; }
    local previous
    previous="$(sed -n 's/^max_depth_previous=//p' "$record")"
    if awk '/^\[agents\]/{a=1;next} /^\[/{a=0} a && /^[[:space:]]*max_depth[[:space:]]*=[[:space:]]*2[[:space:]]*$/{f=1} END{exit !f}' "$cfg" 2>/dev/null; then
        if [ "$previous" = "absent" ]; then
            awk '/^\[agents\]/{a=1} /^\[/&&!/^\[agents\]/{a=0} !(a && /^[[:space:]]*max_depth[[:space:]]*=/){print}' "$cfg" > "$cfg.pstack.tmp" && mv "$cfg.pstack.tmp" "$cfg"
        else
            awk -v v="$previous" '/^\[agents\]/{a=1} /^\[/&&!/^\[agents\]/{a=0} a && /^[[:space:]]*max_depth[[:space:]]*=/{print "max_depth = " v; next} {print}' "$cfg" > "$cfg.pstack.tmp" && mv "$cfg.pstack.tmp" "$cfg"
        fi
        printf 'Restored [agents] max_depth in %s\n' "$cfg"
    fi
    rm -f "$record"
}

strip_models_block() {
    local f
    for f in "$HOME/.codex/AGENTS.md" "$HOME/.codex/AGENTS.override.md"; do
        [ -f "$f" ] && grep -q 'pstack-models:begin' "$f" || continue
        awk '/<!-- pstack-models:begin -->/{s=1;next} /<!-- pstack-models:end -->/{s=0;next} !s{print}' "$f" > "$f.pstack.tmp" && mv "$f.pstack.tmp" "$f"
        printf 'Removed the pstack-models block from %s\n' "$f"
    done
    return 0
}

# ---------------------------------------------------------------------------
# Per-harness actions. Each runs as `run_<id> <install|uninstall> <global|workspace>`.
# ---------------------------------------------------------------------------

# Claude Code loads plugins only from marketplaces, so this goes through the `claude plugin` CLI.
run_claude() {
    local action="$1" sc="$2" marketplace="pstack-rewire" plugin_id="pstack@pstack-rewire" claude_scope="user" legacy source
    [ "$sc" = "workspace" ] && claude_scope="project"
    legacy="$HOME/.claude/plugins/pstack"; [ "$sc" = "workspace" ] && legacy="$PWD/.claude/plugins/pstack"
    if [ -d "$legacy" ]; then rm -rf "$legacy"; printf 'Removed legacy folder copy at %s\n' "$legacy"; fi
    if ! on_path claude; then
        printf 'The claude CLI was not found on PATH. In a Claude Code session, run:\n'
        if [ "$action" = "uninstall" ]; then
            printf '  /plugin uninstall %s\n  /plugin marketplace remove %s\n' "$plugin_id" "$marketplace"
        else
            printf '  /plugin marketplace add %s\n  /plugin install %s\n' "$REPO_SLUG" "$plugin_id"
        fi
        return 3
    fi
    if [ "$action" = "uninstall" ]; then
        if claude plugin uninstall "$plugin_id" --scope "$claude_scope" >/dev/null 2>&1; then
            printf 'Uninstalled pstack (claude, %s scope)\n' "$claude_scope"
        else
            printf 'pstack (claude, %s scope) is not installed\n' "$claude_scope"
        fi
        # Drop this scope's marketplace declaration, and the marketplace itself once no scope still has pstack.
        claude plugin marketplace remove "$marketplace" --scope "$claude_scope" >/dev/null 2>&1 || true
        if ! claude plugin list 2>/dev/null | grep -q "$plugin_id"; then
            claude plugin marketplace remove "$marketplace" >/dev/null 2>&1 && printf 'Removed marketplace %s (no pstack install remains)\n' "$marketplace"
        fi
        return 0
    fi
    if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/.claude-plugin/marketplace.json" ] && [ -d "$SCRIPT_DIR/claude" ]; then source="$SCRIPT_DIR"; else source="$REPO_SLUG"; fi
    # `marketplace add` and `plugin install` are idempotent and record the declaration in the chosen scope's settings.
    claude plugin marketplace add "$source" --scope "$claude_scope"
    claude plugin marketplace update "$marketplace"
    claude plugin install "$plugin_id" --scope "$claude_scope"
    claude plugin update "$plugin_id" --scope "$claude_scope" || true
    printf 'Installed or updated pstack (claude, %s scope). Restart Claude Code or run /reload-plugins, then run /pstack:poteto-help.\n' "$claude_scope"
}

# Codex: the plugin through `codex plugin` (global), or the skills copied into
# .agents/skills (workspace; Codex plugins have no project scope).
run_codex() {
    local action="$1" sc="$2" marketplace="pstack-rewire-codex" plugin_id="pstack@pstack-rewire-codex" source cache
    if [ -d "$HOME/.codex/plugins/pstack" ]; then rm -rf "$HOME/.codex/plugins/pstack"; printf 'Removed legacy folder copy at %s\n' "$HOME/.codex/plugins/pstack"; fi
    if [ "$sc" = "workspace" ]; then
        if [ "$action" = "uninstall" ]; then
            flat_uninstall "$PWD/.agents/skills" "$PWD/.agents/.pstack-manifest-codex" "codex, workspace"
            remove_codex_agents "$PWD/.codex/agents"
            revert_max_depth "$PWD/.codex/config.toml" "$PWD/.codex/.pstack-install"
            return 0
        fi
        flat_install "$REPO_ROOT/codex/skills" "$PWD/.agents/skills" "$PWD/.agents/.pstack-manifest-codex" codex
        install_codex_agents "$REPO_ROOT/codex/agents" "$PWD/.codex/agents"
        offer_max_depth "$PWD/.codex/config.toml" "$PWD/.codex/.pstack-install"
        printf 'Installed pstack (codex, workspace) -> %s/.agents/skills. Trust this project in Codex, then type $poteto-help.\n' "$PWD"
        return 0
    fi
    if ! on_path codex; then
        printf 'The codex CLI was not found on PATH. Install it with `npm i -g @openai/codex`, or run:\n'
        if [ "$action" = "uninstall" ]; then
            printf '  codex plugin remove %s\n  codex plugin marketplace remove %s\n' "$plugin_id" "$marketplace"
        else
            printf '  codex plugin marketplace add %s\n  codex plugin add %s\n' "$REPO_SLUG" "$plugin_id"
        fi
        return 3
    fi
    if [ "$action" = "uninstall" ]; then
        if codex plugin remove "$plugin_id" >/dev/null 2>&1; then
            printf 'Uninstalled pstack (codex plugin %s)\n' "$plugin_id"
        else
            printf 'pstack (codex plugin %s) is not installed\n' "$plugin_id"
        fi
        if ! codex plugin list 2>/dev/null | grep -q "$plugin_id"; then
            codex plugin marketplace remove "$marketplace" >/dev/null 2>&1 && printf 'Removed marketplace %s\n' "$marketplace"
        fi
        remove_codex_agents "$HOME/.codex/agents"
        strip_models_block
        revert_max_depth "$HOME/.codex/config.toml" "$HOME/.codex/.pstack-install"
        return 0
    fi
    if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/.agents/plugins/marketplace.json" ] && [ -d "$SCRIPT_DIR/codex" ]; then source="$SCRIPT_DIR"; else source="$REPO_SLUG"; fi
    # `marketplace add` is idempotent; `upgrade` refreshes Git sources and errors harmlessly for local ones.
    codex plugin marketplace add "$source"
    codex plugin marketplace upgrade "$marketplace" >/dev/null 2>&1 || true
    codex plugin add "$plugin_id"
    cache="$(ls -d "$HOME/.codex/plugins/cache/$marketplace/pstack"/*/ 2>/dev/null | sort -V | tail -n 1)"
    if [ -z "$cache" ] || [ ! -f "$cache/.codex-plugin/plugin.json" ]; then
        printf 'error: Codex did not install the codex/ bundle (expected %s.codex-plugin/plugin.json)\n' "${cache:-<cache>/}" >&2
        return 1
    fi
    install_codex_agents "${cache%/}/agents" "$HOME/.codex/agents"
    offer_max_depth "$HOME/.codex/config.toml" "$HOME/.codex/.pstack-install"
    printf 'Installed or updated pstack (codex plugin %s). Start a new Codex session and type $pstack:poteto-help.\n' "$plugin_id"
}

# The open-standard skills copied into .agents/skills, for any agent that reads them.
run_default() {
    local action="$1" sc="$2" base="$HOME" answer
    [ "$sc" = "workspace" ] && base="$PWD"
    if [ "$action" = "uninstall" ]; then
        flat_uninstall "$base/.agents/skills" "$base/.agents/.pstack-manifest-default" "default, $sc"
        if [ "$sc" = "global" ] && [ -f "$HOME/.agents/pstack-models.md" ] && have_tty; then
            answer="$(ask "Also remove your model roles file $HOME/.agents/pstack-models.md? [y/N]: ")"
            case "$answer" in y|Y|yes|YES) rm -f "$HOME/.agents/pstack-models.md"; printf 'Removed %s\n' "$HOME/.agents/pstack-models.md" ;; esac
        fi
        return 0
    fi
    flat_install "$REPO_ROOT/default/skills" "$base/.agents/skills" "$base/.agents/.pstack-manifest-default" default
    if [ -d "$HOME/.codex/plugins/cache/pstack-rewire-codex/pstack" ]; then
        printf 'Note: the pstack Codex plugin is also installed, so Codex will list both pstack:<name> and <name> skills.\n'
    fi
    printf 'Installed or updated pstack (default, %s) -> %s/.agents/skills. Start a new agent session and ask for the poteto-help skill.\n' "$sc" "$base"
}

# Antigravity, Cursor, and any other folder-based harness: copy the harness folder.
run_folder() {
    local harness="$1" action="$2" sc="$3" dest
    dest="${DEST:-$(folder_dest "$harness" "$sc")}"
    if [ "$action" = "uninstall" ]; then
        if [ -d "$dest" ]; then
            rm -rf "$dest"
            printf 'Uninstalled pstack (%s, %s) from %s\n' "$harness" "$sc" "$dest"
        else
            printf 'pstack (%s, %s) is not installed at %s\n' "$harness" "$sc" "$dest"
        fi
        return 0
    fi
    if [ ! -d "$REPO_ROOT/$harness" ]; then
        printf 'error: harness "%s" not found in %s\n' "$harness" "$REPO_SLUG" >&2
        return 1
    fi
    mkdir -p "$(dirname "$dest")"
    rm -rf "$dest"
    cp -R "$REPO_ROOT/$harness" "$dest"
    printf 'Installed pstack (%s, %s) -> %s\n' "$harness" "$sc" "$dest"
}

run_harness() {
    local harness="$1" action="$2" sc="$3"
    if [ -n "$DEST" ]; then run_folder "$harness" "$action" "$sc"; return; fi
    case "$harness" in
        claude)  run_claude "$action" "$sc" ;;
        codex)   run_codex "$action" "$sc" ;;
        default) run_default "$action" "$sc" ;;
        *)       run_folder "$harness" "$action" "$sc" ;;
    esac
}

# ---------------------------------------------------------------------------
# Run.
# ---------------------------------------------------------------------------
if [ "$ACTION" = "install" ]; then
    NEED=""
    for h in $SELECTED; do
        case "$h" in
            claude) ;;
            codex) [ "$SCOPE" = "workspace" ] && NEED="$NEED codex" ;;
            *) NEED="$NEED $h" ;;
        esac
    done
    # shellcheck disable=SC2086
    [ -n "$NEED" ] && resolve_repo_root $NEED
fi

if [ "$SCOPE" = "all" ]; then SCOPES="global workspace"; else SCOPES="$SCOPE"; fi
SUMMARY=""
FAILED=0
for h in $SELECTED; do
    for sc in $SCOPES; do
        if [ "$ACTION" = "uninstall" ] && [ -z "$DEST" ] && [ "$h" != "claude" ] && [ "$h" != "codex" ] && ! installed_at "$h" "$sc"; then
            continue
        fi
        printf '\n== %s (%s, %s)\n' "$(label_of "$h")" "$ACTION" "$sc"
        # A plain (non-conditional) subshell keeps `set -e` active, so a failed step fails only this harness.
        set +e
        ( set -e; run_harness "$h" "$ACTION" "$sc" )
        rc=$?
        set -e
        if [ "$rc" -eq 0 ]; then
            SUMMARY="$SUMMARY
  ok      $(label_of "$h") ($sc)"
        elif [ "$rc" -eq 3 ]; then
            SUMMARY="$SUMMARY
  skipped $(label_of "$h") ($sc): its CLI is not on PATH, run the commands printed above"
        else
            FAILED=1
            SUMMARY="$SUMMARY
  FAILED  $(label_of "$h") ($sc)"
        fi
    done
done

printf '\npstack %s summary:%s\n' "$ACTION" "${SUMMARY:-
  nothing to do}"
exit "$FAILED"
