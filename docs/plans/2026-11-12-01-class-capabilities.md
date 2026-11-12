# Edition-aware class capabilities Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans task-by-task. The owner has approved execution; no additional routine approval checkpoint.

**Goal:** Make early-level class building extensible, edition-aware and backward-compatible.

**Architecture:** Keep schema-1 evaluation unchanged behind an explicit legacy boundary. Add optional schema-2 contracts to existing Codable envelopes, with typed rule data and a separate replay evaluator; SwiftUI and PDF consume its calculated summary. Saved schema-2 builds pin their evaluator and edition.

**Tech Stack:** Swift 6, SwiftUI, Codable, Foundation/PDFKit, standalone regression executables, Node generators.

**Spec:** `docs/designs/2026-11-12-rules-expansion.md`

## Global Constraints

- Keep existing schema-1 packs and characters readable and evaluable with their current semantics.
- Public examples remain original; private definitions remain imported and private.
- Source-pack references remain self-contained for this roadmap.
- AI may recommend mechanical choices; the deterministic engine validates accepted choices.
- Each increment includes engine/schema changes, usable SwiftUI controls, summary/PDF projection, public original fixtures, docs, and regressions for its own scope.
- No forced pushes, unrelated changes, content publication, release tags, or App Store distribution.
- Increment 1 supports levels 1–5 and a uniform slot pool only; future mechanics fail explicitly.

## Review Focus

1. A legacy character in a library with schema-2 packs must not change evaluation or saved identity.
2. A false/unsupported prerequisite must never become a valid result merely because its prose exists.
3. Removing a grant must remove its modifiers and dependent choices on repeat replay.
4. Same-name definitions from different editions/sources must not merge or become implicitly compatible.
5. A private missing spell reference must remain a visible blocker, not a fabricated replacement.

### Task 1: Deliver the typed engine and native foundation

**Files:**
- Create `Sources/FolioCore/Capabilities.swift`, `CapabilityValidation.swift`, `CapabilityEngine.swift`, `RulesUpgrade.swift` for typed contracts, bounded validation, replay, and explicit copy migration.
- Create `Sources/FolioApp/CapabilityEditor.swift` for additional choices/configuration; keep existing shared presentation.
- Modify `Models.swift`, `RulesEngine.swift`, `Validation.swift`, `ContentCatalog.swift`, `PrintableSheet.swift`, `Sources/FolioApp/{AppStore,CharacterView,LibraryView}.swift` to route new data without changing schema-1 semantics.
- Create `Tests/FolioCoreTests/CapabilityChecks.swift`; register checks in `FolioCoreTests.swift`.
- Modify `scripts/build-schema.mjs`, `scripts/build-example-pack.mjs`, generated public resources/schema and content/engineering docs for the foundation interface. Task 2 owns final README/coverage/private converter acceptance.
- Create `docs/capability-coverage.md`; use the controller's pre-implementation source inventory.

**Interfaces:**
- Preserve `RulesEngine.evaluate(_:in:through:) -> CharacterSummary` and `advance(_:in:) -> CharacterBuild` as public facade methods; dispatch schema-1 unchanged and schema-2 to `CapabilityEngine.evaluate`.
- Add optional versioned capability data to packs, level choices and builds; absent data decodes as legacy, not an inferred upgrade. Schema-2 build rules profile must be explicit.
- Add typed choices, prerequisites (bounded all/any/not), grants/modifiers, conditional configuration, proficiency ranks, resource tables/recovery and casting selection policy. No scripts or free-form expression evaluator.
- `RulesUpgrade.copy(_ record: CharacterRecord) throws -> CharacterRecord` creates a distinct ID and snapshot/profile, retaining original content/story/portrait/history and exposing unresolved differences for review; it never saves over the source.
- Extend `CharacterSummary` with supported traits, ranks, resource capacities, provenance and support diagnostics, using defaulted new fields so legacy callers remain source-compatible.
- Exact nested type names may follow Swift conventions; document the implemented schema and exported interfaces for later deliveries. Use separate small files for prerequisite/modifier replay if required rather than a monolithic evaluator.

