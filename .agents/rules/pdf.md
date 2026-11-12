---
paths:
  - "Sources/FolioCore/PrintableSheet.swift"
  - "Sources/FolioPDF/**"
  - "Sources/FolioApp/SheetPDFView.swift"
  - "Tests/FolioCoreTests/SheetChecks.swift"
  - "Tests/FolioPDFChecks/**"
  - "scripts/check-pdf.sh"
---
# Printable sheet

- Keep the official blank template locally imported and fingerprint-checked; do not bundle it.
- Use the same generated PDF bytes for preview and export. Keep the Summary available alongside the 2024 sheet.
- Leave untracked combat/equipment values blank. Mark incomplete builds as drafts and explain conditional statistics instead of inventing totals.
- Preserve Known/Granted meanings even when the official form says Prepared Spells, including overflow lists.
- Preserve editable AcroForm values, widget values, and appearances. A screenshot alone does not verify editable export correctness.
- Keep PDF edits independent of saved character data; do not silently import reader edits back into the build.

Use `pocket-party-pdf` for template compatibility and export verification.
