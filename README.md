# session-window

A Claude Code skill and hook that report how much of the Claude 5-hour usage window is left, and tell Claude to wrap up and write a handoff before the window runs out.

```
5h session: 93% used, 7% left, resets Mon 12:49 BST (in 4h04m)
7d weekly:  53% used, 47% left, resets Sun 04:59 BST (in 140h14m)
```

## What it does

- **Skill** (`session-window`): Claude runs it when you ask about remaining usage, or before a long or multi-agent run.
- **Hook** (`wrap-up-hook.sh`): runs on `PostToolUse` and `UserPromptSubmit`. Once the 5-hour window passes 90% used, it adds a note to Claude's context telling it to stop starting new work, save its state and run a `handoff` skill. The note appears once per session per window.

Usage data is cached for up to 5 minutes in `~/.cache/session-window`, so the hook does not call the API on every tool call.

## Requirements

- Claude Code, logged in with a Claude subscription (OAuth). API-key logins have no 5-hour window.
- `bash`, `curl`, `jq`, and GNU `date` and `stat` (Linux). macOS needs `coreutils`.

## Install

Clone the repo, then link the skill into your personal skills folder:

```bash
git clone https://github.com/codebeetl/session-checker.git ~/session-checker
ln -s ~/session-checker/.claude/skills/session-window ~/.claude/skills/session-window
```

To get the wrap-up prompt, add the hook to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "~/session-checker/.claude/skills/session-window/scripts/wrap-up-hook.sh", "timeout": 20 }] }
    ],
    "UserPromptSubmit": [
      { "hooks": [{ "type": "command", "command": "~/session-checker/.claude/skills/session-window/scripts/wrap-up-hook.sh", "timeout": 20 }] }
    ]
  }
}
```

The wrap-up note tells Claude to run a `handoff` skill. Claude Code does not ship one, so provide your own or change the message in `wrap-up-hook.sh`.

## Configuration

| Variable | Default | Meaning |
|---|---|---|
| `SESSION_WINDOW_THRESHOLD` | `90` | Percent of the 5-hour window used before the hook fires |
| `SESSION_WINDOW_CACHE` | `~/.cache/session-window` | Cache and once-per-session marker folder |
| `CLAUDE_CREDENTIALS` | `~/.claude/.credentials.json` | Claude Code OAuth credentials file |

## How it gets the data

The scripts read the Claude Code OAuth token from the credentials file and call `https://api.anthropic.com/api/oauth/usage`, the endpoint Claude Code itself uses for usage figures. The token is never printed or stored elsewhere.

This endpoint is not documented and may change without notice. This project is not affiliated with Anthropic.

## Tests

```bash
bash tests/run.sh
```

The tests use a cached sample response and make no network calls.

## Licence

MIT
