# Addy Osmani skill adaptations

Five Pocket Party skills adapt [Addy Osmani's agent-skills](https://github.com/addyosmani/agent-skills), copyright 2025 Addy Osmani, under the accompanying [MIT license](LICENSE.txt). These are locally maintained adaptations, not verbatim upstream releases or an upstream endorsement.

## Source snapshot

Adapted on 2026-11-12 from the owner's installed copies, installed that day from `addyosmani/agent-skills`. The installer recorded content hashes but no Git commit or release tag. The SHA-256 values below identify the exact original `SKILL.md` bytes inspected; they are not hashes of our adapted files. No upstream commit identity is claimed. Upstream links use `main` for discovery and may change.

| Local skill | Original path in upstream repository | Original file SHA-256 |
| --- | --- | --- |
| pocket-party-source-check | skills/source-driven-development/SKILL.md | `df38a852658679a67c7a9e4840160570c95094a13a63307e834045ddbf8aa287` |
| pocket-party-tdd | skills/test-driven-development/SKILL.md | `8fcaa57cf445ca6111fd20d2321bcfc0f424db7cfe526836db7b9bf8828fee39` |
| pocket-party-debug | skills/debugging-and-error-recovery/SKILL.md | `01cff31fbd8796b444225f8a8386219792c25cebb5d4d76df664afd1d13ed610` |
| pocket-party-simplify | skills/code-simplification/SKILL.md | `e13b433345e6bf425c3625442ac1b3507b371c18d7ea3e3db822da7a7f742a29` |
| pocket-party-review | skills/code-review-and-quality/SKILL.md | `a47551daf26e3cc5670f5286f9e4850c2fc662d5ba08b86eee895254f3851797` |

The upstream simplification skill also credits inspiration from Anthropic's [Code Simplifier agent](https://github.com/anthropics/claude-plugins-official/blob/main/plugins/code-simplifier/agents/code-simplifier.md); that attribution is retained here.

## Adaptation boundaries

- Retained source verification, red/green/refactor, root-cause triage, behavior-preserving simplification, and five-axis review.
- Replaced web-stack examples with Swift, SDK availability, local persistence, content snapshots, and PDF/native UI boundaries.
- Reused `pocket-party-verify` for commands rather than maintaining another test-command catalog.
- Removed browser tooling, backend deployment assumptions, fixed diff-size quotas, mandatory multi-model delegation, automatic commits, mandatory PR splitting, and repeated approval gates.
- Kept reviews read-only unless changes are requested. Removed automatic source mutation from the review checklist.
- Removed dependencies on absent upstream shared checklists and global companion skills. The adapted instructions contain the relevant checks or link to resources present in this repository.
- Used distinct names to avoid identical-name collisions with global installations. Global skills remain unchanged; these files do not disable host-level instructions.

Update deliberately: inspect the upstream diff and license, revise the adaptation, refresh provenance, and validate the affected workflow. Do not overwrite these files with an unreviewed upstream update. Preserve this notice and license when redistributing the adaptations.
