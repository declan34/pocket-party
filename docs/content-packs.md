# Content pack contract v1

Schema 1 remains supported unchanged. For schema-2 typed engine/editor authoring, see [the capability interface](capability-interface.md). The original `capability-pack.json` installs alongside the legacy example and includes thirteen family mechanism laboratories. Registered behavior checks, actual private-adapter acceptance and unresolved content are distinguished in [coverage](capability-coverage.md).

Schema-2 multiclass authoring additionally requires `multiclass`, a per-class canonical identity/entry policy, first-versus-later training, and an explicit contribution policy for casters. Class levels and spell access remain local to each class; total character level is capped at 20. See the [I4 contract and source boundaries](capability-interface.md#multiclass-contracts-i4). Class-local talent/subclass IDs remain scoped to their owning source-qualified class; canonical class/feature identity intentionally crosses source qualification.

Use `content-pack.schema.json` for structural tooling, and the bundled `example-pack.json` as a complete working template. Import also applies semantic checks in `PackValidator`: duplicate IDs, missing references, progression gaps, unsupported values, and content limits. Schema validity alone is not enough.

## Identity and versions

A pack has `schemaVersion: 1`, `ruleset: "2024"`, a stable `id`, a nonempty `version`, `name`, `attribution`, `isPrivate`, and explicit `coverageNotes`. Bump `version` when changing content. Characters embed a snapshot of their original pack; installing a newer pack never changes existing characters. Importing different content with the same ID/version is rejected.

All collection IDs are unique within their collection. References are local IDs, not Foundry UUIDs. Abilities are `str`, `dex`, `con`, `int`, `wis`, `cha`; skills use the standard English names. Spell descriptions and feature text are plain text. Tool/equipment strings are informational.

Packs may be partial (for example, only species or feats). Keep the required collection keys, using empty arrays for absent kinds; at least one record or language is required. References must still resolve inside that source pack. Cross-pack UUID-style dependencies are not supported.

On import, content joins a shared library. New characters use the last-installed revision per source ID, not a lexical version comparison. Source/type/local-ID tuples become deterministic qualified IDs in the character snapshot; class-local talent/subclass IDs remain scoped to their class. Distinct source definitions remain distinct even when names match. Duplicate labels include source name/version. Class spell lists remain restricted to their own declared spells.

An existing character's **Add library choices** action appends previously absent source revisions, preserving its original definitions and selections. It is not an upgrade/migration of already-selected rules. Character exports may carry optional internal `sources` and `sourceLabels` metadata; those combined snapshots are character data, not source-pack imports. The source-pack JSON Schema intentionally does not expose those internal fields.

Combined snapshots are bounded at 100 source revisions, 100 classes, 1,000 species, 2,000 backgrounds, 5,000 feats, 10,000 spells and 12 MB encoded content. Character records, including portraits, remain limited to 20 MB. Oversized combinations fail before saving. A snapshot containing any private source is conservatively marked private, even when that source is not currently selected.

New combined snapshots also retain `sourceCoverageNotes` by selectable definition identity. Sheet support notes follow selected class/species/background/feats/spells rather than every installed source. Older snapshots without this metadata retain their existing notes; diagnostics from evaluation are never hidden. This metadata is snapshot-only, not a source-pack authoring field.

## Supported records

| Record | Meaning |
|---|---|
| `classes` | Hit die, primary/spell ability, two saving throws, skill choices, subclass unlock, progression, features, talents, class spell list, equipment note, armor formula |
| `progression` | One row per supported level, beginning at 1 with no gaps; maximum 5 for schema 1, 20 for schema 2. Choice counts are **cumulative totals**, not additional picks. `slots`/`slotLevel` describe one uniform pool. `improvement` opens a general-feat choice on the class's declared schedule. Missing rows are never extrapolated. |
| `talents` | Selectable class features. `minimumLevel`, prerequisite talent IDs, and `exclusiveGroup` restrict selection. Empty group means no group restriction. Only listed `skills` are calculated; other text is descriptive. |
| `subclasses` | Features with grant levels; additional known spells grouped by grant level. These do not consume class known-spell picks. Subclass choice cannot change between historical level rows. |
| `species` | Name, traits text, size, speed, fixed HP per character level (`hpPerLevel` is required; use zero for none). Size is descriptive in this MVP. |
| `backgrounds` | Exactly three eligible ability types, two skills, a tool, an origin feat ID, equipment notes. Player assigns +2/+1 or three +1 bonuses. |
| `feats` | Origin/general category, minimum level, eligible ability improvements/point budget, ability prerequisites for selected general feats (all must hold), HP per level, initiative proficiency flag, skill grants. Origin feats requiring prerequisites are unsupported: use minimum level 1 and empty `abilityMinimums`. Schema 2 optionally declares `repeatable: true`; absent/false remains nonrepeatable, and schema 1 ignores it. There are no arbitrary effect expressions. |
| `spells` | ID, name, spell level (0 = cantrip), plain description, provenance. Optional `unavailableReason` makes selection/grant fail build checks instead of silently using incomplete content. |
| `languages` | Standard additional creation choices for schema-1/2024; do not include Common, which is automatic only under those conventions. Schema-2 2014 languages come from authored semantic grants/choice groups instead; fixed or exotic grants never enlarge this pool. See the capability interface. |

`armorFormula` is `unarmored` or `vessel-mantle`. The latter displays an additional `10 + CON modifier + CHA modifier` option; it does not equip armor, track cloak state, or perform transformations. Baseline AC is `10 + DEX modifier`.

The engine currently permits at most one known leveled-spell replacement and one talent replacement per level; cantrips cannot be replaced. These are MVP policies, **not universal rules for every class**. Only supply classes compatible with them. For a different policy, extend the schema and deterministic engine together with regression tests—do not encode executable code in a pack or imply that prose will be interpreted automatically.

## Authoring process

1. Copy the original example and assign a new pack ID/version/name.
2. Add content you are entitled to use; retain provenance and explicit coverage notes.
3. Define mechanical fields for the supported subset. Put unevaluated rules in text and disclose them in coverage notes.
4. Check all references, then import. The app explains structural/semantic failures.
5. Create test characters through every supported level and test invalid choices too.

The supplied JSON Schema rejects unknown fields to catch typos in authoring tools. The Swift Codable reader ignores unknown JSON fields; they have **no mechanical effect**. Use only documented fields and validate with the schema before distribution. Packs have a 10 MB import limit, up to 20 classes, 100 species, 200 backgrounds, 500 feats, and 2,000 spells.

Private packs and character exports can contain copyrighted descriptions. They are not safe to publish merely because they are JSON. The app does not upload them.
