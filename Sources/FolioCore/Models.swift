import Foundation

public enum Ability: String, Codable, CaseIterable, Sendable, Identifiable {
    case str, dex, con, int, wis, cha
    public var id: String { rawValue }
    public var name: String {
        switch self {
        case .str: "Strength"
        case .dex: "Dexterity"
        case .con: "Constitution"
        case .int: "Intelligence"
        case .wis: "Wisdom"
        case .cha: "Charisma"
        }
    }
    public static func modifier(_ score: Int) -> Int { Int(floor(Double(score - 10) / 2)) }
}

public struct Feature: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var name: String
    public var level: Int
    public var text: String
}

public struct Talent: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var name: String
    public var text: String
    public var minimumLevel: Int
    public var exclusiveGroup: String
    public var skills: [String]
    public var requires: [String]
}

public struct Spell: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var name: String
    public var level: Int
    public var text: String
    public var source: String
    public var unavailableReason: String?
}

public struct SpellGrant: Codable, Sendable, Hashable {
    public var level: Int
    public var spellIDs: [String]
}

public struct Subclass: Codable, Sendable, Hashable, Identifiable {
    public var capabilities: DefinitionCapabilities? = nil
    public var id: String
    public var name: String
    public var text: String
    public var features: [Feature]
    public var spells: [SpellGrant]
}

public struct Progression: Codable, Sendable, Hashable, Identifiable {
    public var level: Int
    public var talents: Int
    public var cantrips: Int
    public var spells: Int
    public var slots: Int
    public var slotLevel: Int
    public var improvement: Bool
    public var id: Int { level }
}

public struct ClassDefinition: Codable, Sendable, Hashable, Identifiable {
    public var capabilities: DefinitionCapabilities? = nil
    public var id: String
    public var name: String
    public var summary: String
    public var hitDie: Int
    public var primaryAbility: Ability
    public var spellAbility: Ability?
    public var saves: [Ability]
    public var skillCount: Int
    public var skillPool: [String]
    public var subclassLevel: Int
    public var talentLabel: String
    public var features: [Feature]
    public var talents: [Talent]
    public var subclasses: [Subclass]
    public var progression: [Progression]
    public var spellIDs: [String]
    public var equipment: String
    public var armorFormula: String
    public func at(_ level: Int) -> Progression? { progression.first { $0.level == level } }
    public var maxLevel: Int { progression.map(\.level).max() ?? 1 }
}

public struct Species: Codable, Sendable, Hashable, Identifiable {
    public var capabilities: DefinitionCapabilities? = nil
    public var id: String
    public var name: String
    public var text: String
    public var speed: Int
    public var hpPerLevel: Int
    public var size: String
}

public struct Background: Codable, Sendable, Hashable, Identifiable {
    public var capabilities: DefinitionCapabilities? = nil
    public var id: String
    public var name: String
    public var text: String
    public var abilities: [Ability]
    public var skills: [String]
    public var tool: String
    public var originFeatID: String
    public var equipment: String
}

public struct Feat: Codable, Sendable, Hashable, Identifiable {
    public var capabilities: DefinitionCapabilities? = nil
    public var id: String
    public var name: String
    public var text: String
    public var category: String
    public var minimumLevel: Int
    public var abilityOptions: [Ability]
    public var abilityPoints: Int
    public var hpPerLevel: Int
    public var initiativeProficiency: Bool
    public var skills: [String]
    public var abilityMinimums: [String: Int]
}

public struct ContentSource: Codable, Sendable, Hashable {
    public var id: String
    public var version: String
    public var name: String
    public var attribution: String
    public var isPrivate: Bool
    public init(pack: ContentPack) {
        id = pack.id; version = pack.version; name = pack.name
        attribution = pack.attribution; isPrivate = pack.isPrivate
    }
}

