import Foundation

public enum CapabilityValidation {
    public static let supported: Set<String> = ["choices", "modifiers", "casting", "editions", "resources", "traits", "proficiencies", "configuration", "languages", "spell-pools", "multiclass", "equipment"]

    /// Old class-local IDs remain valid for single-class snapshots. New authored
    /// multiclass policies must be unambiguous; combined libraries are checked
    /// against participating classes only when a multiclass history is selected.
    static func validateTrackOwnership(_ pack: ContentPack, classIDs: Set<String>? = nil) throws {
        if let classIDs, classIDs.count < 2 { return }
        let classes=pack.classes.filter { cls in classIDs.map { $0.contains(cls.id) } ?? (cls.multiclass != nil) }
        var owners:[String:String]=[:]
        func register(_ data: DefinitionCapabilities, owner: String) throws {
            let ids=(data.groups ?? []).map(\.id) + (data.configurations ?? []).map(\.id) + (data.casting ?? []).map(\.id)
            for id in ids {
                if let prior=owners[id], prior != owner || owner != "shared species/background/feat definitions" {
                    throw FolioError.invalid("Capability track ownership conflict for '\(id)': \(prior) and \(owner). Give class-owned groups, configurations and casting policies distinct IDs; shared common tracks cannot also belong to a class.")
                }
                owners[id]=owner
            }
        }
        for data in pack.species.compactMap(\.capabilities) + pack.backgrounds.compactMap(\.capabilities) + pack.feats.compactMap(\.capabilities) {
            try register(data,owner:"shared species/background/feat definitions")
        }
        for cls in classes {
            for data in [cls.capabilities].compactMap({ $0 }) + cls.subclasses.compactMap(\.capabilities) {
                try register(data,owner:"class \(cls.name) [\(cls.id)]")
            }
        }
    }

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
        if pack.sources == nil { try validateTrackOwnership(pack) }
        for cls in pack.classes {
            guard let policy=cls.multiclass else { continue }
            try require(caps.required.contains("multiclass") && cls.capabilities != nil,"Multiclass contracts require the multiclass capability and explicit class edition.")
            try require(!policy.canonicalID.isEmpty && policy.canonicalID.count <= 120,"Multiclass canonical identity is required.")
            try require((0...4).contains(policy.laterSkillCount ?? 0) && (policy.laterSkillCount ?? 0) <= cls.skillPool.count,"Invalid later-class skill count.")
            func prerequisite(_ p: RulePredicate, depth: Int = 0) -> Bool {
                guard depth < 8 else { return false }
                if p.kind == .ability { return Ability(rawValue:p.key ?? "") != nil && (1...30).contains(p.minimum ?? 0) }
                return [.all,.any].contains(p.kind) && !(p.children ?? []).isEmpty && (p.children?.count ?? 0) <= 12 && (p.children ?? []).allSatisfy { prerequisite($0,depth:depth+1) }
            }
            try require(policy.prerequisites.map { prerequisite($0) } ?? true,"Entry prerequisites must be bounded ability/all/any predicates.")
            let training=policy.laterProficiencies + (policy.startingProficiencies ?? [])
            try require(training.count <= 60 && training.allSatisfy { $0.kind == .proficiency && $0.rank == .proficient && $0.condition == nil && $0.value == nil && ($0.level ?? 1) == 1 && !($0.target ?? "").isEmpty && ($0.target?.count ?? 0) <= 120 && !($0.target ?? "").hasPrefix("save.") && $0.target != "all-saves" && !$0.id.isEmpty && $0.id.count <= 120 },"Class training must be fixed proficiency grants, not saving throws or effects.")
            if let casting=policy.casting {
                let pools=([cls.capabilities].compactMap { $0 } + cls.subclasses.compactMap(\.capabilities)).flatMap { $0.spellPools ?? [] }
                try require((1...20).contains(casting.divisor) && (1...20).contains(casting.startsAt) && Set(casting.poolIDs).count == casting.poolIDs.count && Set(casting.poolIDs).isSubset(of:Set(pools.map(\.id))),"Invalid multiclass contribution or pool references.")
                if casting.kind == .ordinary {
                    try require(!casting.poolIDs.isEmpty && pools.filter { casting.poolIDs.contains($0.id) }.allSatisfy { $0.kind == .ordinary },"Ordinary contribution must reference ordinary pools.")
                }
            }
        }
        let definitions = pack.classes.compactMap(\.capabilities) + pack.classes.flatMap { $0.subclasses.compactMap(\.capabilities) }
            + pack.species.compactMap(\.capabilities) + pack.backgrounds.compactMap(\.capabilities) + pack.feats.compactMap(\.capabilities)
        var canonicalGrants: [String: CapabilityGrant] = [:]
        let allPools = definitions.flatMap { $0.spellPools ?? [] }
        try require(Set(allPools.map(\.id)).count == allPools.count, "Duplicate spell pool identity.")
        let newCasting = definitions.contains { !($0.spellPools ?? []).isEmpty || ($0.casting ?? []).contains { $0.loadout != nil || $0.poolIDs != nil || $0.preparation != nil || $0.alwaysGrantedSpellIDs != nil || $0.legacyClassCasting != nil } }
        try require(!newCasting || caps.required.contains("spell-pools"), "Tiered casting requires the spell-pools capability declaration.")
        if newCasting {
            let policies=definitions.flatMap { $0.casting ?? [] }
            try require(Set(policies.map(\.id)).count == policies.count, "Casting policy identities must be unique across source definitions.")
        }
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
                case .level: try require((1...20).contains(p.minimum ?? 0), "Unsupported prerequisite level.")
                case .ability: try require(Ability(rawValue: p.key ?? "") != nil && (1...30).contains(p.minimum ?? 0), "Invalid ability prerequisite.")
                case .selection: try require(known[p.key ?? ""] != nil, "Missing selection prerequisite.")
                case .configuration: try require(configs.contains(p.key ?? ""), "Unknown configuration predicate.")
                case .equipment: try require(caps.required.contains("equipment") && ["unarmored","noShield","unarmed"].contains(p.key ?? ""), "Unknown equipment condition.")
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
            func ruleValue(_ value: RuleValue?) throws {
                if let v = value {
                    try require((-1000...1000).contains(v.minimum ?? 0), "Unsafe rule minimum.")
                    try require((-1000...1000).contains(v.base ?? 0) && (-100...100).contains(v.levelMultiplier ?? 0) && (-10...10).contains(v.proficiencyMultiplier ?? 0) && (v.abilities?.count ?? 0) <= 6, "Unsafe rule value.")
                    try require((v.table?.count ?? 0) <= 20 && (v.table ?? []).allSatisfy { (-1000...1000).contains($0) }, "Invalid resource/value table.")
                }
            }
            func grant(_ g: CapabilityGrant) throws {
                try require(identity(g.id) && (1...20).contains(g.level ?? 1), "Invalid grant identity or level.")
                try predicate(g.condition)
                try ruleValue(g.value)
                if [.proficiency, .skillAbility, .skillBonus].contains(g.kind) {
                    let saveTarget = g.kind == .proficiency && (g.target == "all-saves" || Ability.allCases.contains { "save." + $0.rawValue == g.target })
                    try require(RulesEngine.skillAbilities[g.target ?? ""] != nil || g.target == "all-skills" || saveTarget || (g.kind == .proficiency && EquipmentEngine.trainingKeys.contains(g.target ?? "")), "Unknown skill or equipment training target.")
                }
                if g.kind == .proficiency { try require(g.rank != nil, "Proficiency grant needs a rank.") }
                if g.kind == .equipment || g.equipment != nil {
                    try require(caps.required.contains("equipment") && g.kind == .equipment && g.equipment != nil,"Equipment rules require the equipment capability.")
                    try EquipmentEngine.validateRule(g.equipment!)
                    if g.equipment?.kind == .unarmed {
                        let value=g.value ?? .init()
                        let applicable=(g.level ?? 1)...max(g.level ?? 1,owner?.maxLevel ?? 20)
                        let complete=applicable.allSatisfy { at in
                            (value.table == nil || value.table!.indices.contains(at - 1))
                                && [4,6,8,10,12].contains(value.resolve(level:at,scores:[:],proficiency:0))
                        }
                        try require((value.abilities ?? []).isEmpty && (value.levelMultiplier ?? 0) == 0 && (value.proficiencyMultiplier ?? 0) == 0 && value.minimum == nil && complete,"Unarmed dice must explicitly resolve to supported die sides at every applicable supported level.")
                    }
                }
                if g.kind == .skillAbility { try require(g.ability != nil, "Skill substitution needs an ability.") }
                if g.kind == .abilityScore || g.kind == .abilityCap { try require(Ability(rawValue: g.target ?? "") != nil, "Unknown ability target.") }
                if g.kind == .abilityCap {
                    try require((20...30).contains(g.value?.base ?? 0) && (g.value?.abilities ?? []).isEmpty && (g.value?.levelMultiplier ?? 0) == 0 && (g.value?.proficiencyMultiplier ?? 0) == 0 && g.value?.table == nil && g.value?.minimum == nil, "Ability caps must declare a fixed maximum from 20 to 30.")
                }
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
                try require((1...20).contains(group.counts.count) && group.counts.allSatisfy { (0...30).contains($0) }, "Invalid choice count table.")
                try require((group.replacementLimits ?? []).allSatisfy { (0...30).contains($0) } && (group.replacementLimits?.count ?? 0) <= 20, "Invalid replacement schedule.")
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
                try require((adapter.subclassLevel.map { (1...20).contains($0) } ?? true) && adapter.replacementGrants.count <= 128, "Invalid adapter bounds.")
                try require(["2014", "2024"].contains(adapter.edition) && !adapter.canonicalID.isEmpty && !adapter.label.isEmpty, "Adapter needs explicit edition, identity and label.")
                for g in adapter.replacementGrants { try grant(g) }
            }
            try require((definition.adapters?.count ?? 0) <= 2 && Set((definition.adapters ?? []).map(\.edition)).count == (definition.adapters?.count ?? 0), "Duplicate or excessive edition adapters.")
            let scopedPolicies = scope.flatMap { $0.casting ?? [] }
            let scopedPools = scope.flatMap { $0.spellPools ?? [] }
            try require((definition.spellPools?.count ?? 0) <= 32, "Too many spell pools.")
            for pool in definition.spellPools ?? [] {
                try require(identity(pool.id) && !pool.name.isEmpty && pool.name.count <= 200 && !pool.recovery.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty && pool.recovery.count <= 200, "Spell pools require identity, name and recovery.")
                try require((1...20).contains(pool.capacities.count) && pool.capacities.allSatisfy { $0.count <= 9 && $0.allSatisfy { (1...9).contains($0.key) && (0...100).contains($0.value) } }, "Invalid spell pool tier table.")
                try predicate(pool.condition)
            }
            try require(Set(scopedPolicies.map(\.id)).count == scopedPolicies.count, "Duplicate scoped casting policy identity.")
            let policies = definition.casting ?? []
            try require(policies.count <= 32 && Set(policies.map(\.id)).count == policies.count, "Invalid casting policy identities.")
            for policy in policies {
                try ruleValue(policy.preparation)
                try require(policy.preparation == nil || policy.hasEditableLoadout, "Preparation expression requires an explicit editable policy.")
                try require(policy.preparation == nil || policy.preparedCounts == nil, "Choose one preparation allowance representation.")
                let poolIDs = policy.poolIDs ?? [], additions = policy.alwaysGrantedSpellIDs ?? []
                try require(Set(poolIDs).count == poolIDs.count && Set(poolIDs).isSubset(of:Set(scopedPools.map(\.id))), "Missing or duplicate casting pool reference.")
                try require(Set(additions).count == additions.count && additions.count <= 100 && Set(additions).isSubset(of:Set(pack.spells.map(\.id))), "Missing or duplicate automatic spell.")
                try require(!policy.hasEditableLoadout || [.prepared,.book].contains(policy.mode), "Editable loadouts require prepared or book acquisition.")
                try require(policy.mode != .book || !policy.hasEditableLoadout || policy.preparedCounts != nil || policy.preparation != nil, "Editable book policy needs a preparation allowance.")
                try require(identity(policy.id) && (policy.replacementLimits?.count ?? 0) <= 20 && (policy.preparedCounts?.count ?? 0) <= 20, "Invalid casting bounds.")
                try predicate(policy.condition)
                try require((1...20).contains(policy.counts.count) && policy.counts.allSatisfy { (0...100).contains($0) }, "Invalid casting counts.")
                try require(policy.maximumSpellLevels.count == policy.counts.count && policy.maximumSpellLevels.allSatisfy { (0...9).contains($0) }, "Invalid casting spell-level table.")
                try require(Set(policy.spellIDs).count == policy.spellIDs.count && Set(policy.spellIDs).isSubset(of: Set(pack.spells.map(\.id))), "Missing or duplicate casting spell.")
                try require((policy.replacementLimits ?? []).allSatisfy { (0...100).contains($0) } && (policy.preparedCounts ?? []).allSatisfy { (0...100).contains($0) }, "Invalid casting replacement/preparation counts.")
            }
        }
    }
}
