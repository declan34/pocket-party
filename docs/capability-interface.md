# Schema-2 capability foundation

The capability engine/editor contract below is exercised by registered original family scenarios and actual private adapter checks; see the precise [coverage and source blockers](capability-coverage.md). It does not certify all official subclasses. Explicit single-class progression supports levels 1–20. Multiclass, tiered slot pools, equipment state and combat simulation remain outside this evaluator.

## Version boundary

`schemaVersion: 2` requires `capabilities: {version: 1, required: [...]}`. Supported required names are `choices`, `modifiers`, `casting`, `editions`, `resources`, `traits`, `proficiencies`, `configuration`, `languages`. Unknown required names or versions fail import. Each capability-bearing definition has explicit `edition: "2014" | "2024"`. A schema-2 build pins `rulesProfile: {edition, evaluator: 2}`; absent keys never infer a saved-character upgrade. Classes intended for evaluator 2 should declare `capabilities`, even if only `{edition: "2014"}`.

`RulesEngine.evaluate(_:in:through:)` and `advance(_:in:)` retain their signatures. A legacy class with an absent profile still uses unchanged schema-1 replay, including in a mixed snapshot. `CapabilityEngine.evaluate` validates the supplied record before applying rules; invalid structural data returns `cap-invalid-content` with no calculated totals. Draft choices remain savable: missing picks are evaluation issues, not import errors.

Library structural budgets apply independently to each installed pack and pinned character snapshot, with the same checks before save and load. Accumulating valid characters does not exhaust one aggregate pack budget. Library version and duplicate character identity checks also run before writing; atomic saves and previous-file backups remain unchanged.

`ContentPack.sample()` loads the unchanged original schema-1 sample; `capabilitySample()` loads the separately generated original Trail Warden. AppStore installs the second sample when absent without rewriting any character snapshots. Source-qualified catalog identities include capability groups, options, grants, configurations, policies and their references. Same names do not imply shared rules.

## Choices and replay

`LevelChoice.capabilities` stores cumulative dictionaries `groups`, `spells`, `prepared`, and a `configurations` list. Each level stores its own choices. Earlier edits re-evaluate the whole history. `CapabilityChoiceGroup.counts` and `replacementLimits` are level-indexed totals/maximum removals (first element is level 1). `locked` forbids replacements. Unknown tracks, wrong counts, prerequisites, duplicate nonrepeatable ownership and exclusive option variants produce build issues.

Option IDs are canonical across independent tracks. A nonrepeatable option cannot double-grant via a bonus track. Repeatable options have per-track/per-position occurrence grant identity and additive grants stack per occurrence; proficiency ranks still take the maximum rather than adding. Authors must use distinct canonical option IDs for different parameter variants, such as separate skills.

- `requiredOptionID`: the group must include this option unless another track already owns it, in which case an alternative is allowed.
- `requiredOptionIDs`: the group must include at least one member of this family; owning a different family member elsewhere does not waive the requirement. Useful for mandatory skill-specific variants.
- `waiveRequiredFamilyIfOwned: true`: explicitly permits another eligible option when an accepted family member is owned in another track. Without this flag the family remains mandatory. Shared canonical IDs still prohibit duplicate ownership.
- `requirementTiming: "acquisition"` checks mandatory option/family alternatives only on the first nonempty acquisition row. Default `"ongoing"` (including absent data) preserves the prior continuous requirement. Earlier edits still replay the original acquisition; the selected locked bonus cannot change, but the original separately purchased family member can later be replaced if it is not an actual prerequisite.
- `exclusiveGroup` on options prevents incompatible variants being owned together.
- `exclusiveGroupExceptions` on a choice track explicitly permits an additional distinct variant of the named family across tracks. It does not permit two variants within that track or duplicate nonrepeatable canonical IDs. Ordinary tracks remain mutually exclusive with each other, and the exception is order-independent. The converter grants this exception only to the Cursed bonus Presence track, not ordinary Aspect purchases or Formless alternatives.

`RulePredicate` is closed typed data: `all`, `any`, `not`, `level`, `ability`, `selection`, `proficiency`, `configuration`, `subclass`. `key` names the referenced item; `minimum` supplies an ability/level threshold; composites use `children`. No strings execute as expressions. Selection dependencies are grounded from valid roots, including grant-derived proficiency. Current-level ASI cannot fund that level's capability prerequisite. Selection/configuration cycles and excessive predicate depth/fanout fail import.

