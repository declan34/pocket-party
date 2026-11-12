---
name: pocket-party-tdd
description: Use when adding or changing Pocket Party behavior, reproducing a bug in tests, or extending regression coverage for existing mechanics.
license: MIT
---
# Behavior-first regression work

Adapted from Addy Osmani's `test-driven-development`; [provenance and license](../../third-party/addyosmani/NOTICE.md).

Use the existing standalone Swift harnesses and real domain types. Read the relevant runner before adding a check: a test function that is never registered does not run. `pocket-party-verify` owns the command map; do not invent XCTest filters or add a new test framework as part of ordinary coverage work.

For new behavior or a reported defect:

1. State the expected input/output or invariant. Create the smallest original fixture that demonstrates it.
2. Add and run a check before changing production behavior. Confirm the failure is the intended assertion, not a toolchain error or broken fixture. An unreproduced bug remains a hypothesis.
3. Implement the smallest authorized correction, run the affected harness, then refactor with the checks still passing. Run the relevant complete harness before handoff and report any unrelated failures separately.

For coverage of existing correct behavior, a passing characterization check is useful: state that it passed initially and which defect it would detect. Do not break or delete working code to manufacture a red result. If mutation testing is explicitly requested, use an isolated disposable copy and preserve the user's checkout.

Assert results and meaningful diagnostics, not internal call sequences. Keep each scenario understandable; prefer real evaluation and disposable storage over mocks. Include boundary cases and repeated evaluation where they can expose state accumulation.

Example coverage target: after a Constitution increase, assert total HP at the new level, HP/scores when evaluated through an earlier level, and the same result on repeated evaluation. Inspect existing coverage before duplicating it.

UI helpers, native PDF behavior, and model generation need different evidence. Report absent templates/devices/private fixtures as skips; a stubbed response is not live AI proof. Pure documentation edits need document validation, not a fabricated behavioral red/green cycle. No commits, PRs, or additional agents are required by this skill.
