import Foundation

public enum CapabilityValidation {
    public static let supported: Set<String> = ["choices", "modifiers", "casting", "editions", "resources", "traits", "proficiencies", "configuration", "languages"]

    /// Inspect JSON containers before Codable can recursively instantiate predicates.
    public static func preflight(_ data: Data) throws {
        try preflightJSON(JSONSerialization.jsonObject(with: data))
    }

    /// A library is a collection of independently bounded snapshots, not one pack.
    /// Bound unknown envelope fields too; do not bypass checks for ignored JSON.
    static func preflightLibrary(_ data: Data) throws {
        guard var envelope = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FolioError.invalid("Expected a library object.")
        }
        for key in ["packs", "characters"] {
            if let entries = envelope[key] as? [Any] {
                for entry in entries { try preflightJSON(entry) }
                envelope.removeValue(forKey: key)
            }
        }
        try preflightJSON(envelope)
    }

    private static func preflightJSON(_ root: Any) throws {
        var queue: [(Any, Int)] = [(root, 0)]
        var visited = 0
        while let (value, depth) = queue.popLast() {
            visited += 1
            guard depth <= 32, visited <= 300_000 else { throw FolioError.invalid("Content nesting or node count exceeds the safe limit.") }
            if let array = value as? [Any] { queue.append(contentsOf: array.map { ($0, depth + 1) }) }
            else if let dict = value as? [String:Any] { queue.append(contentsOf: dict.values.map { ($0, depth + 1) }) }
        }
    }

    public static func validate(_ pack: ContentPack) throws {
        func require(_ condition: Bool, _ message: String) throws { if !condition { throw FolioError.invalid(message) } }
        guard let caps = pack.capabilities else { throw FolioError.invalid("Schema 2 requires a capability contract.") }
        try require(caps.version == 1 && Set(caps.required).isSubset(of: supported), "Unsupported required capability or capability version.")
        let definitions = pack.classes.compactMap(\.capabilities) + pack.classes.flatMap { $0.subclasses.compactMap(\.capabilities) }
            + pack.species.compactMap(\.capabilities) + pack.backgrounds.compactMap(\.capabilities) + pack.feats.compactMap(\.capabilities)
        var canonicalGrants: [String: CapabilityGrant] = [:]
        for data in definitions {
            for g in (data.grants ?? []) + (data.groups ?? []).flatMap({ $0.options.flatMap(\.grants) }) {
                if let prior = canonicalGrants[g.id] { try require(prior == g, "Conflicting grant identity across definitions.") }
                canonicalGrants[g.id] = g
            }
        }
        for definition in definitions {
            try require(["2014", "2024"].contains(definition.edition), "Unknown definition edition.")
            let owner = pack.classes.first { $0.capabilities == definition || $0.subclasses.contains { $0.capabilities == definition } }
            let scope = owner.map { [$0.capabilities].compactMap { $0 } + $0.subclasses.compactMap(\.capabilities) } ?? [definition]
            let groups = scope.flatMap { $0.groups ?? [] }, options = groups.flatMap(\.options)
            let configurationList = scope.flatMap { $0.configurations ?? [] }
            let configs = Set(configurationList.map(\.id))
            func identity(_ id: String) -> Bool { !id.isEmpty && id.count <= 120 }
            try require(configs.count == configurationList.count && configs.allSatisfy(identity), "Invalid configuration identities.")
            try require(groups.count <= 64 && options.count <= 500 && configs.count <= 64, "Too many capability choices.")
            try require(Set(groups.map(\.id)).count == groups.count, "Duplicate choice group identity.")
            // Option identity is shared across tracks so bonus/purchased ownership cannot double-grant it.
            var known: [String:CapabilityOption] = [:]
            for option in options {
                try require(!option.id.isEmpty && option.id.count <= 120, "Invalid option identity.")
                if let previous = known[option.id] { try require(previous == option, "Conflicting shared option identity.") }
                known[option.id] = option
            }
            var predicateNodes = 0
            func predicate(_ p: RulePredicate?, _ depth: Int = 0) throws {
                if depth == 0 { predicateNodes = 0 }
                guard let p else { return }
                predicateNodes += 1
                try require(predicateNodes <= 256, "Predicate node budget exceeded.")
                try require(depth <= 8 && (p.children?.count ?? 0) <= 16, "Predicate complexity exceeds bounds.")
                switch p.kind {
                case .all, .any: try require(!(p.children ?? []).isEmpty, "Empty composite predicate.")
                case .not: try require(p.children?.count == 1, "Not requires one predicate.")
                case .level: try require((1...5).contains(p.minimum ?? 0), "Unsupported prerequisite level.")
                case .ability: try require(Ability(rawValue: p.key ?? "") != nil && (1...30).contains(p.minimum ?? 0), "Invalid ability prerequisite.")
                case .selection: try require(known[p.key ?? ""] != nil, "Missing selection prerequisite.")
                case .configuration: try require(configs.contains(p.key ?? ""), "Unknown configuration predicate.")
                case .proficiency: try require(RulesEngine.skillAbilities[p.key ?? ""] != nil, "Unknown proficiency prerequisite.")
                case .subclass: try require(pack.classes.contains { $0.subclasses.contains { $0.id == p.key } }, "Unknown subclass prerequisite.")
                }
                for child in p.children ?? [] { try predicate(child, depth + 1) }
            }
            func references(_ p: RulePredicate?) -> [String] {
                guard let p else { return [] }
                return (p.kind == .selection ? [p.key ?? ""] : []) + (p.children ?? []).flatMap { references($0) }
            }
            var completed: Set<String> = []
            func visit(_ id: String, _ path: Set<String>) throws {
                try require(!path.contains(id), "Cyclic selection prerequisites.")
                if completed.contains(id) { return }
                for next in references(known[id]?.prerequisite) { try visit(next, path.union([id])) }
                completed.insert(id)
            }
            func grant(_ g: CapabilityGrant) throws {
                try require(identity(g.id) && (1...5).contains(g.level ?? 1), "Invalid grant identity or level.")
                try predicate(g.condition)
                if let v = g.value {
                    try require((-1000...1000).contains(v.minimum ?? 0), "Unsafe rule minimum.")
                    try require((-1000...1000).contains(v.base ?? 0) && (-100...100).contains(v.levelMultiplier ?? 0) && (-10...10).contains(v.proficiencyMultiplier ?? 0) && (v.abilities?.count ?? 0) <= 6, "Unsafe rule value.")
                    try require((v.table?.count ?? 0) <= 5 && (v.table ?? []).allSatisfy { (-1000...1000).contains($0) }, "Invalid resource/value table.")
                }
                if [.proficiency, .skillAbility, .skillBonus].contains(g.kind) {
                    try require(RulesEngine.skillAbilities[g.target ?? ""] != nil || g.target == "all-skills", "Unknown skill target.")
                }
                if g.kind == .proficiency { try require(g.rank != nil, "Proficiency grant needs a rank.") }
                if g.kind == .skillAbility { try require(g.ability != nil, "Skill substitution needs an ability.") }
                if g.kind == .abilityScore { try require(Ability(rawValue: g.target ?? "") != nil, "Unknown ability target.") }
                if g.kind == .spell { try require(pack.spells.contains { $0.id == g.target }, "Missing granted spell.") }
                if g.spellMode != nil { try require(g.kind == .spell, "Spell classification belongs only to spell grants.") }
                if g.kind == .size { try require(["Tiny","Small","Medium","Large","Huge","Gargantuan"].contains(g.target ?? ""), "Unknown size grant.") }
                if g.kind == .language {
                    let name = g.target ?? ""
                    try require(identity(name) && name == name.trimmingCharacters(in: .whitespacesAndNewlines) && name.rangeOfCharacter(from: .controlCharacters) == nil, "Language grants require a bounded, nonempty language name.")
                }
            }
            for group in groups {
                if group.languageChoices == true {
                    try require(group.options.allSatisfy { option in
                        option.repeatable != true && option.grants.count == 1 && option.grants[0].kind == .language && option.grants[0].condition == nil && (option.grants[0].level ?? 1) == 1
                    }, "Language-choice options must each grant exactly one unconditional language, without repeatability.")
                    try require(Set(group.options.compactMap { $0.grants.first?.target }).count == group.options.count, "Language-choice options must name distinct languages.")
                }
                try require(identity(group.id) && group.options.count <= 500, "Invalid group identity or size.")
                if let required = group.requiredOptionID { try require(group.options.contains { $0.id == required }, "Missing required bonus option.") }
                if let family = group.requiredOptionIDs { try require(!family.isEmpty && Set(family).count == family.count && Set(family).isSubset(of: Set(group.options.map(\.id))), "Invalid required option family.") }
                if group.waiveRequiredFamilyIfOwned == true { try require(group.requiredOptionIDs != nil, "Family waiver needs an explicit required family.") }
                if let exceptions = group.exclusiveGroupExceptions {
                    let families = Set(group.options.compactMap(\.exclusiveGroup).filter { !$0.isEmpty })
                    try require(exceptions.count <= 64 && Set(exceptions).count == exceptions.count && Set(exceptions).isSubset(of: families), "Invalid track-specific exclusivity exception.")
                }
                try require((1...5).contains(group.counts.count) && group.counts.allSatisfy { (0...30).contains($0) }, "Invalid choice count table.")
                try require((group.replacementLimits ?? []).allSatisfy { (0...30).contains($0) } && (group.replacementLimits?.count ?? 0) <= 5, "Invalid replacement schedule.")
                try require(Set(group.options.map(\.id)).count == group.options.count, "Duplicate option in group.")
                try predicate(group.condition)
                for option in group.options { try require(option.grants.count <= 128, "Too many option grants."); try predicate(option.prerequisite); for g in option.grants { try grant(g) } }
            }
            for id in known.keys { try visit(id, []) }
            for config in definition.configurations ?? [] { try predicate(config.prerequisite) }
            func configReferences(_ p: RulePredicate?) -> [String] {
                guard let p else { return [] }
                return (p.kind == .configuration ? [p.key ?? ""] : []) + (p.children ?? []).flatMap(configReferences)
            }
            var configDone = Set<String>()
            func visitConfig(_ id: String, _ path: Set<String>) throws {
                try require(!path.contains(id), "Cyclic configuration prerequisites.")
                if configDone.contains(id) { return }
                for next in configReferences(configurationList.first { $0.id == id }?.prerequisite) { try visitConfig(next, path.union([id])) }
                configDone.insert(id)
            }
            for id in configs { try visitConfig(id, []) }
            let allGrants = scope.flatMap { ($0.grants ?? []) + ($0.groups ?? []).flatMap { $0.options.flatMap(\.grants) } }
            try require(allGrants.count <= 4096 && (definition.grants?.count ?? 0) <= 128, "Too many grants.")
            var grantIDs: [String: CapabilityGrant] = [:]
            for g in allGrants {
                if let previous = grantIDs[g.id] { try require(previous == g, "Conflicting grant identity.") }
                grantIDs[g.id] = g
            }
            for g in definition.grants ?? [] { try grant(g) }
            for adapter in definition.adapters ?? [] {
                try require((adapter.subclassLevel.map { (1...5).contains($0) } ?? true) && adapter.replacementGrants.count <= 128, "Invalid adapter bounds.")
                try require(["2014", "2024"].contains(adapter.edition) && !adapter.canonicalID.isEmpty && !adapter.label.isEmpty, "Adapter needs explicit edition, identity and label.")
                for g in adapter.replacementGrants { try grant(g) }
            }
            try require((definition.adapters?.count ?? 0) <= 2 && Set((definition.adapters ?? []).map(\.edition)).count == (definition.adapters?.count ?? 0), "Duplicate or excessive edition adapters.")
            let scopedPolicies = scope.flatMap { $0.casting ?? [] }
            try require(Set(scopedPolicies.map(\.id)).count == scopedPolicies.count, "Duplicate scoped casting policy identity.")
            let policies = definition.casting ?? []
            try require(policies.count <= 32 && Set(policies.map(\.id)).count == policies.count, "Invalid casting policy identities.")
            for policy in policies {
                try require(identity(policy.id) && (policy.replacementLimits?.count ?? 0) <= 5 && (policy.preparedCounts?.count ?? 0) <= 5, "Invalid casting bounds.")
                try predicate(policy.condition)
                try require((1...5).contains(policy.counts.count) && policy.counts.allSatisfy { (0...100).contains($0) }, "Invalid casting counts.")
                try require(policy.maximumSpellLevels.count == policy.counts.count && policy.maximumSpellLevels.allSatisfy { (0...9).contains($0) }, "Invalid casting spell-level table.")
                try require(Set(policy.spellIDs).count == policy.spellIDs.count && Set(policy.spellIDs).isSubset(of: Set(pack.spells.map(\.id))), "Missing or duplicate casting spell.")
                try require((policy.replacementLimits ?? []).allSatisfy { (0...100).contains($0) } && (policy.preparedCounts ?? []).allSatisfy { (0...100).contains($0) }, "Invalid casting replacement/preparation counts.")
            }
        }
    }
}
