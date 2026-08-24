# What `dsh-find-simplifications` teaches this pack

Reviewed against DeepSeek Harness commit [`b150a551`](https://github.com/deepseek-ai/deepseek-harness/commit/b150a551b8d465e31e418e1b2eaf5e79bbb7d28e).

## Primary source

The repository-scoped [`dsh-find-simplifications` Skill](https://github.com/deepseek-ai/deepseek-harness/blob/b150a551b8d465e31e418e1b2eaf5e79bbb7d28e/.agents/skills/dsh-find-simplifications/SKILL.md) turns broad cleanup requests into a small number of evidence-backed deletion or collapse proposals. Its strongest reusable ideas are:

1. **Classify consumers before proposing deletion.** Separate production callers from tests, docs, snapshots, generated output, and ambiguous examples/scripts. Exact-symbol search is discovery; reading call sites is proof.
2. **Prefer proved candidates over candidate count.** Strong candidates remove unused public surface, duplicated representations of one fact, speculative product generality, or a seam every implementation carries but no consumer uses.
3. **Audit ownership and lifecycle state.** Map defensive copies, validators, sentinels, readiness promises, cancellation paths, and disposers to distinct trust boundaries or lifecycle transitions. Mirrored mechanisms for one fact are simplification candidates.
4. **Judge dependencies by net deletion.** A maintained dependency or runtime builtin is a simplification only when implementation, dedicated tests, and documentation disappear and residual glue does not recreate the same complexity. This is the policy recorded in DeepSeek Harness's [dependency Agent Note](https://github.com/deepseek-ai/deepseek-harness/blob/b150a551b8d465e31e418e1b2eaf5e79bbb7d28e/.agents/notes/implemented/process/2026-07-26-dependencies-over-hand-rolling.md).
5. **Treat tests as evidence of behavior, not proof that behavior deserves to exist.** The worked [mutable session summary removal](https://github.com/deepseek-ai/deepseek-harness/blob/b150a551b8d465e31e418e1b2eaf5e79bbb7d28e/.agents/notes/implemented/simplification/2026-06-19-drop-mutable-session-summary.md) deleted tested persistence surface after proving it had no production consumer.
6. **Make trade-offs explicit.** A durable simplification proposal should state the current evidence, exact deletion, strongest counterargument, capability given up, acceptance criteria, and risks.

## Immediate action taken

Switching this pack from a locally adapted `code-simplifier` to Anthropic's official version removed the only updater that could produce an `ATTENTION` result. Every remaining `run_update` call passed `-1` as its attention code, so `update-all-skills` still carried an unproducible state, branch, counter, summary label, documentation, and exit path.

The aggregate runner now has only two real outcomes: all updaters succeeded (`0`) or at least one failed (`1`). The scheduled-update wrapper deliberately retains its documented handling of direct status `2`, because `install-launch-agent` accepts an arbitrary external update command; that is a public extension contract with plausible consumers, not dead internal state.

## What not to copy

Do not install the DeepSeek Skill globally or add it to this pack unchanged. Its description explicitly scopes it to `deepseek-harness`, and its required architecture docs, Agent Note lifecycle, protected adapter/backend decisions, validation commands, and relative links do not exist in other repositories.

Do not create a generic fork immediately. The existing `codebase-design`, `improve-codebase-architecture`, `code-simplifier`, and strict review Skills already cover adjacent jobs. First apply the evidence rubric during real audits; create a dedicated generic Skill only after repeated use proves a distinct trigger and output contract. That avoids responding to a simplification lesson by adding speculative surface.

## Reusable review rubric

For a future simplification audit, require each candidate to answer:

- What exact production consumers exist?
- Are tests/docs the only consumers, and does the behavior still deserve support?
- What interface, implementation, tests, configuration, and documentation disappear?
- Does complexity vanish, or merely move behind another wrapper?
- Which trust boundary, owner, or lifecycle transition requires each defensive mechanism?
- What capability is knowingly given up, and under what evidence should it return?
- Does an existing ADR or project decision already justify the current design?

Reject candidates that cannot answer those questions with file and call-site evidence.
