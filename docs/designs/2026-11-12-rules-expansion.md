# Pocket Party: extensible 5e character building

Status: approved 2026-11-12; implementation authorized through all five deliveries without further routine approval checkpoints.

## Intent and agreed scope

Build complete characters level by level, not just collect character ideas. Keep the native SwiftUI app, local storage, combined content library, pinned character definitions, and optional AI. AI may recommend mechanical choices; the deterministic engine validates accepted choices.

The owner requested five separately verified, committed, and pushed deliveries: broader class support, levels 6–20, multiple spell-slot tiers, multiclassing, and equipment mechanics. Compatibility targets are official 5e classes/subclasses and Vessel, with a reusable import format for homebrew. The default rules baseline remains 2024; imported 2014 content must also work.

This is engine and builder work, not a request to republish every official book or reparse source PDFs. Public examples remain original; private definitions remain imported and private. An official class name in a picker is not proof that its mechanics work.

## Current constraints verified in the checkout

- `Models.swift` has one character-level `classID`, one class talent track, one `slots`/`slotLevel` pair, and mostly descriptive feature text.
- `Validation.swift` accepts only schema 1, ruleset 2024, and characters/progressions through level five. It assumes 2024 background boosts and an origin feat.
- `RulesEngine.swift` hardcodes standard array, limited replacement policies, a single casting ability, and two armor formulas. Replaying choices rather than accumulating bonuses is the right foundation to retain.
- `ContentCatalog.swift` preserves qualified source identity and pinned snapshots, but the combined pack currently inherits a single pack-level ruleset. Mixed-edition catalogs need per-record provenance, not that implicit choice.
- The editor, summary, story context, and printable sheet assume one class. The sheet fills one slot tier and leaves equipment/combat state blank.
- Tests are standalone Swift executables. Mac checks do not prove iPhone compilation, live AI behavior, or third-party PDF editing.

## Product decisions proposed by the builder

These are explicit implementation proposals, not additional statements attributed to the owner.

### Editions and compatibility

Each character pins a rules profile (`2014` or `2024`) as well as its content definitions and evaluator version. Each imported definition retains its source edition. A shared library can contain both editions; new-character choices are filtered by compatibility, with source and edition visible. Do not reintroduce a required pack picker.

Pure 2014 builds use 2014 creation rules; they do not inherit 2024 background ability boosts or origin-feat assumptions. Model species/race and background grants as data under the selected profile. Retain standard array in this delivery; point buy and rolled abilities are separate future additions.

Legacy content in a 2024 build needs an explicit compatibility declaration or adapter in the pack. The adapter describes replacement identities, grant-level mapping, and changed prerequisites/creation grants as applicable. Never silently shift every older subclass to a new level or merge same-name spells. Unknown cross-edition combinations remain visible as incompatible, not silently accepted. Imported house-rule adapters may permit other combinations, but the UI labels them custom rather than officially validated. Mixed-edition class progressions use the character's pinned profile plus each explicit adapter; arbitrary mixing without an adapter is not part of this work.

A schema version describes data structure, not game edition. Keep those fields separate.

### Engine capabilities, not class-specific code

Introduce a versioned schema with named, typed capabilities rather than executable scripts. Packs declare:

- Feature grants and multiple independent choice groups, with grant level, selection count, replacement schedule, and source ownership.
- Prerequisites using bounded all/any/not predicates over supported facts: abilities, class/character level, proficiencies, and prior selections.
- Proficiency ranks, expertise, tool/weapon/armor training, languages, movement, senses, resistances, saving-throw grants, and other supported sheet traits.
- Typed modifiers and alternatives for scores/caps, HP, initiative, AC, attacks, and resource maxima. Specify stacking/override identities; alternative AC formulas do not add together.
- Resource pools with class-level or character-level tables and recovery metadata. This builder computes maxima; encounter use and rest buttons are not introduced here.
- Class- or subclass-owned spellcasting policies and lists. Known, prepared, spellbook, always-granted, innate, and feature-limited spells remain distinct.

Expressions are bounded typed operations over an allowlisted fact model, not arbitrary Swift/JavaScript or unrestricted expression evaluation. Validate reference existence, cycles, incompatible capabilities, expression depth, count limits, and progression bounds before evaluation. Preserve import-size/privacy safeguards.

Every calculated value should retain enough origin information to explain where it came from and undo a removed selection during replay. Conditional feature benefits require a declared condition and a visible builder configuration where meaningful; do not silently assume a combat condition is active.

Novel homebrew mechanics outside this vocabulary require another reusable capability. Record explicit support status: automated, descriptive/manual, or unsupported required mechanic. Manual combat text is acceptable for a builder. An unsupported mechanic that affects build legality or calculated sheet values prevents a fully validated result; it must not be hidden behind a green check.

### Meaning of class support

The target is each imported class/subclass's character-creation decisions, advancement, persistent sheet statistics, spell access, and resource capacities. It is not automated combat resolution, initiative management, summons acting on a battle map, or recreation of Foundry activities.

