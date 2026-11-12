---
name: pocket-party-verify
description: Use when choosing or running Pocket Party regression checks, native smoke tests, or reporting build and device readiness.
---
# Verification map

Run commands from the repository root. Select checks for the changed behavior; documentation-only changes do not require an app build.

| Change | Existing check |
| --- | --- |
| Rules, model, storage, catalog, sheet projection | `swift run FolioChecks` |
| Presentation helpers | `bash scripts/check-presentation.sh` |
| Native app compilation | `swift build --product CharacterFolio` |
| Native PDF integration | `bash scripts/check-pdf.sh /absolute/path/to/blank.pdf /disposable/output` |
| Mac preview bundle | `bash scripts/build-preview.sh` |

These are standalone harnesses, not `swift test`/XCTest. Inspect harness output and prerequisites: a successful core run need not include the optional private Vessel fixture; absent PDF input exits as skipped. Do not hard-code historical check counts as the expected result.

For a native smoke test that changes data, build the preview, then launch its executable directly with a fresh library:

```sh
smoke_library=$(mktemp -d)
FOLIO_LIBRARY_PATH="$smoke_library" 'Preview/Character Folio.app/Contents/MacOS/CharacterFolio'
```

Do not assume launching through `open` passes the environment to an existing app process. Verify that the smoke instance has the isolated library before mutating it. Leave the user's normal library untouched; close the isolated instance when finished. Avoid two instances modifying the same library.

Check `xcode-select -p` and `xcodebuild -version` before claiming iPhone tooling is available. Command Line Tools can support the Mac harness without providing an iOS SDK. A native desktop build, an iPhone build, device testing, live AI output, accessibility, and distribution are separate evidence gates.

Report commands/results, skips/blockers, and any actual interactive checks. [Engineering notes](../../../docs/engineering.md) describe historical evidence, not a substitute for fresh verification. This skill does not authorize committing, pushing, or releasing.
