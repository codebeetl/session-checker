#!/bin/bash
# Claude Code hook: tell Claude to wrap up once the 5-hour usage window passes a threshold.

threshold=${SESSION_WINDOW_THRESHOLD:-90}

input=$(cat)
body=$("$(dirname "$0")/fetch-usage.sh" 60 2>/dev/null) || exit 0
used=$(jq -r '.five_hour.utilization // empty' <<<"$body")
[ -n "$used" ] || exit 0
awk -v u="$used" -v t="$threshold" 'BEGIN { exit !(u >= t) }' || exit 0

event=$(jq -r '.hook_event_name // "PostToolUse"' <<<"$input")
session=$(jq -r '.session_id // "unknown"' <<<"$input")
resets=$(jq -r '.five_hour.resets_at // empty' <<<"$body")

warned_dir="${SESSION_WINDOW_CACHE:-$HOME/.cache/session-window}/warned"
marker="$warned_dir/$session-$(date -d "${resets:-@0}" +%s)"
[ -e "$marker" ] && exit 0
mkdir -p "$warned_dir"
touch "$marker"
reset_time=$([ -n "$resets" ] && date -d "$resets" '+%H:%M %Z')
message="USAGE LIMIT NEAR: the 5-hour usage window is $(printf '%.0f' "$used")% used${reset_time:+ and resets at $reset_time}. \
Wrap up now: do not start new long or multi-agent work, finish or checkpoint the current step, \
persist memory, and run the handoff skill to write HANDOFF.md before the limit ends this session."

jq -n --arg event "$event" --arg message "$message" \
  '{hookSpecificOutput: {hookEventName: $event, additionalContext: $message}}'
