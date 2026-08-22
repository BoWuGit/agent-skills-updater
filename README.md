# Agent Skills Updater

A small macOS `launchd` wrapper for keeping Agent Skills up to date across Claude Code, Codex, Pi, Amp, and other harnesses.

It schedules an existing `update-all-skills` command, keeps timestamped logs, and sends a desktop notification only when an update fails or needs manual review.

## Why this pattern

- **Use `launchd`, not cron, on macOS.** A calendar job missed while the Mac sleeps is coalesced and run after wake.
- **Fail late.** One broken upstream should not prevent unrelated skills from updating.
- **Reserve exit status `2` for review.** Locally adapted skills should report upstream changes instead of overwriting local behavior blindly.
- **Keep logs and actionable notifications.** Clicking a `terminal-notifier` alert opens the exact run log.
- **Use argument arrays, not `eval`.** See [`examples/update-all-skills`](examples/update-all-skills).
- **Do not require secrets.** Public Git repositories fetched over HTTPS need no token.

## Requirements

- macOS
- An executable command that updates all of your skills
- Optional: [`terminal-notifier`](https://github.com/julienXX/terminal-notifier) for clickable notifications (`osascript` is the built-in fallback)

```bash
brew install terminal-notifier
```

## Install

```bash
git clone https://github.com/BoWuGit/agent-skills-updater.git
cd agent-skills-updater
./bin/install-launch-agent \
  --hour 10 \
  --minute 0 \
  --update-command "$HOME/.local/bin/update-all-skills"
```

The installer copies the runtime wrapper to `~/.local/libexec`, generates `~/Library/LaunchAgents/io.github.agent-skills-updater.plist`, loads it, and sends a test notification.

The update command must be an executable absolute path and should follow this exit-status contract:

| Status | Meaning | Notification |
| --- | --- | --- |
| `0` | Success | None |
| `1` (or any status except `0`/`2`) | Failure | Failure alert |
| `2` | Upstream change needs manual review | Review alert |

If you do not have an orchestrator yet, copy and customize the example:

```bash
install -m 0755 examples/update-all-skills "$HOME/.local/bin/update-all-skills"
"$HOME/.local/bin/update-all-skills" --dry-run
```

## Operate it

Run now:

```bash
"$HOME/.local/libexec/agent-skills-updater/run-scheduled-update"
```

Inspect the latest result:

```bash
cat "$HOME/Library/Logs/agent-skills-updater/latest-status"
open "$HOME/Library/Logs/agent-skills-updater/latest.log"
```

Inspect the LaunchAgent:

```bash
launchctl print "gui/$(id -u)/io.github.agent-skills-updater"
```

Logs are retained for 30 days by default. Override runtime behavior through LaunchAgent environment variables if needed:

- `SKILL_UPDATE_COMMAND`
- `SKILL_UPDATE_PATH`
- `SKILL_UPDATE_LOG_DIR`
- `SKILL_UPDATE_LOG_RETENTION_DAYS`
- `SKILL_UPDATE_NOTIFICATIONS=0` (useful in tests)

## Uninstall

```bash
launchctl bootout \
  "gui/$(id -u)" \
  "$HOME/Library/LaunchAgents/io.github.agent-skills-updater.plist"
rm "$HOME/Library/LaunchAgents/io.github.agent-skills-updater.plist"
rm -rf "$HOME/.local/libexec/agent-skills-updater"
```

Logs are intentionally left in `~/Library/Logs/agent-skills-updater`.

## Security notes

An updater is a software supply-chain boundary. Prefer these practices in each skill-specific updater:

1. Fetch over HTTPS and fail on network or TLS errors.
2. Pin a branch, tag, commit, or recorded digest; print the installed revision.
3. Validate expected files and metadata before replacing installed copies.
4. Update atomically or install from a temporary directory.
5. Do not overwrite local adaptations automatically; diff and return status `2`.
6. Never put tokens, private repository URLs, usernames, or absolute home paths in committed files.

This repository's scheduler intentionally does not interpret output or execute shell command strings. It invokes one configured executable directly and uses only its exit status.

## 中文说明

这是一个 macOS 原生的 Agent Skills 自动更新外壳：每天通过 `launchd` 调用你已有的 `update-all-skills`，保留 30 天日志；成功时保持安静，失败或上游变化需要人工 review 时才发系统通知。安装命令见上方 **Install**，默认示例为每天本地时间 10:00。

## Development

```bash
./tests/test.sh
```

## License

MIT
