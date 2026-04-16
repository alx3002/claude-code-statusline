# Claude Code — Custom Status Line

> 🇧🇷 [Versão em português](README.pt-br.md)

A custom status line for [Claude Code](https://claude.ai/code) that shows model, effort level, git info, token usage, and real-time rate limit bars.

## Preview

```
│ Sonnet · high │ n8n-claude · main │ +12 -3 │ in 8.2k out 1.1k cache 4.5k │ 5h ██░░░░░░ 24% ↺1h30m │ 7d ███░░░░░ 41% ↺2d3h
```

**Color coding:**
- 🟢 Green — below 70%
- 🟡 Yellow — 70–89%
- 🔴 Red — 90%+

## What it shows

| Segment | Description |
|---|---|
| `Sonnet · high` | Current model + effort level |
| `n8n-claude · main` | Project folder + git branch |
| `+12 -3` | Lines added / removed this session |
| `in 8.2k out 1.1k cache 4.5k` | Input, output and cache-read tokens |
| `5h ██░░░░░░ 24% ↺1h30m` | 5-hour rate limit usage + time until reset |
| `7d ███░░░░░ 41% ↺2d3h` | 7-day rate limit usage + time until reset |

> **Note:** `rate_limits` fields require Claude.ai Pro or Max subscription and appear after the first API response in a session.

## Requirements

- Claude Code v2.1.80+
- `bash`
- `jq`
- `git`

Install `jq` if needed:

```bash
# Debian / Ubuntu / WSL
sudo apt install jq

# macOS
brew install jq

# Windows (Git Bash) — pick one:
winget install jqlang.jq
# or: scoop install jq
# or: choco install jq
```

### Windows support

Claude Code on Windows runs status line commands through **Git Bash**, so this script works natively — no changes needed.

| Environment | Works? | Notes |
|---|---|---|
| WSL (Ubuntu, Debian…) | ✅ | Identical to Linux |
| Git Bash + Windows Terminal | ✅ | Recommended Windows setup |
| Git Bash + cmd / old terminals | ⚠️ | Block chars (`█░`) may not render; centering may be off |
| PowerShell only | ❌ | Would need a `.ps1` rewrite |

> **Recommended on Windows:** [Windows Terminal](https://aka.ms/terminal) + [Cascadia Code](https://github.com/microsoft/cascadia-code) (or any Nerd Font) for correct rendering of the progress bar characters.  
> Make sure [Git for Windows](https://git-scm.com/download/win) is installed — it includes Git Bash.  
> On Windows, `~/.claude/` maps to `C:\Users\YourName\.claude\`.

The script handles Windows paths automatically — backslashes in `workspace.current_dir` are normalized so the folder name always displays correctly.

## Installation

### One command

```bash
bash install.sh
```

Then restart Claude Code.

### Manual

1. Copy `statusline.sh` to `~/.claude/statusline-command.sh`
2. Make it executable: `chmod +x ~/.claude/statusline-command.sh`  
   *(on Git Bash/WSL — not needed on native Windows)*
3. Add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  }
}
```

### Uninstall

```bash
bash install.sh --uninstall
```

---

## How it works

Claude Code passes a JSON blob to your script via **stdin** on every response. The script parses it with `jq`, builds colored segments, and prints the result. Claude Code renders whatever the script prints at the bottom of the terminal.

### JSON fields used

```json
{
  "model": { "display_name": "Sonnet" },
  "workspace": { "current_dir": "/path/to/project" },
  "cost": {
    "total_lines_added": 12,
    "total_lines_removed": 3
  },
  "context_window": {
    "total_input_tokens": 8200,
    "total_output_tokens": 1100,
    "current_usage": { "cache_read_input_tokens": 4500 }
  },
  "rate_limits": {
    "five_hour": { "used_percentage": 23.5, "resets_at": 1738425600 },
    "seven_day": { "used_percentage": 41.2, "resets_at": 1738857600 }
  }
}
```

The effort level is read from `~/.claude/settings.json` (`.effortLevel` field), since it is not included in the stdin JSON.

### Full list of available fields

See the [official Claude Code statusline docs](https://code.claude.com/docs/en/statusline) for the complete JSON schema. Other useful fields you can add:

| Field | Description |
|---|---|
| `session_id` | Unique session identifier |
| `context_window.used_percentage` | Pre-calculated context % |
| `context_window.context_window_size` | Max context size in tokens |
| `cost.total_cost_usd` | Estimated session cost in USD |
| `cost.total_duration_ms` | Session wall-clock time in ms |
| `vim.mode` | Vim mode (`NORMAL` / `INSERT`) when vim mode is on |
| `worktree.name` | Active git worktree name |

---

## Customization

### Change colors

Edit the color palette block in `statusline.sh`:

```bash
MODEL_COLOR=$'\033[38;5;183m'   # lilac  — model name
EFFORT_COLOR=$'\033[38;5;215m'  # orange — effort level
DIR=$'\033[38;5;110m'           # steel blue — directory
BRANCH=$'\033[38;5;150m'        # sage green — git branch
TOKEN=$'\033[38;5;174m'         # salmon — token values
CACHE=$'\033[38;5;179m'         # gold — cache tokens
ADD=$'\033[38;5;150m'           # green — lines added
DEL=$'\033[38;5;203m'           # red — lines removed
```

Use any [256-color ANSI code](https://www.ditig.com/256-colors-cheat-sheet).

### Add cost tracking

Append to the token section in `statusline.sh`:

```bash
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
if [ -n "$cost" ] && [ "$cost" != "0" ]; then
    cost_fmt=$(LC_ALL=C awk "BEGIN {printf \"$%.4f\", $cost}")
    content+=" ${MUTED}·${RESET} ${TOKEN}${cost_fmt}${RESET}"
fi
```

### Add context window bar

```bash
ctx_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
if [ -n "$ctx_pct" ]; then
    ctx_color=$(pct_color "$ctx_pct")
    ctx_int=$(LC_ALL=C awk "BEGIN {print int($ctx_pct+0.5)}")
    content+=" ${MUTED}│ ctx${RESET} $(make_bar "$ctx_pct" "$ctx_color") ${ctx_color}${ctx_int}%${RESET}"
fi
```

### Add vim mode indicator

```bash
vim_mode=$(echo "$input" | jq -r '.vim.mode // empty')
[ "$vim_mode" = "NORMAL" ] && content+=" ${MUTED}[N]${RESET}"
[ "$vim_mode" = "INSERT" ] && content+=" ${GREEN}[I]${RESET}"
```

### Refresh on a timer

To keep the rate limit countdown updating even when Claude is idle, add `refreshInterval` to `settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh",
    "refreshInterval": 30
  }
}
```

---

## Troubleshooting

**Status line disappeared / shows nothing**

Test the script manually:

```bash
echo '{}' | bash ~/.claude/statusline-command.sh
```

If it errors, check that `jq` is installed and the script is executable.

**Rate limit bars not showing**

- Requires Pro or Max subscription
- Appears only after the first API response in a session (not at session start)
- Check with: `echo '{"rate_limits":{"five_hour":{"used_percentage":50,"resets_at":9999999999}}}' | bash ~/.claude/statusline-command.sh`

**Decimal commas instead of dots (e.g. `8,2k` instead of `8.2k`)**

The script uses `LC_ALL=C awk` to force dot separator. If you still see commas, check that your `awk` respects `LC_ALL`.

**Wrong effort level shown**

The effort is read from `~/.claude/settings.json`. Change it with `/effort` in Claude Code, then it will update on the next response.

---

## Sources

- [Claude Code statusline docs](https://code.claude.com/docs/en/statusline)
- [ccusage statusline guide](https://ccusage.com/guide/statusline)
- [Claude Code statusline gist by jtbr](https://gist.github.com/jtbr/4f99671d1cee06b44106456958caba8b)