Build an auditable capability matrix covering the standard class families, Artificer-style item choices, Vessel-style options, and subclass variations. Test full/half/fractional/pact casting, martial and expertise progressions, alternate defenses, bonus choice schedules, resource scaling, spellbook/prepared differences, and subclass-added casting with original fixtures. Do not add a switch on a displayed class name.

Maintain two separate claims: engine capabilities verified by original fixtures, and specific imported class/subclass packs verified against their supplied definitions. The five deliveries do not imply that every commercial subclass's content was supplied or audited. Where a class family reveals an unimplemented build-time mechanic, add the capability or record the remaining gap; do not claim complete coverage of that family.

Completion is not merely those example fixtures plus a gap report. Before implementing increment 1, establish a capability matrix for the twelve core class families, Artificer, and Vessel under the applicable 2014/2024 definitions, and enumerate build-time subclass variations present in the available source inventory. Each row names the required engine capability, the delivery that owns it, its fixture, and the source evidence. A known required row assigned to a delivery must pass before that delivery is complete. A dependency assigned to a later delivery may remain pending until that delivery, clearly labeled. Missing source evidence means unverified pack coverage, not a passing row. If the inventory exposes a materially new subsystem beyond these five scopes, surface it before claiming the roadmap complete. Complete support for every official subclass remains a compatibility goal, not a certification attainable without its definitions.

Actual Vessel is required, not only a synthetic lookalike. The existing corrected module checkout is available: module version 1.11.0, Git revision `c7b5ac9` at design time. Reuse its class, subclass, Aspect, and spell-list sources through the existing read-only converter; record full revision and file hashes at implementation. The current private app pack is only a 1–5 Trickster slice and is not the complete acceptance target. Cover all build-time class/subclass choices in that supplied module through 20 across these deliveries. Already-known unresolved content, including the converter's Flame Whip diagnostic, must stay explicit; do not invent a spell or claim the affected build passes until its source/policy is resolved. Combat automation remains outside this builder target.

### Save and schema compatibility

Keep existing schema-1 packs and characters readable and evaluable with their current semantics. Preserve saved IDs, source snapshots, story, portrait, choices, and backups. Use an explicit legacy evaluator/adapter boundary with golden regression fixtures; adding installed content never rewrites an existing build.

New schema-2 characters pin a rules/evaluator profile. Existing characters can opt into an upgrade that creates a new character copy, preserves the original, shows changed or unresolved choices, and validates before save. Required migration changes are confined to the feature that introduces them, not deferred until the final delivery. Future schema capabilities must fail clearly in older evaluators rather than being silently ignored.

Source-pack references remain self-contained for this roadmap. Separate subclass-expansion packs and arbitrary cross-pack dependency resolution are not added incidentally; authors can include the referenced definitions in an importable pack. Source-qualified identities still prevent same-name collisions in the combined library.

## Five independently delivered increments

Dependency order places spell pools before multiclassing. Each increment includes engine/schema changes, usable SwiftUI controls, summary/PDF projection, public original fixtures, docs, and regressions for its own scope. Each gets a separate commit and push; no mega-commit at the end.

### 1. Broader class support and edition-aware contracts

Deliver schema-2 capability vocabulary, 2014/2024 creation profiles, compatibility declarations, generic choice groups and grants, proficiencies/expertise, resource capacities, and class/subclass policy-driven selection/replacement. Implement the old-save compatibility boundary and opt-in copy upgrade. Extend public authoring documentation and the repeatable private adapter only as needed to express already-extracted definitions; do not change upstream source repositories.

This increment remains limited to levels 1–5 and the existing uniform slot pool; later capabilities are explicitly unavailable, not simulated. Define interfaces for later slot/equipment capabilities without pretending they are implemented.

Acceptance: a noncaster, known caster, prepared caster, spellbook caster, subclass caster, and Vessel-style class can express supported early-level choices without bespoke class-name logic. Include pure 2014 creation, 2024 creation, an explicit legacy adapter, and rejection of an unadapted mixed selection. Existing schema-1 golden builds remain unchanged.

### 2. Levels 6–20

Extend supported progression bounds, replay, validation, prerequisites, proficiency growth, HP, subclass grants, class-specific improvement schedules, repeatable choices where declared, and high-level ability-cap/feat behavior. No extrapolation of missing progression rows. A pack can intentionally stop early; the UI identifies its boundary.

Acceptance: original martial and Vessel-style builds advance through 20, edit an earlier level, and remove/re-add a later level without stale grants. Validate high-level feat eligibility, resource scaling, cap overrides, and replay through earlier levels. Level 21 remains unsupported. Multi-tier spellcasting is still identified as pending until increment 3.

### 3. Multiple spell-slot tiers and casting sources