Ordinary feat `abilityMinimums` also use capability-adjusted historical scores before the choice. Earlier retained ability grants can qualify; the current feat's boost or capability grants and newly acquired same-level options cannot fund its prerequisite. Earlier edits replay these checks. `RulesEngine.subclassUnlockLevel(for:build:in:)` is shared by the native editor and evaluator, including explicit edition adapters; premature saved subclass choices remain visible for correction and are not silently removed.

Configurations describe declared conditions, not combat state. Their `prerequisite` can require another configuration; `exclusiveGroup` prohibits simultaneous alternatives. Invalid configuration effects are removed and reported. The editor exposes controls and shows inactive tracks/policies explicitly so retained choices can be cleared.

## Grants and calculations

`CapabilityGrant` uses `id`, `kind`, optional `level`, `condition`, `target`, `value`, `rank`, `ability`, `text`, `recovery`. Kinds: proficiency, skillAbility, skillBonus, armorFormula, armorBonus, hitPoints, initiative, speed, speedBase, size, abilityScore, trait, resource, spell, language, manual, unsupported.

### Languages and edition-aware creation

Declare `languages` in the required capability names when authoring semantic language grants. A `language` grant's `target` is an authored canonical display name (1–120 characters, trimmed, no control characters), not a reference to the standard-choice pool. This allows original or exotic fixed languages without making them available as 2024 creation picks. Use the same exact spelling for the same language across sources. Fixed grants, including ordinary feature options that incidentally grant languages, deduplicate by name; their level/condition controls when they appear. Later conditional grants never invalidate an earlier learned copy, and removing a form does not remove another source's copy.

For actual language-selection slots, mark an ordinary capability group `languageChoices: true`. Each option must grant exactly one unconditional language at level 1, with no repeatability or unrelated effects. Options in that group name distinct languages; authored group counts, conditions, unlocks, replacement limits and locking control acquisition. Two selected language slots cannot spend choices on the same language, including overlap with 2024 standard creation selections. Ordinary feature choices are not language-selection slots and may grant overlapping fixed languages without being rejected. Unknown option IDs and earlier edits use normal historical replay validation.

2014 has no automatic Common or universal two-language allocation: species/background definitions author fixed grants and selection groups explicitly. The bundled **Old Road Wayfarer / Old Roadfolk / Old Road Guide** fixture grants Common and Road Cant from species plus one background language choice. Any retained `build.languages` values are preserved but require explicit review/clearing; they are not silently converted. 2024 and schema-1 keep Common plus two distinct selections from `pack.languages`. That list remains only the standard creation-choice pool, excludes Common, and is never expanded by fixed language grants. `CharacterSummary.languages` supplies both the native summary and printable sheet. Older pinned snapshots remain unchanged; installing the newer examples/converter output does not migrate them.

`speedBase` replaces the species walking speed before additive `speed` modifiers; use mutually exclusive predicates for alternative forms. `size` supplies a canonical size label (Tiny through Gargantuan), reflected in `CharacterSummary.size` and the printable size field. A `trait` with a `value` projects a calculated fact as `text: number`, useful for counts or secondary movement rates without claiming combat execution. Generic configuration controls activate these effects; no class-name special cases exist.

`RuleValue` combines bounded `base`, ability modifiers from `abilities`, `levelMultiplier`, `proficiencyMultiplier`, a level-indexed `table`, and optional `minimum`. All level references use the current historical single-class level, not the acquisition level (class level and character level are equal in this delivery). Tables support up to 20 explicit rows. An absent active value/group/policy row blocks completion rather than extrapolating. Ability-score grants resolve before dependent totals; HP recalculates Constitution retroactively, followed by defenses/initiative and casting values. Armor formulas select the best alternative before additive armor bonuses. No spending, rests or combat actions are simulated.

`abilityCap` grants declare an ability `target` and fixed `value.base` from 20 to 30; no dynamic expression is permitted for a cap. Caps use the highest applicable maximum, never add together. Every historical row checks its scores against its own active caps before continuing; a later cap cannot repair an earlier invalid score. Default maximum remains 20. Class `progression.improvement` rows are authoritative, and feat `repeatable: true` is explicit data, not inferred from its name. Repeatable feat scalar benefits and grants apply per acquisition with distinct grant identities; shared choice tracks remain canonical tracks, not automatically duplicated choices.

