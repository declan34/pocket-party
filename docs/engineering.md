# Engineering notes

## Architecture

The schema-2 interface is documented in [capability-interface.md](capability-interface.md). `Capabilities.swift`, `CapabilityValidation.swift`, `CapabilityEngine.swift` and `RulesUpgrade.swift` separate typed contracts, bounded validation, replay and explicit review-copy migration. `CapabilityEditor.swift` edits declarative choices; legacy `RulesEngine` replay remains the schema-1 boundary. The [coverage matrix](capability-coverage.md) distinguishes original mechanism evidence from actual private adapter acceptance and unresolved source blockers.

- `Sources/FolioCore/Models.swift`: Codable data-only pack, character, and level-choice contracts. Character records pin a full pack snapshot.
- `RulesEngine.swift`: deterministic evaluation from choices, not incremental bonuses. Replaying historical choices catches invalid earlier levels and avoids accumulated/stat-stacking state.
- `Validation.swift`: bounded import validation and reference integrity. Separate content structure from build completeness so unfinished drafts can be saved.
- `Persistence.swift`: atomic local save, previous-file backup, versioned documents, character export, bounded narrative prompt construction.
- `Sources/FolioApp/`: SwiftUI library, level editor, sheet, story and optional Apple Foundation Models integration. Suggestions require explicit acceptance and never touch build choices.
- `scripts/convert-vessel-pack.mjs`: curated adapter from existing corrected Foundry/YAML sources into private portable data, with source hashes and unresolved-reference diagnostics.
- `Tests/FolioCoreTests/`: standalone Swift regression executable, no third-party testing dependencies.
- `ContentCatalog.swift`: source-qualified shared choices, last-installed revisions for new snapshots, opt-in additive choices for pinned builds.
- `PrintableSheet.swift`: pure rules-output-to-sheet projection, with untracked state blank and conditional rules in notes.
- `Sources/FolioPDF/SheetPDF.swift`: fingerprinted local template, native editable form filling, measured overflow and selectable Core Text supplements. `SheetPDFView.swift` hosts a read-only native preview of the same export bytes.

## Shared library and sheet verification (2026-10-30)

- Core: 28 scenario checks, including catalog collisions/revisions/partial packs/privacy/pinning and calculated sheet fields. Presentation: 8 checks. Native PDF integration checks reopen the actual supported template, verify every populated level-five caster field, Unicode, proficiency flags, blank combat state, draft marking, long-story pagination, preservation of the blank master and rejection of invalid replacement templates.
- Native PDF checks require a locally supplied official blank PDF; missing input is reported as SKIPPED with nonzero exit. Run `bash scripts/check-pdf.sh /path/to/blank.pdf /tmp/folio-pdf-checks`.
- Source identity uses SHA-256 of source ID, version, record type and local ID. Different source definitions are not silently deduplicated. Source-pack schema remains unchanged because partial collections were already structurally permitted; semantic validation now permits them.
- The supported template's URL, exact SHA-256 and widget map are in `SheetPDF.swift`. The PDF itself is not bundled. A publisher revision requires explicit mapping/compatibility review.
- Native PDFKit prints orphan-field warnings for the official form's field tree; pypdf reports unused object offsets when reopening generated files. Populated widget values match the canonical AcroForm values and retain appearance streams/editable flags. These warnings are documented, not treated as evidence of universal PDF-reader compatibility. Acrobat/third-party editing remains unverified.
- A fresh-context read-only reviewer found two projection issues: pre-spellcasting DC/attack numbers and missing Known/Granted classifications beyond 30 main-form rows. Both have failing-then-passing regressions and fixes. A UI-discovered whitespace-only page also has a regression.
- Isolated native UI smoke confirmed one class picker with both sources, cross-pack species, source-disambiguated backgrounds, preserved old builds and the populated read-only PDF preview. The PDF export button initially failed to open its dialog with nested SwiftUI exporters. A single character-level export presenter now handles explicitly typed JSON/PDF payloads. After the Mac was unlocked, native checks passed for PDF save/cancel/reopen, importing the supported blank template, updating a character name and seeing it in the regenerated preview/export, and switching back to a correctly named JSON export dialog. The saved PDF reopened with the updated canonical/widget values and editable flags; the imported blank master remained byte-identical. Screenshot: `Preview/verified-sheet-export.png`.
- User saves were not used as test fixtures. All smoke mutations used `FOLIO_LIBRARY_PATH` in an isolated temporary directory. iPhone compilation/device, Dynamic Type, VoiceOver and live AI remain unverified.

