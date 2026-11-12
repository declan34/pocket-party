# Rules capability and content coverage

This inventory was established before implementation on 2026-11-12. No row is verified merely because the class exists in a menu. I1–I5 correspond to the five approved deliveries. I1 mechanism checks and source exceptions are recorded below; I2–I5 remain pending.

## Source inventory

The existing extracted dnd5e sources supply twelve legacy SRD class/subclass pairs in `classes`/`subclasses` and twelve revised pairs in `classes24`. Artificer and commercial fractional-casting subclasses are absent. Additional `classes24-homebrew` records do not count as official source coverage. These local sources are read-only inputs; none of their private content is bundled here.

The corrected Vessel module inventory is version 1.11.0, revision `c7b5ac9dbbc2bc54ad4a98609022d612411305f1`, with six subclasses, 24 Aspects and nine Archon profiles. A corrected Foundry module is not proof that every source description was extracted correctly. Source hashes and exact local paths belong in the ignored private conversion report.

## Capability acceptance matrix

| Class family and available variants | I1: early rules | I2: high levels | I3: casting | I5: equipment | Original fixture target |
| --- | --- | --- | --- | --- | --- |
| Barbarian / Berserker, both | Resource capacity, conditional traits, alternate AC, ability substitutions | Scaling, cap overrides | None | Armor/shield conditions, mastery | martial-rage-defense |
| Bard / Lore, both | Expertise, partial proficiency, inspiration, extra skills | Additional choices | Cross-list full caster | Training | expert-cross-list-caster |
| Cleric / Life, both | Order choices, channel resource, domain grants | Alternative strikes | Prepared full caster, granted spells | Order training | prepared-domain-order |
| Druid / Land, both | Order choices, conditional form traits | Form eligibility, fury choices | Prepared caster, selected-land configuration | Form equipment restrictions | prepared-land-form |
| Fighter / Champion, both | Style choices, resources | Extra improvements, attacks, styles | Fractional subclass capability; source absent | Mastery/defense modifiers | martial-extra-improvements |
| Monk / Open Hand variants | Alternate AC, movement, focus capacity/die | Save proficiency, scaling, caps | Feature casting where supplied | Unarmed/equipment restrictions | unarmed-focus-defense |
| Paladin / Devotion, both | Style/cantrip alternatives, healing/channel capacity | Aura/stat scaling | Half caster, oath grants | Training/mastery | half-caster-aura |
| Ranger / Hunter, both | Expertise/languages, styles, configurable choices | Replacement/scaling | Edition-specific acquisition, half caster, free uses | Mastery/weapons | hunter-choice-reconfiguration |
| Rogue / Thief, both | Expertise/languages | Dice/save scaling | Fractional subclass capability; source absent | Item/attunement exceptions | expert-item-exception |
| Sorcerer / Draconic variants | Metamagic, resource, HP/AC, affinity | Scaling | Full caster, subclass grants, limited uses | Defense restrictions | metamagic-draconic-caster |
| Warlock / Fiend variants | Prerequisite/possibly repeatable choices, pact choices | Arcanum choices | Pact, free/at-will/arcanum, expanded list vs grants | Pact weapon | pact-invocation-arcanum |
| Wizard / Evocation variants | Book acquisition vs preparation, expertise | Mastery/signature choices | Full caster, rituals/free uses | Training | spellbook-preparation |
| Artificer / no supplied source | Item-option selections, prerequisites | Scaling | Declared casting policy | Known recipes vs active applications/limits | item-augmentation-caster; content unverified |
| Vessel / all six | See detailed gate below | All supplied Aspect/feature progression | Custom pool, subclass overrides/branches, limited spells | Conditional strikes/defenses/starting choices | vessel-capabilities plus actual private adapter |

I4 owns entry prerequisites, starting versus later training, class-local advancement, canonical nonstacking identities and explicitly declared caster contributions for every family. Each relevant row must be covered by registered original scenarios before its owning delivery is complete. Unsupplied official subclasses remain unverified content even if their equivalent engine capability passes.

## Actual Vessel gate

- Class: independent Aspect track, Charisma casting, conditional mantle, no-armor/no-shield defense, Archon configuration, resource and die scaling, level-dependent improvements.
- Ascended: prepared casting from Vessel or Wizard list instead of known spells, ritual access, conditional traits, high-level independently limited spell choices.
- Cataclysm: element selection with dependent spell branch, conditional traits and attack profile.
- Cursed: additional locked Striking Presence; existing-selection alternative, including distinct skill choice. Unresolved Flame Whip stays explicit.
- Fallen: Insight/martial training, conditional skill modifier, later locked Aether Wings or alternative, weapon configuration.
- Formless: additional locked Ethereal Tendril or alternative, conditional size/movement/senses/AC and tendril attacks.
- Trickster: conditional skills, defenses, senses/language, conditional spell access.
- Aspects: level prerequisites, dependency graph, proficiency vs conditional ability use, repeatable choices when explicitly permitted, bonus-granted vs purchased identity, ritual/limited spell choices, conditional size/defense/attack traits.
- Starting equipment is present in Mortal Vessel prose despite empty structured starting-equipment fields; the converter must not claim none exists on that basis.

