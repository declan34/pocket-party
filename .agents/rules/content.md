---
paths:
  - "Sources/FolioCore/Models.swift"
  - "Sources/FolioCore/Validation.swift"
  - "Sources/FolioCore/ContentCatalog.swift"
  - "Sources/FolioCore/Resources/**"
  - "PrivatePacks/**"
  - "scripts/build-example-pack.mjs"
  - "scripts/build-schema.mjs"
  - "scripts/convert-vessel-pack.mjs"
  - "docs/content-pack*"
---
# Content contracts

- Packs are declarative data, not executable scripts.
- Keep source-qualified identity; do not merge distinct definitions solely because their names match.
- Keep class-specific subclasses and talents attached to their class; share only the supported catalog collections.
- Keep private conversion output in ignored `PrivatePacks/`. Read upstream extracted sources without modifying those repositories.
- Preserve source provenance and report unresolved references; do not invent replacement rules or spell descriptions.
- Keep public examples original. A private flag does not make an export safe to publish.

Use `pocket-party-content` for the schema, generators, conversion boundaries, and catalog regression cases.