The approved visual direction uses white backgrounds, black primary actions, pale gray pill rows, system sans typography, and circular portraits with safe initials fallbacks. Color stays with the characters. The library has collection/list modes and name/class search; Story uses large concept editing and non-destructive prompt hints. No externally downloaded imagery or fonts are required. Final ability totals are on Sheet; Build separates base choices from background bonuses. Portrait display is circular but the original imported image bytes are retained.

## Reference-led UI verification (2026-10-30)

- All 26 core checks and 8 new presentation checks pass; native Mac preview builds and its ad-hoc signature verifies.
- The new presentation checks were run failing before the helper implementation; they cover blank, multiword and Unicode names plus trimmed, accent-insensitive name/class searching.
- Native walkthrough at approximately 452 points wide exercised collection/list switching, empty-search recovery, existing Mara restoration, ability-score rows, calculated Sheet, Story prompts, unavailable AI feedback, and opening/cancelling character creation. Screenshots are in `Preview/reference-{library,builder,story}.png`.
- A fresh-context read-only reviewer found no blocking regressions. Duplicate error presentation was noted and corrected. Core rules, models, persistence, content resources and AppStore are unchanged against the pre-redesign source backup.
- This is not iPhone, Dynamic Type, VoiceOver, live generation, or distribution proof. Those gates remain unverified. No characters were created or modified during this UI walkthrough.

## Verification boundaries

At the initial MVP handoff:

- Native macOS Swift package/app compiled with Swift 6.3.2, MacOSX26.5 SDK; ad-hoc bundle signature verified.
- Standalone core checks exercised a complete level-1–5 build, incomplete choices, earlier-level edits, replacement rules, feat prerequisites, HP recalculation, malformed packs, persistence/backup, corruption protection, exports, bounded AI context, and the converted private Vessel pack.
- Native UI walkthrough exercised sample creation, calculated sheet, story editor, private pack import, and persisted library restoration after restart. Apple Intelligence reported `appleIntelligenceNotEnabled`; generation was disabled cleanly. Real generated output is **not verified** on this machine.
- Xcode project plist syntax was validated; no iOS SDK/simulator or Xcode application is installed. iPhone layout, compile, signing, model generation, and device performance remain unverified.
- No TestFlight/App Store submission, release, push, or public deployment occurred.

## Known content limitations

Private conversion includes a curated Vessel level-1–5 slice with all six supplied subclasses, two species, two backgrounds and supported feats. It does not convert every Foundry advancement/effect. Required unresolved spells remain explicit build blockers. Some inherited descriptions have extraction defects; reviewed mechanical corrections are provenance-backed, not a claim that every paragraph is clean. Review descriptions before using them as the sole rules reference.

Earlier review removed Cursed/Formless from the schema-1 adapter because bonus Aspects were unsupported. Schema 2 now represents their canonical locked bonus choices and alternatives. Existing schema-1 snapshots remain unchanged. The separate single-window safeguard remains in place.

The private output includes legacy supplementary spells when no revised 2024 source exists. `ruleset: 2024` names the builder conventions, not a guarantee that every imported description was published in 2024.

## Next engineering increments

1. Actual iPhone build/test, compact-width and Dynamic Type testing, local AI generation and cancellation smoke tests.
2. Explicit class-specific choice/replacement policies, richer proficiencies, equipment and armor choices; complete remaining sheet dialog/device checks.
3. More fully reviewed 2024 species/classes/feats; selected spell casting beyond a single uniform slot pool.
4. Levels 6–20 and multiclass prerequisites/progression; optional migration between pack versions with a review screen.
5. Portrait generation through an explicitly chosen on-device image API, accessible app icon, distribution/signing and public license review.

