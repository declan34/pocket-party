---
name: pocket-party-pdf
description: Use when changing Pocket Party's 2024 sheet projection, local template handling, PDF preview, or editable PDF export.
---
# Sheet and PDF workflow

Read the sheet section of [README](../../../README.md) and PDF verification boundaries in [engineering notes](../../../docs/engineering.md). Paths below are repository-relative.

Trace changes across these boundaries:

- `Sources/FolioCore/PrintableSheet.swift`: pure projection from calculated character data.
- `Sources/FolioPDF/SheetPDF.swift`: template hash/widget map, native filling, and supplements.
- `Sources/FolioApp/SheetPDFView.swift` and `CharacterView.swift`: preview and the shared JSON/PDF export presenter.
- `Tests/FolioCoreTests/SheetChecks.swift` and `Tests/FolioPDFChecks/Checks.swift`: projection and native integration scenarios.

For a new template revision, inspect actual fields and validate compatibility before changing the accepted hash. Do not bypass fingerprint checks just to accept a different PDF.

Run `swift run FolioChecks` for projection changes. With a user-supplied supported blank template, run from the repository root:

```sh
pdf_check_dir=$(mktemp -d)
bash scripts/check-pdf.sh /absolute/path/to/blank.pdf "$pdf_check_dir"
```

Missing template input is a skipped integration check, not a pass. Do not commit the template or rendered private output.

Reopen generated PDFs and verify canonical form values, widget values, editability, appearance, and preservation of the blank master. Render/inspect layout for overflow, long text, and unwanted blank pages. For export UI changes, test save, cancel, reopen, changed character data, and switching back to JSON; an exporter mounted in the wrong SwiftUI hierarchy previously failed to show its dialog.

Keep native PDFKit verification separate from third-party reader editing and iPhone save-dialog evidence.
