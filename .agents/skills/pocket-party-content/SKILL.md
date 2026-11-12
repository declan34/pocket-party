---
name: pocket-party-content
description: Use when creating or converting Pocket Party content packs, changing their schema, or changing the shared content catalog.
---
# Content workflow

Start with [the pack contract](../../../docs/content-packs.md), [JSON Schema](../../../docs/content-pack.schema.json), and the affected Swift models/validation. Paths below are repository-relative.

Choose the relevant route:

- Public example: edit `scripts/build-example-pack.mjs`, regenerate with `node scripts/build-example-pack.mjs`, and inspect the resulting `Sources/FolioCore/Resources/example-pack.json` diff.
- Contract: coordinate `Models.swift`, `Validation.swift`, `scripts/build-schema.mjs`, and the pack documentation. Run `node scripts/build-schema.mjs` when changing the generated schema; inspect rather than accept unrelated generated changes.
- Private Vessel conversion: read `scripts/convert-vessel-pack.mjs` and the README's converter instructions first. It consumes corrected extracted sources, not the original PDFs, and requires the importer's installed `js-yaml`. Resolve the source checkouts on the current machine; do not assume the owner's directory layout. Missing sources are a reported prerequisite, not a reason to reconstruct copyrighted content from memory.
- Shared catalog: inspect `Sources/FolioCore/ContentCatalog.swift` and `Tests/FolioCoreTests/CatalogChecks.swift`. Exercise same-name/different-source records, revisions, partial packs, privacy propagation, pinned builds, and opt-in additive choices as relevant.

Run `swift run FolioChecks` for contract/catalog changes. Check reference integrity and unsupported-mechanic diagnostics, not just JSON parsing. Preserve provenance in conversion reports and inspect Git status for accidental private outputs before handoff.

Character exports embed content snapshots. Treat exports and PDFs containing private definitions as private, even when made through the public app.
