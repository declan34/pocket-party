---
paths:
  - "Sources/FolioCore/**/*.swift"
  - "Tests/FolioCoreTests/**/*.swift"
---
# Rules and saved characters

- Derive statistics by replaying choices. Do not accumulate bonuses in mutable character state.
- Revalidate later choices after earlier-level edits. Keep unsupported mechanics explicit; feature prose is not implemented behavior.
- Keep content validation separate from character completeness: an unfinished build can still be saved.
- Preserve pinned definitions and choices when offering additional library content. Never silently upgrade saved builds to an installed pack revision.
- Preserve Codable compatibility, atomic saves, the previous-file backup, and protection against overwriting corrupt libraries.
- Keep internal CharacterFolio identifiers and save paths compatible unless the task includes a migration.

For mechanics or persistence work, use `pocket-party-rules`. For pack identity/schema work, also use `pocket-party-content`; for sheet projection, use `pocket-party-pdf`.
