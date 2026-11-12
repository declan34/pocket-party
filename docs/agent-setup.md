# Repository agent setup — review draft

The repository carries one shared instruction set for Codex and Claude Code. No personal plugins, memory service, or global configuration are required. This draft changes guidance only, not app behavior.

## What to review

- [AGENTS.md](../AGENTS.md): app identity and cross-cutting constraints, plus one routing instruction.
- [Scoped rules](../.agents/rules): short invariants selected by repository-relative `paths` globs.
- [Skills](../.agents/skills): task-specific source maps and verification workflows, loaded when relevant.

| Area | Rule | Skill |
| --- | --- | --- |
| Rules and saved characters | [core](../.agents/rules/core.md) | [pocket-party-rules](../.agents/skills/pocket-party-rules/SKILL.md) |
| Packs and shared library | [content](../.agents/rules/content.md) | [pocket-party-content](../.agents/skills/pocket-party-content/SKILL.md) |
| Native UI and optional local AI | [ui](../.agents/rules/ui.md) | [pocket-party-ui](../.agents/skills/pocket-party-ui/SKILL.md) |
| Printable sheet and PDF | [pdf](../.agents/rules/pdf.md) | [pocket-party-pdf](../.agents/skills/pocket-party-pdf/SKILL.md) |
| Tests and evidence | [verification](../.agents/rules/verification.md) | [pocket-party-verify](../.agents/skills/pocket-party-verify/SKILL.md) |

The rules preserve existing product decisions and implementation guarantees. The skills point into existing documentation and code rather than duplicating the schema or embedding past conversations. Current MVP limitations live in README, not permanent prohibitions against extending the app.

## Adapted external skills

Five task workflows adapt Addy Osmani's collection for this native Swift app:

| Local skill | Purpose | Upstream skill |
| --- | --- | --- |
| [pocket-party-source-check](../.agents/skills/pocket-party-source-check/SKILL.md) | Verify version-sensitive native APIs | source-driven-development |
| [pocket-party-tdd](../.agents/skills/pocket-party-tdd/SKILL.md) | Behavior-first changes and regression coverage | test-driven-development |
| [pocket-party-debug](../.agents/skills/pocket-party-debug/SKILL.md) | Evidence-based diagnosis and scoped fixes | debugging-and-error-recovery |
| [pocket-party-simplify](../.agents/skills/pocket-party-simplify/SKILL.md) | Preserve behavior while reducing complexity | code-simplification |
| [pocket-party-review](../.agents/skills/pocket-party-review/SKILL.md) | Read-only, evidence-backed change review | code-review-and-quality |

[Workflow routing](../.agents/rules/workflows.md) selects these only for relevant tasks. The original five domain skills still describe where Pocket Party's behavior lives; these five describe how to approach particular kinds of work. Verification commands remain in `pocket-party-verify`.

The adaptations remove web-only tooling and examples, absent shared-checklist dependencies, and automatic workflow expansion. They preserve the user's latest AI boundary: recommendations may include mechanics, but accepted choices still pass deterministic validation. Chat-based recommendations are a future feature, not claimed as implemented here.

See [source fingerprints, changes, and attribution](../.agents/third-party/addyosmani/NOTICE.md) and the retained [MIT license](../.agents/third-party/addyosmani/LICENSE.txt). No upstream release/commit was recorded by the installer; provenance identifies the inspected originals by SHA-256 instead.

Distinct `pocket-party-*` names avoid same-name collisions with global skills. They do not disable global installations or override system instructions. Use the project workflow for the task and reuse evidence if a global workflow also applies, rather than performing the same checks twice. Global configuration is unchanged.

## How each tool loads them

**Codex:** reads the root `AGENTS.md` and discovers repository skills under `.agents/skills/`. Codex does not document native `paths`-glob instruction loading. The root instruction explicitly asks the agent to inspect rule frontmatter and read matching bodies before working on files. This is agent-followed routing, not an installed hook or automatic enforcement. Overlapping matches all apply.

**Claude Code:** current versions support `AGENTS.md` directly. `.claude/rules/` contains relative symlinks to the canonical rule files, letting Claude use its native `paths` matching. `.claude/skills/` contains relative symlinks to the same skill folders Codex discovers. Edit the canonical `.agents/` files, not duplicate copies. There is no `CLAUDE.md` wrapper.

Claude's AGENTS support requires version 2.1.277 or later. Under its default setting, project/ancestor `CLAUDE.md`, `.claude/CLAUDE.md`, or `CLAUDE.local.md` can prevent AGENTS loading. If that applies on another machine, use the current Claude `/config` project-instructions option to enable both instruction formats, or resolve the conflicting file intentionally. This repository does not change personal settings; that option is not a reliable project-level settings override.

See the official [Codex AGENTS guide](https://learn.chatgpt.com/docs/agent-configuration/agents-md), [Codex skills guide](https://learn.chatgpt.com/docs/build-skills), [Claude memory/AGENTS guide](https://code.claude.com/docs/en/memory#agentsmd), and [Claude skills guide](https://code.claude.com/docs/en/skills). Tool discovery behavior can change; these compatibility notes were checked on 2026-11-12.

## On another machine

1. Clone the repository with Git, preserving its relative symlinks. All targets stay inside the checkout; nothing points to this Mac.
2. Open the repository root in the agent. Start a new session after adding/changing discovery files.
3. Ask it to identify its loaded `AGENTS.md` and list the ten `pocket-party-*` skills. Invoke one relevant skill explicitly if discovery is unclear. For Claude, inspect its memory listing as well if an ancestor instruction file may interfere.
4. For a routing check, ask which rules apply to `Sources/FolioCore/PrintableSheet.swift`: core, PDF, and workflows. `Sources/FolioApp/SheetPDFView.swift` should select UI, PDF, and workflows. These routing checks do not demonstrate app correctness.
5. Follow README for the build environment. Agent instructions do not install Swift, Xcode, private packs, or the official PDF template.

When symlinks are not preserved, fix checkout configuration before relying on Claude discovery; don't replace links with independently maintained copies. Native UI/PDF development still requires Apple's tooling.

## Deliberately undecided

No new branch-naming policy, mandatory PR process, mandatory subagent review, or automatic commit/push rule is introduced here. If you want those standardized, we should choose them explicitly rather than infer them from a previous task.

Open review question: should ordinary feature work default to an isolated branch/worktree, or should that remain a per-task choice? Either answer fits this instruction layout.