## Evidence gaps discovered before implementation

Inherited descriptions contain interleaved/truncated text, incomplete high-level advancement metadata and a Minor Magick repeatability disagreement. Verified private original-page review resolves the early replacement/preparation/bonus rules and identified level-18/20 truncations; the latter still belong to I2. No upstream source was edited and no PDF extraction was rerun. Missing essential rules cannot be replaced with guesses, and synthetic fixtures alone cannot certify actual Vessel.

## I1 registered mechanism evidence

`capabilityFamilyMatrixChecks` evaluates thirteen original family laboratories under separate original 2014 and 2024 fixtures. It asserts totals/invalid paths, not just class IDs:

| Family | Asserted early mechanics |
| --- | --- |
| Barbarian | Resource capacity, conditional AC and ability substitution; removal restores baseline |
| Bard | Expertise, rounded half proficiency, extra skill, inspiration and explicit cross-list eligibility |
| Cleric | Order skill, channel capacity, preparation changes and additional domain grant |
| Druid | Order choice, preparation and conditional form trait; land-specific spell-pool delivery remains I3 |
| Fighter | Style-dependent AC, recovery and surge capacities |
| Monk | Conditional alternate AC, movement, focus capacity and declared focus die |
| Paladin | Style versus two granted cantrips, healing/channel capacities and additional oath grant |
| Ranger | Expertise/language, style and configurable tracking trait; edition casting details remain I3 |
| Rogue | Expertise and calculated language grant; item exceptions remain I5 |
| Sorcerer | Metamagic selection, resource capacity, per-level HP, conditional AC/affinity and extra spell |
| Warlock | Prerequisite removal, repeatable invocation occurrences, pact track and bounded expanded list |
| Wizard | Expertise, acquired spellbook versus prepared subset, rejection outside the acquired book |
| Artificer | Dependent item-recipe selections and declared preparation; official source absent, active items remain I5 |

Original names and numbers are mechanism examples, **not conversions/certification of every official subclass**. Tiered full/half/fractional/pact casting progression belongs to I3, even when the early selection mechanism passes here.

Focused checks: `capabilityBonusFamilyAlternativeChecks`, `capabilityAcquisitionRequirementChecks`, `capabilityTrackExclusivityChecks`, `capabilityMovementBaseChecks`, `capabilityFormSizeChecks`, `capabilityComputedTraitChecks`, `capabilityAdditionalSpellGrantChecks`, and `capabilitySelectedCoverageChecks`. Track exclusivity checks reject ordinary and Formless duplicate Presence-family purchases while accepting the Cursed-specific distinct-variant exception, including source-qualified catalogs. Existing Task-1 checks retain independent-track, prerequisite-cycle/removal, edition/adapter, legacy replay, copy-review and malformed-content coverage. See [interfaces](capability-interface.md).

## Actual private Vessel acceptance

`vesselCapabilityChecks` explicitly prints SKIP if its ignored private input is absent. With current conversion it checks all six supplied subclasses, all four Cataclysm branches, permanent Athletics versus cloak-only Charisma, Archon-implied cloak, no-armor/no-shield defense, actual profile walking speed/size, computed pseudopods, optional fortified movement, Ascended Wizard-only preparation, additional grants, canonical Cursed skills, locked/general bonus alternatives, replacement schedules and historical replay.

The adapter imports exported Sealed Magic entries including affinity fields, explicit revised Wizard journal membership, and runtime Archon AC bonuses plus source profile movement/traits. Placeholder actor AC/HP/abilities are not rules. Locate Creature remains level 4 even though access is granted at Vessel 5; the uniform pool remains level 2.

Current input produces 106 spell identities and ten unresolved diagnostics: four LL-only class-list choices (Glitterbeam, Otherworldly Grasp, Ethereal Anchor, Flame Whip) and six standard-only subclass references (Elemental Blade, Beckon Air, Control Flame, Torrent, Flame Whip, Ethereal Anchor). LL and standard references remain separate. Selecting an unavailable class-list choice blocks completion; automatic unresolved grants block the corresponding subclass/affinity/level. Ascended, Formless and Trickster acceptance builds pass through 5; Cursed/Fallen/Cataclysm checks assert the expected source blockers rather than a false clean build.

Exact source file hashes, module revision/version, original PDF hash/pages and Wizard journal ID stay in `PrivatePacks/conversion-report.json` and `vessel-source-review.json`. Starting equipment is present in Mortal Vessel prose; structured equipment remains I5. Combat rolls, transformation lifecycle on a battle map, companion turns, expenditure/rest simulation and crafting economies are outside this builder roadmap.
