#!/usr/bin/env bash
# Claude Code hook target: tracks which sessions are actively working so the
# shell can show an indicator (services/Claude.qml watches the marker dir).
#
# Wire it up in ~/.claude/settings.json hooks:
#   UserPromptSubmit -> claude-state.sh start
#   Stop             -> claude-state.sh stop
#   SessionEnd       -> claude-state.sh stop
#
# Each marker file is named after the session id and contains the PID of the
# owning claude process, so markers from crashed sessions can be pruned.

set -u

dir="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia/claude/sessions"
mkdir -p "$dir"

event="${1:-prune}"

input=""
[ -t 0 ] || input=$(cat)
session=$(jq -r '.session_id // empty' <<<"$input" 2>/dev/null)
session=${session//[^a-zA-Z0-9_-]/}

# Nearest ancestor that is the claude CLI; hooks are spawned by it, possibly
# through an intermediate shell. Falls back to the direct parent.
claude_pid() {
    local pid=$PPID comm
    while [ "$pid" -gt 1 ]; do
        comm=$(cat "/proc/$pid/comm" 2>/dev/null) || break
        case "$comm" in
        claude* | node*)
            echo "$pid"
            return
            ;;
        esac
        pid=$(awk '{print $4}' "/proc/$pid/stat" 2>/dev/null) || break
        [ -n "$pid" ] || break
    done
    echo "$PPID"
}

case "$event" in
start) [ -n "$session" ] && claude_pid >"$dir/$session" ;;
stop) [ -n "$session" ] && rm -f "$dir/$session" ;;
esac

# Drop markers whose owning process is gone (crashed/killed sessions).
for f in "$dir"/*; do
    [ -e "$f" ] || continue
    pid=$(<"$f")
    if ! [[ $pid =~ ^[0-9]+$ ]] || ! kill -0 "$pid" 2>/dev/null; then
        rm -f "$f"
    fi
done

exit 0
