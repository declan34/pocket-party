---
name: pocket-party-ui
description: Use when editing Pocket Party SwiftUI screens, presentation helpers, portrait handling, or optional on-device story generation.
---
# Native UI workflow

Read the approved visual direction and relevant UI verification notes in [engineering notes](../../../docs/engineering.md). Paths below are repository-relative.

Find the actual owner before editing:

- `Sources/FolioApp/Theme.swift` and `Presentation.swift`: shared appearance and presentation helpers.
- `LibraryView.swift`: collection/list modes, search, and entry points.
- `CharacterView.swift`: Build/Sheet/Story flow and export presentation.
- `AppStore.swift`: library actions and persistence coordination.
- `StoryView.swift`: narrative editing, portrait import, and Foundation Models availability/generation.

Keep mechanical calculations in FolioCore. UI work should not redefine rules or refresh pinned content implicitly. Check empty/missing-portrait states and long names as well as a populated example.

For AI changes, inspect current SDK availability gates and model availability handling. Exercise unavailable feedback, cancel/navigation, and accept/discard separately. A graceful unavailable state is not proof of generated output. Keep narrative editing functional without Apple Intelligence.

Run `bash scripts/check-presentation.sh` for helper changes and `swift build --product CharacterFolio` for native compilation. Use `pocket-party-verify` for an isolated native smoke test; include the changed flow, narrow width, and relevant accessibility checks. Report unperformed device/accessibility checks explicitly rather than inferring them from a desktop screenshot.

PDF UI changes also use `pocket-party-pdf`; the export presenter spans `CharacterView.swift` and `SheetPDFView.swift`.