- [ ] Add registered characterization checks for old-format decode/evaluation/round-trip/pinned library and corrupt-library protections; run and record their initially passing baseline.
- [ ] Add failing `CapabilityChecks`: original martial, known/prepared/book/subclass-caster and Vessel-style early builds; two independent choice tracks; replacements and dependencies; expertise; conditional AC/skills; resource capacities. Assert invalid choices and repeat/earlier replay, not only happy paths.
- [ ] Add failing edition/contract checks: pure 2014 has no 2024 background ASI/origin feat requirement; 2024 retains those rules; explicit adapter succeeds; unadapted mixing fails. Bound recursive predicates/cycles/counts/import sizes; unsupported required mechanics block, manual combat descriptions do not. Test copy-upgrade preserves original and surfaces unresolved choices.
- [ ] Implement the typed contract, semantic validation, legacy routing, schema-2 replay, catalog qualification and per-definition edition compatibility. Use explicit adapters including canonical replacement identity and changed grants where relevant; do not infer compatibility from names. Reject future required capabilities.
- [ ] Implement native class/edition labels, compatible creation choices, generic per-level groups, policy-driven spell choices, condition controls, resource/trait summary and explicit copy-upgrade review. Keep unfinished characters savable. Project calculated expertise/traits/conditional values to the sheet without invented combat state.
- [ ] Update generated schema, original example and authoring documentation together. Install the original capability example alongside the unchanged legacy example without rewriting existing snapshots. Keep class-family matrix/private adapter acceptance marked pending Task 2.
- [ ] Run `swift run FolioChecks`, `bash scripts/check-presentation.sh`, `swift build --product CharacterFolio` and generator checks. Controller handles native smoke/PDF rendering after this task; report missing tooling separately.
- [ ] Self-review, then make an internal signed commit `feat: add schema-2 capability foundation`. Do not push. Task 2 and independent reviews must pass before the entire feature is squash-merged to main and pushed as its own delivery.

### Task 2: Complete class-family fixtures and the actual Vessel adapter

**Files:** Modify `scripts/convert-vessel-pack.mjs`, `scripts/build-example-pack.mjs`, original generated capability resource, `Tests/FolioCoreTests/CapabilityChecks.swift` (or focused `CapabilityCoverageChecks.swift` / `VesselCapabilityChecks.swift` registered in the runner), README, `docs/content-packs.md`, `docs/engineering.md`, `docs/capability-coverage.md`, AGENTS baseline wording. Extend capability contracts/engine/editor/schema only when a matrix-owned I1 mechanism requires it, with a failing regression first.

**Interfaces:** Consume the Task-1 `Capabilities.swift` contracts, `CapabilityEngine.evaluate`, `CapabilityEngine.compatible`, `RulesUpgrade.copy`, source-qualified catalog and generic native editor. Public examples are original; private source descriptors stay in ignored PrivatePacks. Controller's ignored `PrivatePacks/vessel-source-review.json` records the visually verified PDF corrections and hash. The converter must record these specific evidence references without committing private prose or input files.

- [ ] Read the completed Task-1 interface documentation and I1 rows in `docs/capability-coverage.md`; register original family scenarios for every required I1 mechanism. Test choice dependencies, partial/expertise proficiency, conditional ability substitutions/AC, resources, known/prepared/book/subclass policies, bonus/locked grant alternatives and cross-list access. Assert expected totals and invalid paths; do not mark a family covered solely because its name is in the fixture.
- [ ] Extend the private Vessel converter for all six supplied subclasses and early-level Aspect grants/choices from the verified module + original-source review. Use exported Sealed Magic manifest, source Wizard list and actual Archon profiles; do not infer spell lists from names or actor placeholder stats. Preserve Flame Whip and other unresolved references as blockers. Record revision/hash/page evidence privately. No upstream edits or full PDF parser run.
- [ ] Add actual private-pack acceptance checks that explicitly report skipped inputs when absent. Test all six subclasses, Cataclysm affinity branches, Ascended preparation, Cursed skill variants, Formless locked bonus alternatives, class/aspect replacement policy, and conditional cloak/Archon implications. Unknown required mechanics block validation, not broad prose-only certification.
- [ ] Coordinate any contract extension with schema/generic UI/PDF projection and original tests. Update authoring instructions, supported scope, source gaps and coverage matrix with actual check names/evidence. Keep levels6–20, tiered pools, multiclass and equipment pending their deliveries.
- [ ] Run full core/presentation/native suites, generator reproducibility and private conversion. Self-review and signed internal commit `feat: complete early class capability coverage`. Do not push. Controller performs independent task/final review, native smoke and one feature squash-commit/push.
