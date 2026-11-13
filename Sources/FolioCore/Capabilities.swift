import Foundation

/// A profile is pinned on a build; schema version and rules edition are independent.
public struct RulesProfile: Codable, Sendable, Hashable {
    public var edition: String
    public var evaluator: Int
    public init(edition: String, evaluator: Int = 2) { self.edition = edition; self.evaluator = evaluator }
}

public struct PackCapabilities: Codable, Sendable, Hashable {
    public var version: Int
    public var required: [String]
    public init(version: Int = 1, required: [String] = []) { self.version = version; self.required = required }
}

public enum ProficiencyRank: String, Codable, Sendable, CaseIterable {
    case none, half, proficient, expertise
    public func bonus(_ proficiency: Int) -> Int {
        switch self { case .none: 0; case .half: proficiency / 2; case .proficient: proficiency; case .expertise: proficiency * 2 }
    }
}

/// Closed operations only: no executable strings or arbitrary expression language.
public struct RuleValue: Codable, Sendable, Hashable {
    public var base: Int?
    public var abilities: [Ability]?
    public var levelMultiplier: Int?
    public var proficiencyMultiplier: Int?
    public var table: [Int]?
    public var minimum: Int?
    public init(base: Int = 0, abilities: [Ability] = [], levelMultiplier: Int = 0, proficiencyMultiplier: Int = 0, table: [Int]? = nil, minimum: Int? = nil) {
        self.base = base; self.abilities = abilities; self.levelMultiplier = levelMultiplier
        self.proficiencyMultiplier = proficiencyMultiplier; self.table = table; self.minimum = minimum
    }
    public func resolve(level: Int, scores: [String:Int], proficiency: Int) -> Int {
        let row = table.flatMap { $0.indices.contains(level - 1) ? $0[level - 1] : nil } ?? 0
        let result = (base ?? 0) + row + (levelMultiplier ?? 0) * level + (proficiencyMultiplier ?? 0) * proficiency
            + (abilities ?? []).reduce(0) { $0 + Ability.modifier(scores[$1.rawValue, default: 10]) }
        return max(minimum ?? -10000, result)
    }
}

public struct RulePredicate: Codable, Sendable, Hashable {
    public enum Kind: String, Codable, Sendable { case all, any, not, level, ability, selection, proficiency, configuration, subclass }
    public var kind: Kind
    public var key: String?
    public var minimum: Int?
    public var children: [RulePredicate]?
    public init(_ kind: Kind, key: String? = nil, minimum: Int? = nil, children: [RulePredicate]? = nil) {
        self.kind = kind; self.key = key; self.minimum = minimum; self.children = children
    }
}

public struct CapabilityGrant: Codable, Sendable, Hashable, Identifiable {
    public enum SpellMode: String, Codable, Sendable { case granted, prepared, atWill, limited, ritual }
    public var spellMode: SpellMode? = nil
    public enum Kind: String, Codable, Sendable {
        case proficiency, skillAbility, skillBonus, armorFormula, armorBonus, hitPoints, initiative, speed, speedBase, abilityScore
        case trait, resource, spell, size, language, abilityCap, unsupported, manual
    }
    public var id: String
    public var kind: Kind
    public var target: String?
    public var value: RuleValue?
    public var rank: ProficiencyRank?
    public var ability: Ability?
    public var condition: RulePredicate?
    public var level: Int?
    public var text: String?
    public var recovery: String?
    public init(id: String, kind: Kind, target: String? = nil, value: RuleValue? = nil, rank: ProficiencyRank? = nil, ability: Ability? = nil, condition: RulePredicate? = nil, level: Int = 1, text: String? = nil, recovery: String? = nil) {
        self.id = id; self.kind = kind; self.target = target; self.value = value; self.rank = rank; self.ability = ability
        self.condition = condition; self.level = level; self.text = text; self.recovery = recovery
    }
}

public struct CapabilityOption: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var name: String
    public var text: String
    public var prerequisite: RulePredicate?
    public var grants: [CapabilityGrant]
    public var repeatable: Bool?
    public var exclusiveGroup: String?
    public init(id: String, name: String, text: String = "", prerequisite: RulePredicate? = nil, grants: [CapabilityGrant] = [], repeatable: Bool = false, exclusiveGroup: String? = nil) {
        self.id = id; self.name = name; self.text = text; self.prerequisite = prerequisite; self.grants = grants
        self.repeatable = repeatable; self.exclusiveGroup = exclusiveGroup
    }
}

