---
name: session-window
description: Report how much of the Claude 5-hour session usage window is left, and when it resets. Use when the user asks about remaining usage, session capacity, the 5h limit, or before starting a long or multi-agent run.
---

# session-window

Run the bundled script and relay its output:

```bash
bash "<skill-dir>/scripts/usage.sh"
```

`<skill-dir>` is this skill's base directory.

The script prints two lines:

```
5h session: 93% used, 7% left, resets Mon 12:49 BST (in 4h04m)
7d weekly:  53% used, 47% left, resets Sun 04:59 BST (in 140h14m)
```

Report the 5h line to the user. Add the 7d line only when the 7d window is the tighter limit.

When the 5h window is 90% used or more and work remains, MUST wrap up: start no new long or multi-agent work, checkpoint the current step, persist memory, and run the `handoff` skill.

`scripts/wrap-up-hook.sh` is a `PostToolUse`/`UserPromptSubmit` hook that injects this wrap-up note once per session per window. `SESSION_WINDOW_THRESHOLD` sets the percent (default 90).

## Errors

- `no Claude Code OAuth token` or `token expired`: relay the message. Any `claude` command refreshes the token.
- `returned HTTP <code>`: relay the code. Do not retry in a loop.

The script reads the OAuth token from `~/.claude/.credentials.json` (override with `CLAUDE_CREDENTIALS`). MUST NOT print, echo or read that file directly.
