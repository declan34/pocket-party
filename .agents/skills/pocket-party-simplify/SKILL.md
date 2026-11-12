---
name: pocket-party-simplify
description: Use when simplifying or refactoring working Pocket Party code without changing its observable behavior.
license: MIT
---
# Simplify without changing meaning

Adapted from Addy Osmani's `code-simplification`; [provenance, original inspiration, and license](../../third-party/addyosmani/NOTICE.md).

Aim for easier comprehension, not fewer lines. Work on the requested code; do not turn feature work into a repository-wide cleanup.

1. Read the function/view, its callers, neighboring conventions, and relevant tests. Identify why the current boundaries exist before removing them. Inspect current dirty changes so cleanup does not absorb someone else's work.
2. State what must stay the same: outputs, diagnostic/error semantics, ordering, mutation, cancellation, saved formats, and supported platforms. For rules code, include earlier-level replay and repeated evaluation. For SwiftUI, include identity, state ownership, and presentation lifecycle.
3. Establish a baseline with applicable checks from `pocket-party-verify`. Add characterization coverage where needed; use `pocket-party-tdd` for that step without requiring an existing-correct behavior to fail first.
4. Make one coherent simplification, verify, then inspect the resulting structure. Useful moves include clearer names, guard clauses with unchanged failure ordering, exhaustive enum switches, removal of proven redundancy, and helpers that name a real concept.

Do not remove error handling, availability guards, snapshot pinning, or Codable compatibility merely because they add branches. A generic abstraction that moves the same complexity elsewhere is not automatically an improvement. SwiftUI view extraction must preserve state identity and export presentation, not just visual similarity.

Existing behavior checks should keep passing without weakened assertions. If a proposed cleanup changes behavior, separate that decision from the refactor and ask when it exceeds the task. If abandoning an attempt, undo only your own exact edits; do not reset or restore entire dirty files.

Summarize the complexity removed and verification performed. No line-count quotas, mandatory separate PRs, automatic commits, or extra reviewer loops are imposed by this skill.