public struct ContentPack: Codable, Sendable, Hashable, Identifiable {
    public var capabilities: PackCapabilities? = nil
    public var schemaVersion: Int
    public var id: String
    public var version: String
    public var name: String
    public var ruleset: String
    public var isPrivate: Bool
    public var attribution: String
    public var coverageNotes: [String]
    public var classes: [ClassDefinition]
    public var species: [Species]
    public var backgrounds: [Background]
    public var feats: [Feat]
    public var spells: [Spell]
    public var languages: [String]
    public var sources: [ContentSource]? = nil
    public var sourceLabels: [String: String]? = nil
    /// Snapshot-only provenance keyed by selectable definition identity.
    public var sourceCoverageNotes: [String: [String]]? = nil
    public func coverageNotes(for build: CharacterBuild) -> [String] {
        guard let scoped = sourceCoverageNotes else { return coverageNotes }
        let background = backgrounds.first { $0.id == build.backgroundID }
        var ids = Set([build.classID, build.speciesID, build.backgroundID] + build.levels.map(\.featID))
        if build.rulesProfile?.edition != "2014", let origin = background?.originFeatID { ids.insert(origin) }
        for row in build.levels {
            ids.formUnion(row.spellIDs + row.cantripIDs)
            ids.formUnion((row.capabilities?.spells ?? [:]).values.flatMap { $0 })
        }
        return Array(Set(ids.flatMap { scoped[$0] ?? [] })).sorted()
    }
    public func optionName(_ name: String, id: String) -> String {
        let matches = classes.filter { $0.name == name }.count + species.filter { $0.name == name }.count + backgrounds.filter { $0.name == name }.count + feats.filter { $0.name == name }.count
        guard matches > 1, let label = sourceLabels?[id] else { return name }
        return "\(name) · \(label)"
    }
    public static func sample() throws -> ContentPack { try bundled("example-pack") }
    public static func capabilitySample() throws -> ContentPack { try bundled("capability-pack") }
    private static func bundled(_ name: String) throws -> ContentPack {
        let packagedURL = Bundle.main.resourceURL?.appendingPathComponent("CharacterFolio_FolioCore.bundle")
        let packagedBundle = packagedURL.flatMap { Bundle(url: $0) }
        let bundle = packagedBundle ?? Bundle.module
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw FolioError.invalid("The example content pack is missing.")
        }
        return try PackValidator.decode(Data(contentsOf: url))
    }
}

public struct LevelChoice: Codable, Sendable, Hashable, Identifiable {
    public var capabilities: CapabilityChoices? = nil
    public var level: Int
    public var subclassID: String
    public var talentIDs: [String]
    public var cantripIDs: [String]
    public var spellIDs: [String]
    public var featID: String
    public var boosts: [String: Int]
    public var id: Int { level }
    public init(level: Int, previous: LevelChoice? = nil) {
        self.level = level
        subclassID = previous?.subclassID ?? ""
        talentIDs = previous?.talentIDs ?? []
        cantripIDs = previous?.cantripIDs ?? []
        spellIDs = previous?.spellIDs ?? []
        featID = ""
        boosts = [:]
        capabilities = previous?.capabilities
    }
}

public struct CharacterBuild: Codable, Sendable, Hashable, Identifiable {
    public var rulesProfile: RulesProfile? = nil
    public var upgradeReview: [String]? = nil
    public var id: UUID
    public var name: String
    public var pronouns: String
    public var concept: String
    public var classID: String
    public var speciesID: String
    public var backgroundID: String
    public var baseScores: [String: Int]
    public var backgroundBoosts: [String: Int]
    public var classSkills: [String]
    public var languages: [String]
    public var levels: [LevelChoice]
    public var backstory: String
    public var appearance: String
    public var personality: String
    public var portrait: Data?
    public var updatedAt: Date
    public var level: Int { levels.count }
    public init(classID: String) {
        id = UUID(); name = "Untitled adventurer"; pronouns = ""; concept = ""
        self.classID = classID; speciesID = ""; backgroundID = ""
        baseScores = ["str": 10, "dex": 14, "con": 13, "int": 8, "wis": 12, "cha": 15]
        backgroundBoosts = [:]; classSkills = []; languages = []
        levels = [LevelChoice(level: 1)]; backstory = ""; appearance = ""; personality = ""
        portrait = nil; updatedAt = Date()
    }
}

/// Each build pins its content, so importing a newer pack cannot silently rewrite a character.
public struct CharacterRecord: Codable, Sendable, Hashable, Identifiable {
    public var schemaVersion: Int = 1
    public var pack: ContentPack
    public var build: CharacterBuild
    public var id: UUID { build.id }
    public init(pack: ContentPack, build: CharacterBuild) { self.pack = pack; self.build = build }
}

public enum FolioError: LocalizedError {
    case invalid(String)
    public var errorDescription: String? { if case .invalid(let message) = self { message } else { nil } }
}
