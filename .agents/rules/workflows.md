---
paths:
  - "Sources/**"
  - "Tests/**"
  - "scripts/**"
  - "Package.swift"
  - "CharacterFolio.xcodeproj/**"
---
# Engineering workflow selection

Use the Pocket Party adaptation for the task at hand:

- Version-sensitive native API decisions: `pocket-party-source-check`.
- New behavior or regression coverage: `pocket-party-tdd`.
- Unexpected behavior or failures: `pocket-party-debug`.
- Behavior-preserving cleanup: `pocket-party-simplify`.
- Requested review of a change: `pocket-party-review`.

Read only relevant workflows alongside the domain skill. Reuse overlapping investigation and verification; do not repeat equivalent global-skill steps just because another skill describes them. Preserve any higher-priority instructions.

These skills do not introduce mandatory delegation, PRs, or commit/push permission. A diagnosis or review request remains read-only unless changes are requested.
