# Skill sources and distribution strategy

This pack installs the following opinionated set. Third-party skills are fetched directly from their official repositories at install/update time; they are not vendored here. This keeps provenance visible and avoids stale forks.

| Installed skill(s) | Official source | License | Strategy |
| --- | --- | --- | --- |
| `thermo-nuclear-code-quality-review` | [Cursor `plugins`](https://github.com/cursor/plugins/tree/main/cursor-team-kit/skills/thermo-nuclear-code-quality-review) | No repository-wide SPDX license detected by GitHub as of 2026-08-22 | Fetch the unmodified `SKILL.md` from Cursor at runtime; validate its frontmatter and record its SHA-256. It is not redistributed in this repository. |
| `sim-use` | [LY Corporation `sim-use`](https://github.com/lycorp-jp/sim-use) | [Apache-2.0](https://github.com/lycorp-jp/sim-use/blob/main/LICENSE) | Shallow-fetch the official repository and link its bundled skill. |
| `autoreview` | [OpenClaw `agent-skills`](https://github.com/openclaw/agent-skills) | [MIT](https://github.com/openclaw/agent-skills/blob/main/LICENSE) | Shallow-fetch the official repository and link only `autoreview`. |
| All non-deprecated Matt Pocock skills | [Matt Pocock `skills`](https://github.com/mattpocock/skills) | [MIT](https://github.com/mattpocock/skills/blob/main/LICENSE) | Shallow-fetch the official repository and link every directory containing `SKILL.md`, excluding `deprecated`. |
| `code-simplifier` | [Anthropic `claude-plugins-official`](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/code-simplifier) | [Apache-2.0](https://github.com/anthropics/claude-plugins-official/blob/main/plugins/code-simplifier/LICENSE) | Fetch Anthropic's unmodified agent file at runtime, validate its frontmatter, record its SHA-256, and expose it as `SKILL.md`. |

## Official code-simplifier compatibility

The upstream file is installed byte-for-byte, including its `model: opus` frontmatter. Claude Code supports that field. Pi ignores unknown frontmatter fields, so the same file still loads there; other Agent Skills consumers continue to receive the required `name` and `description` fields.

The original prompt includes JavaScript/React-oriented examples such as ES modules and explicit React prop types. This pack intentionally does not correct those assumptions: using the official file removes the maintenance fork, and repository-level instructions should take precedence when those examples do not apply.

## Trust model

The default refs intentionally track each upstream's `main` branch so daily updates receive current skill guidance. That is convenient but gives upstream maintainers a software-supply-chain role. Each checkout records the installed commit, and the Cursor single-file updater records a digest.

For stricter reproducibility, override refs or repository URLs before running `update-all-skills`:

- `SIM_USE_REF`
- `OPENCLAW_SKILLS_REF`
- `MATTPOCOCK_SKILLS_REF`
- `CODE_SIMPLIFIER_REF`
- `THERMO_SKILL_URL`

Use a commit SHA as the ref where the upstream server permits fetching it. Review remote skill content before first use in sensitive repositories.