Keep content adapters separate from the rules engine. Add a regression for each new calculated mechanic; never infer automation from description text or use an AI answer as the validator.

## Early capability coverage verification

The standalone harness accepts optional exact check names, for example `swift run FolioChecks vesselCapabilityChecks capabilityFamilyMatrixChecks`; no arguments still runs every registered check. Private acceptance prints an explicit SKIP when its input is absent. Public fixtures are generated deterministically by `scripts/build-example-pack.mjs`; the schema is generated by `scripts/build-schema.mjs`. Neither private acceptance nor Mac compilation proves iPhone execution, fresh PDF rendering, native UI interaction or live AI behavior.

## I3 source casting and preparation

`Spellcasting.swift` is the projection/configuration phase of the existing capability replay, not a second evaluator. Historical acquisition still runs in `CapabilityEngine`; current loadouts are validated after source ability effects. Required `spell-pools` capability gates newer contracts. Native editing, summary and PDF consume the same source summaries.

For isolated controller interaction, create a fresh directory and run `FOLIO_I3_SMOKE_LIBRARY=/absolute/disposable/path swift run FolioChecks spellPublicSmokeChecks`. Launch `Preview/Character Folio.app/Contents/MacOS/CharacterFolio` with `FOLIO_LIBRARY_PATH` set to that directory. The public Notebook Keeper has two learned book spells, one editable preparation, ordinary tier-1/tier-2 capacities and a distinct short-rest Echo pool with a different casting ability. The helper refuses to overwrite an existing library. Change preparation, check the source-labeled Sheet, reopen, and confirm acquired book/history remain intact. No production seeding path or user library is touched.

`Tests/FolioPDFChecks/Checks.swift` also renders `tiered-casting-2024.pdf`: nine ordinary tier widgets, distinct custom capacity, two abilities and 35 book members. The template remains local/fingerprint checked. Native widget/text reopening is automated; visual inspection and third-party editing are separate evidence. New sample version is 1.4.0; private converter is 0.5.0. Older snapshots retain their original rules.

Observed PDF portability limitation: Poppler rendering can omit the non-Latin character 李 from the fixed-Helvetica name-widget appearance even though the canonical field value and supplement header preserve it. This is a real visual glyph-appearance defect, not data loss or merely an orphan-widget warning. Unicode serialization checks do not prove universal appearance fidelity. Font/appearance redesign is deferred beyond I3; do not claim universal non-Latin widget rendering or third-party reader compatibility.

### Earlier I2 evidence

Evaluator 2 accepts 1–20 consecutive levels; schema-1 records remain limited to five. The existing creation/HP/feat replay is reused internally with an explicit pinned-evaluator boundary, not replaced by a second legacy engine. Per-class improvement rows remain authoritative. Capability replay now checks each historical row's score cap, rejects missing active table rows, and projects acquired save ranks in native/PDF summaries. Cap grants are fixed declarations, not executable expressions. Repeatable scalar feat benefits/grants are applied per acquisition, while canonical choice tracks remain shared.

The public Summit Warden demonstrates a twenty-level martial path. For an isolated controller smoke fixture, create a new empty directory and run `FOLIO_I2_SMOKE_LIBRARY=/absolute/disposable/path swift run FolioChecks highLevelPublicFixtureChecks`. The test refuses to overwrite an existing library. Launch the preview executable with `FOLIO_LIBRARY_PATH` pointing at that directory. The original level-19 character can advance to 20; editing level-4 Constitution replays HP, and removing/re-adding 20 replays the capstone. This helper is test-only, with no production seeding path.

The older five-level coverage and converter descriptions above are historical evidence, not current scope. Current private source coverage/blockers are in `capability-coverage.md`. I2 retains uniform spell pools; multiclass, tiered pools, equipment and encounter state are separate increments. Native interactive and editable-PDF checks belong to the controller; missing template/device gates must remain explicitly unverified.
