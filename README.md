# Pocket Party

A native SwiftUI home for character ideas that grow into playable builds. Build a character level by level, explore alternatives, and keep their story alongside their choices.

The project is now called **Pocket Party**. The current Xcode target, preview app, and local save folder still use the development name **Character Folio** to preserve existing builds and saved characters.

This is a local MVP, not a complete D&D character creator yet. Schema-2 builds support **levels 1–20 where the pack supplies explicit rows**, including multiclassing when each class declares an entry policy, with a pinned 2014 or 2024 profile. Schema-1 saves keep their original level-1–5 2024 conventions. The bundled **Lantern Roads** and **Trail Warden capability laboratory** packs are original demonstrations, not official content or a claim of game balance; **Summit Warden** and **Notebook Keeper** demonstrate multiclass progression, tiered pools and editable book preparation.

## Try it now on this Mac

Open `Preview/Character Folio.app`, then choose **Explore a sample character**. Mara’s level-3 build shows the three parts:

- **Build:** ability scores, background, skills, subclass, spells, and decisions at each level. Unfinished or conflicting choices prevent advancing.
- **Sheet:** calculated HP, ability modifiers, saving throws, skills, spell slots, and feature descriptions.
- **Story:** editable backstory, appearance, personality, and an imported portrait. On supported devices, Apple’s on-device text model can suggest prose for you to accept or discard.

Use **Create** or **New character** for a blank build. The library can switch between circular portraits and a list; search accepts character or class names. The three-dot menu duplicates an alternate build or exports a character. Changes save locally. Exports include the character’s content pack, so treat private character exports as private too.

To try your existing Vessel data, use **Import** and select `PrivatePacks/vessel-pack.json`, then choose **Vessel** from the combined class list. Same-name variants show their source. The private adapter represents all six supplied subclasses and early Aspect choices, including locked bonus alternatives, affinity branches and Ascended preparation. Unresolved standard spell references still block affected builds; LL-only class-list choices remain visibly unavailable. Neither the private pack nor its source-review evidence is bundled.

Existing characters keep their saved rules. To offer newly imported choices to an older character, choose **More → Add library choices**. This preserves existing choices and their definitions. New characters use each source's most recently installed version; installing an update never silently changes a saved build.

## Export a 2024 character sheet

1. Open a character and choose **Sheet → 2024 sheet**. The regular Summary stays available.
2. The first time only, use **Download official blank PDF**, save that file, then **Import blank sheet PDF**. The app keeps its own local copy; the official artwork is not bundled with the app.
3. Review the populated sheet, then choose **Export PDF** and a save location.

The export uses the official two-page 2024 layout and adds reference pages for descriptions and longer notes. Its form fields remain editable in a PDF reader; those edits do not sync back into Folio. Incomplete builds are marked **DRAFT**. Current HP, spent slots, equipment, attacks and other untracked details are left blank for you—not guessed. AC assumes no armor or shield; conditional armor is explained separately. Known/granted spells retain those meanings even though the official form labels its list “Prepared Spells.”

Keep PDFs containing private content private. The supported blank PDF revision is fingerprinted: if the publisher changes it, Folio will ask for a supported template rather than fill the wrong fields.

## What works in this slice

- Standard array; background ability bonuses, skills, tool, and origin feat.
- Level-by-level choices, subclass grants, feat prerequisites, and ability improvements.
- Per-level class selection, entry/exit prerequisites, starting versus later-class training, class-local advancement and separate hit-die capacities. Earlier edits retain invalidated choices for correction.
- Known spells, cantrips, spell-list validation, source-owned ordinary/pact/custom/limited pools and up to nine declared slot tiers; legacy uniform pools remain supported.
- Editable preparation separate from learned spells and historical acquisition, with source-specific abilities/DCs and labeled PDF overflow. Higher capacity never unlocks higher-level knowledge.
- Typed independent choices, prerequisite/replacement rules, expertise/partial proficiency, conditional defenses/skills/form size and movement, resource capacities, known/prepared/book policies and explicit cross-list eligibility.
- Rechecking later levels after earlier edits; limited spell/feature replacement.
- Fixed-average HP, retroactive Constitution changes, supported passive feat bonuses.
- Local save with a previous-file backup; JSON import/export; pinned content versions.
- Original public sample content and a repeatable private converter using our already-corrected extracted sources—not the PDFs again.

Not yet supported: every class’s unique choices, equipment purchases/armor loadouts, custom rolled abilities/HP, combat/resource use, cantrip replacement, full conditional feat automation, sync, Foundry export, or AI portrait generation. A class without an explicit multiclass policy cannot be combined by guessing its rules. Narrative feature text is readable but does not imply its mechanics are automated. “Build checks passed” means the implemented checks passed, not that every 2024 rule was evaluated.

## Run and develop

```sh
swift run FolioChecks
bash scripts/check-presentation.sh
# Optional native PDF integration checks (requires your downloaded blank template):
swift run FolioPDFChecks /absolute/path/to/character-sheet.pdf /tmp/folio-pdf-checks
bash scripts/build-preview.sh
open 'Preview/Character Folio.app'
```

The standalone regression harness runs without XCTest. The Mac preview uses the same SwiftUI views and rules engine as the iOS target.

For iPhone: install a current Xcode with an SDK supporting your phone’s OS, open `CharacterFolio.xcodeproj`, choose your personal development team under **Signing & Capabilities**, select your connected iPhone, and Run. The project targets iOS 26 or later. Enable Developer Mode on the phone if Xcode requests it. **iPhone compilation, signing, and device testing have not been performed here** because this Mac currently has Command Line Tools, not Xcode/iOS SDKs.

Apple Intelligence must be available and enabled for local text generation. The app checks availability and remains usable without it. There is no API key, cloud-model fallback, or Siri dependency. Generated suggestions never change mechanical choices automatically.

## Content packs

See [the pack contract](docs/content-packs.md), [JSON Schema](docs/content-pack.schema.json), and [the original example](Sources/FolioCore/Resources/example-pack.json). Content is data; packs do not execute scripts. The data model currently supports the slice above, not arbitrary D&D automation.

The private converter reads adjacent checkouts by default:

```sh
node scripts/convert-vessel-pack.mjs
```

Or pass the module, importer, and private-content roots, in that order. It requires the importer's installed `js-yaml` and the ignored, visually verified `PrivatePacks/vessel-source-review.json`. It writes an ignored pack and report with revision, hashes, Wizard journal identity and PDF-review page evidence. Source repositories are read-only. Standard legacy supplemental spells remain exact sources where no revised version exists; LL suffixes are never silently removed. Conversion is curated, not a universal Foundry-to-app translator. See the [mechanism coverage and source gaps](docs/capability-coverage.md).

## Privacy and sharing

The app has no account, analytics, or backend. On Mac, saves are in `~/Library/Application Support/CharacterFolio/`; on iOS they are in the app’s sandbox. `library.previous.json` preserves the previous successful save, not a full history. For isolated development, set `FOLIO_LIBRARY_PATH` to a different directory.

`PrivatePacks/`, `Preview/`, and build output are ignored by Git. Only original demonstration content is in app resources. A private flag is a label, **not encryption or permission to redistribute source material**. Check content rights before sharing any pack or export.

See [engineering and verification notes](docs/engineering.md) for implementation boundaries and evidence.

For repository-local Codex and Claude Code instructions and skills, see [agent setup](docs/agent-setup.md).
