# Skill context audit

Reference: [Rethinking skills and prompts for GPT-6 Astra](https://developers.openai.com/blog/rethinking-skills-and-prompts-for-gpt-6-astra).

The article recommends precise descriptions, progressive disclosure, fewer rigid recipes, explicit safe decision boundaries, and task-specific completion criteria. Its claims about model defaults are model-specific; this pack serves multiple harnesses and models. Safety rules and project verification contracts are not obsolete merely because a model improved.

## Reviewed local payloads

| Skill | Evidence | Local decision |
| --- | --- | --- |
| `diagnosing-bugs` | Description includes any report of broken/failing/slow behavior. Body requires six phases, prohibits hypotheses without an executable reproduction, and requires 3–5 hypotheses before testing. | Disable for routine discovery. Useful techniques remain available in the retained source; ordinary debugging does not require this prescribed workflow. |
| `research` | Body unconditionally requires a background agent and a Markdown artifact, including for documentation lookup. | Disable; delegation and a durable report should follow the task's needs. |
| `code-review` | Description includes work-in-progress review, but its fixed comparison is `<base>...HEAD`, excluding uncommitted edits. Requires two agents and assumes an issue-tracker setup. | Disable; keep explicitly requested `autoreview` available. |
| `sim-use` | Provides a concrete executable's command contract. | Retain. Overlap with another device tool alone is not sufficient evidence to remove it. |
| `writing-for-agents` | Provides specific document and skill design guidance. | Retain. |

These are observations about installed payloads at audit time, not permanent judgments about upstream projects. The local opt-out is:

```bash
export AGENT_SKILLS_DISABLED="diagnosing-bugs research code-review"
```

Pack defaults remain unchanged for other users. Selection is applied at the managed link layer; upstream content is neither rewritten nor deleted. Re-enable by removing a name and running the updater. Reload the harness afterward: an existing conversation already contains its skill index.

## Boundaries and follow-up

- This audit does not alter BriefFeed's privacy, cache, testing, release, or device-QA contracts.
- `librarian`, project-local device skills, and pi package skills are not managed by this pack; leave them untouched here.
- Do not add description overlays or model-specific prompt forks without evidence that maintaining them is worth the cost.
- Validate the local selection with representative bug fixes, documentation lookups, and reviews. Compare unnecessary file reads, orchestration and artifacts, but also missed defects and incomplete verification. No behavioral improvement is claimed until those comparisons are performed.
- Independent of skill selection, task prompts should define completion and authorize safe local iteration rather than prescribing every intermediate step. External publication and production operations retain their existing authorization boundaries.
