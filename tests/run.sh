#!/bin/bash
# Run with: bash tests/run.sh

root=$(cd "$(dirname "$0")/.." && pwd)
scripts="$root/.claude/skills/session-window/scripts"
failures=0

export SESSION_WINDOW_CACHE=$(mktemp -d)
export CLAUDE_CREDENTIALS=/nonexistent

seed_cache() {
  cat >"$SESSION_WINDOW_CACHE/usage.json" <<EOF
{"five_hour":{"utilization":$1,"resets_at":"2099-01-01T00:00:00+00:00"},
 "seven_day":{"utilization":40.0,"resets_at":"2099-01-02T00:00:00+00:00"}}
EOF
}

check() {
  if [ "$2" = "pass" ]; then
    echo "ok   - $1"
  else
    echo "FAIL - $1"
    failures=$((failures + 1))
  fi
}

seed_cache 93.0
out=$("$scripts/usage.sh" 2>&1)
[[ "$out" == "5h session: 93% used, 7% left"* ]] && r=pass || r=fail
check "usage.sh reports the 5h window from a fresh cache" "$r"

hook_input() {
  printf '{"session_id":"%s","hook_event_name":"%s"}' "$1" "$2"
}

seed_cache 89.0
out=$(hook_input s1 PostToolUse | "$scripts/wrap-up-hook.sh")
[ $? -eq 0 ] && [ -z "$out" ] && r=pass || r=fail
check "hook stays silent below the threshold" "$r"

seed_cache 91.0
out=$(hook_input s1 UserPromptSubmit | "$scripts/wrap-up-hook.sh")
[ "$(jq -r .hookSpecificOutput.hookEventName <<<"$out")" = UserPromptSubmit ] &&
  jq -r .hookSpecificOutput.additionalContext <<<"$out" | grep -q handoff && r=pass || r=fail
check "hook tells Claude to hand off at the threshold" "$r"

out=$(hook_input s1 PostToolUse | "$scripts/wrap-up-hook.sh")
[ -z "$out" ] && r=pass || r=fail
check "hook warns a session only once per window" "$r"

out=$(hook_input s2 PostToolUse | "$scripts/wrap-up-hook.sh")
[ -n "$out" ] && r=pass || r=fail
check "hook still warns another session" "$r"

seed_cache 95.0
touch -d '2 minutes ago' "$SESSION_WINDOW_CACHE/usage.json"
out=$(hook_input s3 PostToolUse | "$scripts/wrap-up-hook.sh")
[ -z "$out" ] && r=pass || r=fail
check "hook ignores a cached figure older than a minute" "$r"

seed_cache_resetting_at() {
  cat >"$SESSION_WINDOW_CACHE/usage.json" <<EOF
{"five_hour":{"utilization":95.0,"resets_at":"$1"}}
EOF
}

seed_cache_resetting_at "2099-01-01T14:09:59.556+00:00"
out=$(hook_input s4 PostToolUse | "$scripts/wrap-up-hook.sh")
seed_cache_resetting_at "2099-01-01T14:10:00.266+00:00"
again=$(hook_input s4 PostToolUse | "$scripts/wrap-up-hook.sh")
[ -n "$out" ] && [ -z "$again" ] && r=pass || r=fail
check "hook warns once when resets_at jitters under a second" "$r"

rm -r "$SESSION_WINDOW_CACHE"
[ "$failures" -eq 0 ]