Replace the single-pool projection for schema-2 characters with explicit pools containing slots by tier, recovery kind, and source. Ordinary spellcasting and pact/custom pools remain distinct. Model subclass/feature casting separately where it has a separate ability, list, known/prepared policy, or use limit. Higher available slots do not automatically grant knowledge of higher-level spells.

Support full, half, fractional, and custom table-driven single-class progressions through 20. Preserve the existing uniform-pool behavior through the legacy adapter. Store selected preparation/loadout choices as editable character configuration, distinct from level-up spell acquisition and spellbook membership.

Acceptance: a nine-tier ordinary pool, a pact-style pool, subclass-added casting, always-granted spells, and an independently limited feature spell all display accurately and round-trip. PDF exports show ordinary tiers and supplemental labeled pools/abilities without combining incompatible counters or losing overflow. Spending slots/rest simulation is out of scope.

### 4. Multiclassing

Each historical level records the class taken; derive class levels from replay rather than maintaining an unrelated mutable counter. Pin the starting class, entry prerequisites, first-class versus later-class proficiency grants, per-class subclass selections, hit-die groups, improvement schedules, and non-stacking feature identities.

Use total character level only where the selected rules profile says so; use class level for class progression and class-specific spells/features. Combine compatible ordinary caster contributions using edition-aware rounding/eligibility rules verified from authoritative sources. Keep pact/custom pools separate. A custom caster needs an explicit multiclass contribution policy or a clear incompatibility diagnostic.

Acceptance: martial/martial, ordinary/ordinary, ordinary/pact, fractional-caster, and Vessel/custom-policy builds; order-sensitive proficiency and HP; invalid entry prerequisites; same-name features that must not stack; distinct spellcasting abilities; earlier-level edits that invalidate later choices. Total character level caps at 20. Same class in two editions cannot be selected as two classes; canonical class identity and compatibility rules enforce this.

### 5. Equipment mechanics

Add declarative item definitions and a saved inventory/loadout: quantities, carried/equipped state, armor/shields, weapons and relevant properties, ammunition, tools, currency, weight, attunement requirements/limits, and typed supported item modifiers. Model starting equipment choices and starting-money alternatives without granting both automatically.

Calculate selected AC formula, shield interactions, weapon attack/damage summaries, proficiency, restrictions, speed/stealth implications, carrying totals, and supported attuned modifiers. Show attacks/formulas, not automatic dice resolution or target damage. Require explicit choices for alternatives such as wielding mode; do not equip every owned item or stack incompatible defenses.

Acceptance: equip/unequip armor and shield; switch weapon modes; resolve trained/untrained use; prevent impossible hand/attunement combinations; apply and remove supported item modifiers exactly once; account for quantity and weight; preserve earlier-level replay while evaluating a saved loadout against that level's proficiencies. Unmodeled magic-item effects remain explicitly descriptive/manual, not silently automated.

## Evidence and shipping contract

- Preserve passing legacy checks and add boundary/invalid-choice regression cases before each behavior change. Use real original fixtures, deterministic replay, and save/export round trips.
- Extend schema generation and its documentation together. Test unsupported schema/capability handling, mixed-source privacy, and oversized/cyclic inputs.
- Run core/presentation/native build checks appropriate to each increment. Exercise changed native flows against an isolated library. Check PDF fields and rendered layout when projections change; absent template/device access is reported explicitly.
- Review each increment for data loss, false validation, source/edition leakage, and unsupported-mechanic claims. Fix issues within that increment before pushing it.
- Push each verified feature commit separately to the approved repository. No forced pushes, unrelated changes, content publication, release tags, or App Store distribution. If another machine moves main, reconcile without overwriting it.
- Separate an engine milestone from complete verification of every official class/subclass pack. Maintain a capability/coverage report; never convert missing sources into invented rules.

## Decisions left to implementation planning

Exact Swift type/file boundaries, schema field names, expression representation, fixture names, and UI component decomposition are engineering choices. Keep pure evaluation out of SwiftUI and the capability modules small enough to test independently. Use the existing approved visual language; this is not another UI redesign.

Plans should be one per increment, with explicit dependencies and coverage gaps. A design approval may authorize writing those plans and continuing through implementation without another routine approval checkpoint; stop only for a material scope change, missing essential source rules, unsafe data migration, or external access that requires the owner.

## Source references

- [Current pack contract](../content-packs.md) and [engineering notes](../engineering.md): repository facts and verified/unverified boundaries.
- [Official SRD downloads](https://www.dndbeyond.com/srd): SRD 5.1 and 5.2.1 are the primary references for edition-specific common rules. Exact mechanics must be checked during each increment; do not treat memory as a rules source.
- [Official 2024 handbook changes](https://www.dndbeyond.com/posts/1810-updates-in-the-players-handbook-2024): older/revised content has replacement and compatibility distinctions. Do not infer tabletop compatibility solely from another character builder's UI restrictions.
- Non-SRD official features and Vessel need supplied/imported definitions for pack-specific validation. Keep those definitions private where required; reusable engine tests use original content.
