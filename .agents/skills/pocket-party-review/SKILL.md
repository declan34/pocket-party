---
name: pocket-party-review
description: Use when asked to review a Pocket Party diff, implementation, or proposed change for correctness and quality.
license: MIT
---
# Evidence-backed change review

Adapted from Addy Osmani's `code-review-and-quality`; [provenance and license](../../third-party/addyosmani/NOTICE.md).

Review the requested change without editing it. Identify the intended behavior, comparison base or supplied patch, and dirty worktree boundaries. If the review target is ambiguous, clarify rather than treating every local edit as part of the change.

Read tests first to establish intended behavior, then trace affected callers, guards, and data contracts. Evaluate relevant dimensions:

- **Correctness:** prerequisites, earlier-level replay, deterministic totals, pinned content, Codable compatibility, error paths, and cancellation/state races.
- **Readability:** meaningful names, understandable flow, cohesive responsibilities, and simplifications that actually reduce complexity.
- **Architecture:** FolioCore owns rules; UI coordinates choices; PDF projects existing results. Avoid duplicate calculations and unjustified dependencies.
- **Security/privacy:** bounded untrusted imports, preservation of private content boundaries, local file handling, and sensitive data in logs/exports. Check actual data flows rather than assuming an account/backend exists.
- **Performance:** repeated evaluation, main-thread file/image/PDF work, collection growth, and retained data. Describe demonstrated or clearly supported risks; do not invent timings.

Validate each suspected defect against callers, guards, and tests. Distinguish introduced regressions from pre-existing issues and stylistic preferences. Zero findings is a valid result. A file's size or an arbitrary diff-line limit is not itself a defect.

Use `pocket-party-verify` to choose relevant non-mutating diagnostic checks. Do not invert conditions, rewrite tests, remove code, or restore files to test your hypothesis during a read-only review. If isolated mutation testing would materially help, propose it separately. Never overwrite unrelated or concurrent edits.

Report findings by severity, each with a file/line, concrete triggering condition, user impact, and a suggested correction. Put optional improvements separately; do not invent mandatory cleanup, issue creation, or a new merge policy. State which checks actually ran, skipped prerequisites, and limits such as untested device or AI behavior.

The result is a review, not permission to implement fixes, spawn reviewers, commit, merge, push, or release. Reuse an existing review's still-applicable evidence rather than repeating the same review because another workflow also names it.
