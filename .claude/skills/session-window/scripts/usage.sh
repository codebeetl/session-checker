#!/bin/bash
# Report remaining capacity in the Claude 5-hour session window (and the 7-day window).

body=$("$(dirname "$0")/fetch-usage.sh" 60) || exit 1

# Print "<used>% used, <left>% left, resets <local time> (in <XhYYm>)" for one window.
window() {
  used=$(jq -r ".$1.utilization // empty" <<<"$body")
  resets=$(jq -r ".$1.resets_at // empty" <<<"$body")
  if [ -z "$used" ]; then
    echo "no data"
    return
  fi
  line=$(awk -v u="$used" 'BEGIN { printf "%.0f%% used, %.0f%% left", u, 100 - u }')
  if [ -n "$resets" ]; then
    reset_epoch=$(date -d "$resets" +%s)
    mins=$(( (reset_epoch - $(date +%s)) / 60 ))
    [ "$mins" -lt 0 ] && mins=0
    line="$line, resets $(date -d "@$reset_epoch" '+%a %H:%M %Z') (in $((mins / 60))h$(printf '%02d' $((mins % 60)))m)"
  fi
  echo "$line"
}

echo "5h session: $(window five_hour)"
echo "7d weekly:  $(window seven_day)"