/// Each row contains the total owned choices at that level, not incremental picks.
public struct CapabilityChoiceGroup: Codable, Sendable, Hashable, Identifiable {
    /// Explicit language-selection slots, unlike feature choices with incidental grants.
    public var languageChoices: Bool? = nil
    public enum RequirementTiming: String, Codable, Sendable { case ongoing, acquisition }
    public var requirementTiming: RequirementTiming? = nil
    /// A locked bonus grants this option unless it is already owned in another track.
    public var requiredOptionID: String? = nil
    /// At least one member is mandatory, even when another member is owned elsewhere.
    public var requiredOptionIDs: [String]? = nil
    /// An accepted family member in another track permits any distinct eligible bonus.
    public var waiveRequiredFamilyIfOwned: Bool? = nil
    /// Permit an additional distinct family variant across tracks, never within this track.
    public var exclusiveGroupExceptions: [String]? = nil
    public var id: String
    public var name: String
    public var counts: [Int]
    public var options: [CapabilityOption]
    public var replacementLimits: [Int]?
    public var condition: RulePredicate?
    public var locked: Bool?
    public init(id: String, name: String, counts: [Int], options: [CapabilityOption], replacementLimits: [Int]? = nil, condition: RulePredicate? = nil, locked: Bool = false) {
        self.id = id; self.name = name; self.counts = counts; self.options = options; self.replacementLimits = replacementLimits; self.condition = condition; self.locked = locked
    }
    public func count(at level: Int) -> Int { counts.indices.contains(level - 1) ? counts[level - 1] : 0 }
}

public struct CapabilityConfiguration: Codable, Sendable, Hashable, Identifiable {
    public var prerequisite: RulePredicate? = nil
    public var exclusiveGroup: String? = nil
    public var id: String
    public var name: String
    public var text: String
    public init(id: String, name: String, text: String = "") { self.id = id; self.name = name; self.text = text }
}

public struct CastingPolicy: Codable, Sendable, Hashable, Identifiable {
    /// Subclass interaction with legacy class acquisition. Absence preserves
    /// the historical implicit replacement contract of older pinned definitions.
    public enum LegacyClassCasting: String, Codable, Sendable { case preserve, replace }
    public var legacyClassCasting: LegacyClassCasting? = nil
    /// Absent retains historical schema-2 preparation semantics. Retained lists
    /// (even when their displayed name says Prepared) are not daily loadouts.
    public enum Loadout: String, Codable, Sendable { case editable, retained }
    public var loadout: Loadout? = nil
    public var poolIDs: [String]? = nil
    public var preparation: RuleValue? = nil
    /// Automatic additions are separately classified and never spend picks.
    public var alwaysGrantedSpellIDs: [String]? = nil
    public enum Mode: String, Codable, Sendable { case known, prepared, book, granted, ritual, limited, atWill }
    public var id: String
    public var name: String
    public var mode: Mode
    public var ability: Ability
    public var spellIDs: [String]
    public var counts: [Int]
    public var maximumSpellLevels: [Int]
    public var replacementLimits: [Int]?
    public var preparedCounts: [Int]?
    public var condition: RulePredicate?
    public var text: String?
    public init(id: String, name: String, mode: Mode, ability: Ability, spellIDs: [String], counts: [Int], maximumSpellLevels: [Int], replacementLimits: [Int]? = nil, preparedCounts: [Int]? = nil, condition: RulePredicate? = nil, text: String? = nil) {
        self.id = id; self.name = name; self.mode = mode; self.ability = ability; self.spellIDs = spellIDs; self.counts = counts
        self.maximumSpellLevels = maximumSpellLevels; self.replacementLimits = replacementLimits; self.preparedCounts = preparedCounts; self.condition = condition; self.text = text
    }
}

public struct DefinitionCapabilities: Codable, Sendable, Hashable {
    public var spellPools: [SpellPool]? = nil
    public var edition: String
    public var grants: [CapabilityGrant]?
    public var groups: [CapabilityChoiceGroup]?
    public var configurations: [CapabilityConfiguration]?
    public var casting: [CastingPolicy]?
    public var adapters: [EditionAdapter]?
    public init(edition: String, grants: [CapabilityGrant] = [], groups: [CapabilityChoiceGroup] = [], configurations: [CapabilityConfiguration] = [], casting: [CastingPolicy] = [], adapters: [EditionAdapter] = []) {
        self.edition = edition; self.grants = grants; self.groups = groups; self.configurations = configurations; self.casting = casting; self.adapters = adapters
    }
}

public struct EditionAdapter: Codable, Sendable, Hashable {
    public var edition: String
    public var canonicalID: String
    public var label: String
    public var replacementGrants: [CapabilityGrant]
    public var subclassLevel: Int?
    public init(edition: String, canonicalID: String, label: String, replacementGrants: [CapabilityGrant] = [], subclassLevel: Int? = nil) {
        self.edition = edition; self.canonicalID = canonicalID; self.label = label; self.replacementGrants = replacementGrants; self.subclassLevel = subclassLevel
    }
}

public struct CapabilityChoices: Codable, Sendable, Hashable {
    public var groups: [String: [String]]?
    public var configurations: [String]?
    public var spells: [String: [String]]?
    public var prepared: [String: [String]]?
    public init(groups: [String:[String]] = [:], configurations: [String] = [], spells: [String:[String]] = [:], prepared: [String:[String]] = [:]) {
        self.groups = groups; self.configurations = configurations; self.spells = spells; self.prepared = prepared
    }
}

public struct ResourceCapacity: Sendable, Hashable, Identifiable {
    public var id: String
    public var name: String
    public var maximum: Int
    public var recovery: String
}

public struct CapabilityProvenance: Sendable, Hashable {
    public var grantID: String
    public var sourceID: String
    public var level: Int
}
