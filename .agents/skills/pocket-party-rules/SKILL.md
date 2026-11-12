---
name: pocket-party-rules
description: Use when changing Pocket Party character calculations, progression, saved choices, or persistence compatibility.
---
# Rules and persistence map

Paths below are repository-relative. Read the relevant sections of [engineering notes](../../../docs/engineering.md), then the affected implementation:

- `Sources/FolioCore/Models.swift`: Codable contracts and saved pack snapshots.
- `RulesEngine.swift`: replay of level choices and calculated results.
- `Validation.swift`: pack integrity and supported bounds, not build completion.
- `Persistence.swift`: library storage, backups, import/export, and corruption handling.
- `Tests/FolioCoreTests/`: executable scenario checks.

For a new mechanic, identify the input choice, calculated output, invalid-choice diagnostic, and earlier-level edits that can change it. Test repeat evaluation and editing an earlier decision as well as the happy path. Avoid introducing effects that depend on how many times evaluation ran.

For a model or persistence change, exercise an old-format original fixture, save/reload, and corrupt-input handling in a disposable directory. Inspect snapshot behavior before changing migrations or library updates. AppStore coordinates UI persistence; check its callers when changing save contracts.

Run `swift run FolioChecks`. Read the current harness to distinguish executed scenarios from optional private-fixture checks. Use `pocket-party-content` when the change also alters pack definitions or shared catalog identity.

The current supported slice is documented in [README](../../../README.md); extending it is product work, not permission to treat unsupported rules as already validated.
