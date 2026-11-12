import Foundation

public enum PackValidator {
    public static func decode(_ data: Data) throws -> ContentPack {
        guard data.count <= 10_000_000 else { throw FolioError.invalid("Content packs must be smaller than 10 MB.") }
        try CapabilityValidation.preflight(data)
        let pack = try JSONDecoder().decode(ContentPack.self, from: data)
        try validate(pack)
        return pack
    }

    public static func validate(_ pack: ContentPack) throws {
        func require(_ condition: Bool, _ message: String) throws {
            guard condition else { throw FolioError.invalid(message) }
        }
        func unique(_ ids: [String], _ label: String) throws {
            try require(ids.count == Set(ids).count && ids.allSatisfy { !$0.isEmpty && $0.count <= 120 }, "\(label) must have unique, nonempty IDs of at most 120 characters.")
        }
        try require([1, 2].contains(pack.schemaVersion), "This pack uses an unsupported schema version.")
        try require(pack.schemaVersion == 1 ? pack.ruleset == "2024" : ["2014", "2024"].contains(pack.ruleset), "Unsupported rules edition.")
        if pack.schemaVersion == 2 { try CapabilityValidation.validate(pack) }
        try require(!pack.id.isEmpty && !pack.version.isEmpty && !pack.name.isEmpty, "Pack ID, version, and name are required.")
        let combined = pack.sources != nil
        try require(pack.classes.count <= (combined ? 100 : 20) && pack.species.count <= (combined ? 1000 : 100) && pack.backgrounds.count <= (combined ? 2000 : 200) && pack.spells.count <= (combined ? 10000 : 2000) && pack.feats.count <= (combined ? 5000 : 500), "This content exceeds supported limits.")
        try require(!pack.classes.isEmpty || !pack.species.isEmpty || !pack.backgrounds.isEmpty || !pack.feats.isEmpty || !pack.spells.isEmpty || !pack.languages.isEmpty, "This content pack is empty.")
        if let sources = pack.sources {
            try require(!sources.isEmpty && sources.count <= 100, "A library snapshot must contain 1–100 sources.")
            try require(Set(sources.map { [$0.id, $0.version] }).count == sources.count, "Duplicate source revisions in snapshot.")
            try require(!sources.contains(where: \.isPrivate) || pack.isPrivate, "Private source content must remain marked private.")
        }
        try unique(pack.classes.map(\.id), "Classes")
        try unique(pack.species.map(\.id), "Species")
        try unique(pack.backgrounds.map(\.id), "Backgrounds")
        try unique(pack.spells.map(\.id), "Spells")
        try unique(pack.feats.map(\.id), "Feats")
        try unique(pack.languages, "Languages")
        try require(pack.languages.count <= 200 && !pack.languages.contains("Common"), "Supply up to 200 additional languages; Common is granted automatically.")
        let spellIDs = Set(pack.spells.map(\.id))
        for spell in pack.spells { try require((0...9).contains(spell.level), "\(spell.name) has an invalid spell level.") }
        for species in pack.species { try require((5...120).contains(species.speed) && (0...10).contains(species.hpPerLevel), "\(species.name) has invalid movement or HP values.") }
        for feat in pack.feats {
            try require(["origin", "general"].contains(feat.category) && (1...5).contains(feat.minimumLevel) && (0...2).contains(feat.abilityPoints) && (0...10).contains(feat.hpPerLevel), "\(feat.name) has unsupported feat rules.")
            try require(feat.category != "origin" || feat.abilityPoints == 0, "Origin feats with ability-score choices are not supported yet.")
            try require(feat.abilityPoints == 0 || !feat.abilityOptions.isEmpty, "\(feat.name) needs ability options.")
            try require(feat.skills.allSatisfy { RulesEngine.skillAbilities[$0] != nil }, "\(feat.name) references an unknown skill.")
            try require(feat.abilityMinimums.allSatisfy { Ability(rawValue: $0.key) != nil && (1...20).contains($0.value) }, "\(feat.name) has invalid prerequisites.")
        }
        for background in pack.backgrounds {
            let revised = (background.capabilities?.edition ?? pack.ruleset) == "2024"
            try require(!revised || background.abilities.count == 3 && Set(background.abilities).count == 3, "\(background.name) must define three distinct background abilities.")
            try require(background.skills.count == 2 && Set(background.skills).count == 2 && background.skills.allSatisfy { RulesEngine.skillAbilities[$0] != nil }, "\(background.name) must grant two distinct known skills.")
            try require(!revised || pack.feats.contains { $0.id == background.originFeatID && $0.category == "origin" }, "\(background.name) references a missing origin feat.")
        }
        for cls in pack.classes {
            try require([6, 8, 10, 12].contains(cls.hitDie) && (0...4).contains(cls.skillCount), "\(cls.name) has unsupported hit dice or skill counts.")
            try require(cls.skillPool.count >= cls.skillCount && Set(cls.skillPool).count == cls.skillPool.count && cls.skillPool.allSatisfy { RulesEngine.skillAbilities[$0] != nil }, "\(cls.name) has an invalid skill pool.")
            try require(cls.saves.count == 2 && Set(cls.saves).count == 2, "\(cls.name) must grant two distinct saving throws.")
            try require((1...5).contains(cls.maxLevel) && cls.progression.map(\.level).sorted() == Array(1...cls.maxLevel), "\(cls.name) must define every supported level, from 1 up to at most 5.")
            try require(["unarmored", "vessel-mantle"].contains(cls.armorFormula), "\(cls.name) uses an unsupported armor formula.")
            try require(Set(cls.spellIDs).isSubset(of: spellIDs) && Set(cls.spellIDs).count == cls.spellIDs.count, "\(cls.name) references missing or duplicate spells.")
            try unique(cls.talents.map(\.id), "Class options")
            try unique(cls.subclasses.map(\.id), "Subclasses")
            try require((1...5).contains(cls.subclassLevel), "Subclass level must be within the supported range.")
            for talent in cls.talents {
                try require((1...20).contains(talent.minimumLevel) && talent.skills.allSatisfy { RulesEngine.skillAbilities[$0] != nil }, "\(talent.name) has unsupported prerequisites or skills.")
                try require(Set(talent.requires).isSubset(of: Set(cls.talents.map(\.id))) && !talent.requires.contains(talent.id), "\(talent.name) references a missing prerequisite or itself.")
            }
            var previous: Progression?
            for p in cls.progression.sorted(by: { $0.level < $1.level }) {
                try require((0...20).contains(p.talents) && (0...10).contains(p.cantrips) && (0...30).contains(p.spells) && (0...10).contains(p.slots) && (0...9).contains(p.slotLevel), "\(cls.name) has invalid progression counts.")
                try require((p.slots == 0) == (p.slotLevel == 0), "Spell-slot count and level must both be zero or both be positive.")
                if let previous { try require(p.talents >= previous.talents && p.spells >= previous.spells && p.cantrips >= previous.cantrips, "Decreasing choice counts are not supported in this MVP.") }
                previous = p
            }
            for subclass in cls.subclasses {
                for grant in subclass.spells { try require((1...20).contains(grant.level) && Set(grant.spellIDs).isSubset(of: spellIDs), "\(subclass.name) references a missing granted spell.") }
            }
        }
    }

