---
paths:
  - "Tests/**"
  - "scripts/check-*.sh"
  - "scripts/build-preview.sh"
  - "scripts/Preview-Info.plist"
  - "Package.swift"
  - "CharacterFolio.xcodeproj/**"
  - "docs/engineering.md"
---
# Verification evidence

- Use the standalone regression executables; this repository does not use an XCTest target.
- Add regression coverage for new calculated mechanics; retain cases for earlier-level edits and recomputation.
- Use original fixtures for public tests. Identify checks skipped because private data or a local PDF template is absent.
- Keep command checks, native UI checks, iPhone/device checks, live AI checks, and distribution evidence separate. A Mac build does not prove an iPhone build.
- Record current command results rather than copying historical test counts or treating engineering notes as fresh verification.

Use `pocket-party-verify` for commands, isolated smoke testing, and evidence boundaries.
