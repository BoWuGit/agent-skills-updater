# Agent Skills Pack & Updater

An opinionated, batteries-included collection of the Agent Skills I use, with one-command installation across Claude Code, Codex, DeepSeek Harness (DSH), Pi, Amp, Cursor, and compatible harnesses.

The pack fetches skills directly from their official upstream repositories and provides repeatable updates. On macOS it can also update everything daily with `launchd`, retained logs, and failure notifications.

## Included Skills

| Skill set | What gets installed |
| --- | --- |
| [Cursor](https://github.com/cursor/plugins) | `thermo-nuclear-code-quality-review` |
| [LY Corporation](https://github.com/lycorp-jp/sim-use) | `sim-use` |
| [OpenClaw](https://github.com/openclaw/agent-skills) | `autoreview` |
| [Matt Pocock](https://github.com/mattpocock/skills) | Every non-deprecated skill in the upstream collection |
| [Anthropic](https://github.com/anthropics/claude-plugins-official) | The official, unmodified `code-simplifier` |

See [Skill sources and distribution strategy](docs/skill-sources.md) for provenance, licenses, and the supply-chain model.

## Quick start

Requirements: Bash, Git, curl, and Python 3. No API key or GitHub token is required for the default public sources.

```bash
git clone https://github.com/BoWuGit/agent-skills-updater.git
cd agent-skills-updater
./install.sh
```

That command:

1. installs the updater under `~/.local/libexec/agent-skills-updater`;
2. exposes `~/.local/bin/update-all-skills`;
3. fetches and installs the complete skill set;
4. detects installed agent harnesses and links skills into them;
5. on macOS, schedules a quiet daily update at 10:00 local time.

Reload or restart your agent harnesses after the first installation.

### Useful installation options

```bash
# Install skills but do not add the macOS daily schedule
./install.sh --no-schedule

# Schedule at 08:30 instead
./install.sh --hour 8 --minute 30

# Also install the sim-use CLI through Homebrew
./install.sh --with-sim-use-binary

# Explicitly replace conflicting same-name skills
./install.sh --force
```

The installer never replaces an existing, unmanaged skill by default. It prints every conflict it skips. Use `--force` only after reviewing those conflicts.

## Where skills are installed

The canonical upstream checkouts live under:

```text
~/.local/share/agent-skills-updater/
```

`~/.agents/skills` is always targeted. Harness-specific targets are added when their configuration parent exists:

| Harness | Skill directory |
| --- | --- |
| Claude Code | `~/.claude/skills` |
| Codex | `~/.codex/skills` |
| Amp / agents standard | `~/.config/agents/skills` |
| Pi | `~/.pi/agent/skills` |
| Cursor | `~/.cursor/skills` |
| DeepSeek Harness (DSH) | `$DSH_HOME/skills` or `~/.dsh/skills` |

DSH also discovers the always-installed `~/.agents/skills` compatibility root. Its native root is linked as well when `$DSH_HOME` (or the default `~/.dsh`) exists, giving DSH its higher-priority `user-dsh` source and supporting custom DSH homes. Declare a custom `DSH_HOME` in the updater config—not only in interactive shell startup—so the macOS LaunchAgent sees it.

Override the exact list in `~/.config/agent-skills-updater/config`:

```bash
export AGENT_SKILLS_TARGETS="$HOME/.claude/skills:$HOME/.codex/skills"
```

## Update manually

```bash
update-all-skills
update-all-skills --dry-run
```

The runner is fail-late: all independent sources are attempted even if one fails.

| Status | Meaning | Scheduled notification |
| --- | --- | --- |
| `0` | Every updater succeeded | None |
| `1` or another nonzero status | At least one updater failed | Failure alert |
| `2` | An upstream change needs manual review | Review alert |

## Automatic updates on macOS

The installer uses macOS `launchd`, not cron. Calendar runs missed while the Mac sleeps are coalesced and run after wake.

- LaunchAgent: `~/Library/LaunchAgents/io.github.agent-skills-updater.plist`
- latest log: `~/Library/Logs/agent-skills-updater/latest.log`
- latest status: `~/Library/Logs/agent-skills-updater/latest-status`
- retention: 30 days

Install [`terminal-notifier`](https://github.com/julienXX/terminal-notifier) for clickable alerts; the built-in `osascript` fallback still displays notifications.

```bash
brew install terminal-notifier
```

Run the scheduled wrapper immediately:

```bash
"$HOME/.local/libexec/agent-skills-updater/run-scheduled-update"
```

## Configuration and pinning

`~/.config/agent-skills-updater/config` is a local shell configuration file. Use it to select targets, opt into conflict replacement, or pin upstream refs to commits/tags. See [`config.example`](config.example).

The defaults track upstream `main` branches so skills stay current. For sensitive or reproducible environments, pin revisions and review skill changes before using them.

## Uninstall automation

```bash
launchctl bootout \
  "gui/$(id -u)" \
  "$HOME/Library/LaunchAgents/io.github.agent-skills-updater.plist" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/io.github.agent-skills-updater.plist"
rm -f "$HOME/.local/bin/update-all-skills"
rm -rf "$HOME/.local/libexec/agent-skills-updater"
```

Canonical source checkouts and logs are intentionally retained. Remove `~/.local/share/agent-skills-updater` only if you no longer need the installed skill symlink targets.

## 中文说明

这个仓库现在不只是自动更新框架，而是一套可以直接安装的 Skills 组合。运行 `./install.sh` 后，会从各自官方上游获取 `thermo-nuclear-code-quality-review`、`sim-use`、OpenClaw `autoreview`、Matt Pocock 的全部非废弃 Skills，以及 Anthropic 未修改的原版 `code-simplifier`。它会自动识别 Claude Code、Codex、DeepSeek Harness（DSH）、Pi、Amp、Cursor；DSH 默认安装到 `~/.dsh/skills`，也支持 `$DSH_HOME`。macOS 上默认每天 10:00 自动更新，成功时保持安静，失败或需要人工 review 时才通知。

## Development

```bash
./tests/test.sh
```

## License

The automation code is MIT licensed. Third-party skills are fetched from their official sources at runtime and retain their upstream licenses.