Proficiency grants also accept `save.str` through `save.cha`, and `all-saves`. These ranks are merged with class starting saves and projected into native summary/PDF values; saving-throw keys never become skill names.

Proficiency ranks are none/half/proficient/expertise; half rounds down and expertise doubles proficiency. `all-skills` is supported for proficiency grants. Resource grants expose maximum/recovery, never current expenditure. `trait` is displayed supported information; `manual` explicitly identifies unevaluated mechanics; `unsupported` blocks the selected build. A missing/unavailable spell reference is never fabricated.

Grant IDs identify nonstacking ownership across tracks. Conflicting grant definitions fail validation within their applicable scope. Explicit edition adapters contain `edition`, `canonicalID`, `label`, `replacementGrants`, optional `subclassLevel`; compatibility is never inferred from names. An adapter replaces capability grants for the target edition. It does not translate arbitrary legacy text or invent replacement choices.

## Casting policies

`CastingPolicy` declares `id`, `name`, `mode`, `ability`, exact eligible `spellIDs`, `counts`, `maximumSpellLevels`, optional `replacementLimits`, `preparedCounts`, `condition`, `text`. Modes: known, prepared, book, granted, ritual, limited, atWill. Counts are cumulative; prepared/ritual selections may change without a known-spell replacement charge. Book acquisition (`spells`) and preparation (`prepared`) are independent, and preparation must be a distinct subset of the acquired book.

A policy condition controls whether the selection track is active. To replace class-known casting at subclass unlock, condition the known policy with `not(subclass: id)` and define the prepared policy on that subclass. Historical rows retain their prior known choices; the new row clears the inactive track and fills preparation. Class and policy lists remain separate: adding an expanded list to one policy must not broaden another subclass's list. Temporary casting availability, expenditures and ritual execution are not combat simulation; do not model temporary inability to cast by deleting known choices.

Additional active spell grants do not consume `known` or `prepared` policy choices. A selection that tries to count one produces `cap-casting-granted-*`; retain its grant and select another eligible spell. Access to a granted spell above the current uniform slot level does not increase slots or change that spell's level.

Spell grants may declare `spellMode: granted | prepared | atWill | limited | ritual` (absent means granted). This supplies an explicit roster classification; it never simulates casting or expenditure. Multiple active grants retain their classifications. An always-prepared grant is labeled `Prepared (granted)` and remains additional to preparation counts.

The current printable casting header is a single ability/DC/attack projection. Simultaneous selected policies with different casting abilities explicitly block completion (`cap-casting-abilities`) until a per-policy sheet projection is implemented; the engine does not certify a misleading single total.

## Presentation and copy review

Defaulted `CharacterSummary` additions preserve legacy caller compatibility: `languages`, `proficiencyRanks`, `skillModifiers`, `traits`, `resources`, `provenance`, `supportDiagnostics`, `spellLabels`, `activeGroupIDs`, `activePolicyIDs`, `castingAbility`. SwiftUI and `PrintableSheet` consume these outputs, including partial/expert skill values and policy labels. Sheet notes identify selected configurations and leave untracked state blank. Core projection tests do not prove native PDF rendering or device layout.

`RulesUpgrade.copy(_:) throws -> CharacterRecord` validates the input and produces a distinct build ID and pinned evaluator-2 snapshot, preserving level history, story and portrait. `upgradeReview` blocks advancement until explicit review; the source record is never overwritten. AppStore saves only the returned copy. This does not convert a private class into a newly supported ruleset automatically.

## Authoring and verification

Keep Swift contracts, `scripts/build-schema.mjs`, `scripts/build-example-pack.mjs`, generated schema/resources and this guide synchronized. `PackValidator` semantic checks add bounded counts, identity/reference integrity, grant consistency, dependency cycles and record-size limits beyond JSON Schema. Tests use original data and the standalone `swift run FolioChecks` runner. Register every new scenario there. Native compilation and `bash scripts/check-presentation.sh` are separate gates; actual private acceptance reports absent inputs explicitly and does not substitute for native/device/PDF verification.