    public static func validateRecord(_ record: CharacterRecord) throws {
        try validate(record.pack)
        guard try LibraryStorage.encoder.encode(record).count <= 20_000_000 else { throw FolioError.invalid("Character files must be smaller than 20 MB.") }
        let b = record.build
        if b.rulesProfile != nil {
            guard b.levels.enumerated().allSatisfy({ $0.element.level == $0.offset + 1 }) else { throw FolioError.invalid("Capability history must contain consecutive levels starting at one.") }
        }
        if let profile = b.rulesProfile {
            guard record.pack.schemaVersion == 2, profile.evaluator == 2, ["2014", "2024"].contains(profile.edition) else {
                throw FolioError.invalid("Unsupported pinned rules profile or evaluator.")
            }
        } else if record.pack.classes.first(where: { $0.id == b.classID })?.capabilities != nil || b.levels.contains(where: { $0.capabilities != nil }) {
            throw FolioError.invalid("Capability choices require an explicit rules profile.")
        }
        for level in b.levels {
            guard let choices = level.capabilities else { continue }
            let dictionaries = [choices.groups ?? [:], choices.spells ?? [:], choices.prepared ?? [:]]
            guard (choices.configurations?.count ?? 0) <= 64,
                  dictionaries.allSatisfy({ $0.count <= 64 && $0.allSatisfy { $0.key.count <= 120 && $0.value.count <= 100 && $0.value.allSatisfy { $0.count <= 120 } } }) else {
                throw FolioError.invalid("Saved capability selections exceed supported bounds.")
            }
        }
        guard record.schemaVersion == 1, (1...5).contains(b.levels.count),
              b.baseScores.values.allSatisfy({ (1...30).contains($0) }),
              b.backgroundBoosts.values.allSatisfy({ (0...2).contains($0) }),
              b.levels.allSatisfy({ (1...5).contains($0.level) && $0.boosts.values.allSatisfy({ (0...2).contains($0) }) }),
              (b.portrait?.count ?? 0) <= 5_000_000 else { throw FolioError.invalid("This character has unsupported data or an oversized portrait.") }
    }
}
