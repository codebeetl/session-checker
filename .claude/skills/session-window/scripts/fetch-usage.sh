#!/bin/bash
# Print the Claude usage JSON, reusing a cached copy younger than $1 seconds (default 300).
# Reads the Claude Code OAuth token from ~/.claude/.credentials.json; never prints it.

max_age=${1:-300}
creds="${CLAUDE_CREDENTIALS:-$HOME/.claude/.credentials.json}"
cache_dir="${SESSION_WINDOW_CACHE:-$HOME/.cache/session-window}"
cache="$cache_dir/usage.json"
url="https://api.anthropic.com/api/oauth/usage"

if [ -f "$cache" ] && [ $(( $(date +%s) - $(stat -c %Y "$cache") )) -lt "$max_age" ]; then
  cat "$cache"
  exit 0
fi

token=$(jq -r '.claudeAiOauth.accessToken // empty' "$creds" 2>/dev/null)
if [ -z "$token" ]; then
  echo "error: no Claude Code OAuth token in $creds - log in with 'claude' first" >&2
  exit 1
fi

expires_ms=$(jq -r '.claudeAiOauth.expiresAt // 0' "$creds")
if [ "$((expires_ms / 1000))" -le "$(date +%s)" ]; then
  echo "error: OAuth token expired - run any 'claude' command to refresh it, then retry" >&2
  exit 1
fi

body=$(curl -sS --max-time 15 -w '\n%{http_code}' \
  -H "Authorization: Bearer $token" \
  -H "anthropic-beta: oauth-2025-04-20" \
  "$url")
status=${body##*$'\n'}
body=${body%$'\n'*}
if [ "$status" != "200" ]; then
  echo "error: $url returned HTTP $status" >&2
  exit 1
fi

mkdir -p "$cache_dir"
printf '%s\n' "$body" >"$cache"
printf '%s\n' "$body"
