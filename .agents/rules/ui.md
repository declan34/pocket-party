---
paths:
  - "Sources/FolioApp/**/*.swift"
  - "Tests/FolioPresentationChecks/**"
---
# Native experience

- Preserve the approved direction: white surfaces, black primary actions, pale-gray pill rows, system typography, circular portraits; color belongs mainly to character artwork.
- Keep one combined library, with source labels for same-name variants. Do not add a mandatory content-pack selection step.
- Keep Build choices, calculated Sheet, and editable Story distinct.
- Preserve original portrait bytes; circular cropping is presentation only.
- Keep AI optional and on-device, with explicit accept/discard. Unavailable AI must not block ordinary editing; do not add a cloud fallback implicitly.
- AI may recommend features and ability-score allocations. Apply accepted mechanical choices through normal rules validation; model output cannot bypass prerequisites, allocation limits, or supported mechanics.
- Use an isolated `FOLIO_LIBRARY_PATH` for UI tests that create or change records, never the user's real library.

Use `pocket-party-ui` for native workflows and AI checks. Sheet preview/export changes also use `pocket-party-pdf`.
