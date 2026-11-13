import Foundation

/// Source-owned rows. An empty row means no capacity; a missing row is unsupported.
/// Capacity never determines the spells a character is allowed to acquire.
public struct SpellPool: Codable, Sendable, Hashable, Identifiable {
    public enum Kind: String, Codable, Sendable { case ordinary, pact, limited, custom }
    public var id: String
    public var name: String
    public var kind: Kind
    public var recovery: String
    public var capacities: [[Int:Int]]
    public var condition: RulePredicate?
    public init(id: String, name: String, kind: Kind, recovery: String, capacities: [[Int:Int]], condition: RulePredicate? = nil) {
        self.id=id; self.name=name; self.kind=kind; self.recovery=recovery; self.capacities=capacities; self.condition=condition
    }
}

public struct SpellPoolSummary: Sendable, Hashable, Identifiable {
    public var id: String
    public var sourceID: String
    public var name: String
    public var kind: SpellPool.Kind
    public var recovery: String
    public var capacities: [Int:Int]
    public var capacityDescription: String { capacities.keys.sorted().map { "Tier \($0): \(capacities[$0]!)" }.joined(separator: " · ") }
}

public struct CastingSourceSummary: Sendable, Hashable, Identifiable {
    public var id: String
    public var sourceID: String
    public var name: String
    public var ability: Ability
    public var dc: Int
    public var attack: Int
    public var maximumSpellLevel: Int
    public var acquisitionPolicy: CastingPolicy.Mode
    public var editableLoadout: Bool
    public var preparationCount: Int
    public var poolIDs: [String]
    public var availableSpellIDs: [String]
    public var memberSpellIDs: [String]
    public var selectedLoadout: [String]
    public var spellLabels: [String:String]
}

extension CastingPolicy {
    public var hasEditableLoadout: Bool { loadout == .editable }
    public func preparationCount(at level: Int, scores: [String:Int], proficiency: Int) -> Int {
        if let preparation { return preparation.resolve(level:level,scores:scores,proficiency:proficiency) }
        let table = preparedCounts ?? (mode == .prepared ? counts : [])
        return table.indices.contains(level - 1) ? table[level - 1] : 0
    }
}

/// Projection and current configuration validation, called once after historical
/// acquisition replay and ability effects. It does not replay or alter history.
enum Spellcasting {
    static func project(build: CharacterBuild, pack: ContentPack, level: Int,
                        policies: [(String,CastingPolicy)], pools: [(String,SpellPool)], result: inout CharacterSummary) {
        func issue(_ code: String, _ message: String) { result.issues.append(.init(code:"cap-"+code,message:message,level:level)) }
        let history = build.levels[level - 1].capabilities
        let grantedLabels = result.spellLabels.mapValues { label in
            label.components(separatedBy:"; ").filter { $0 == "Granted" || $0.contains("(granted)") }
        }
        let useCurrent = level == build.level
        if useCurrent {
            for key in (build.castingLoadouts ?? [:]).keys where !policies.contains(where: { $0.1.id == key && $0.1.hasEditableLoadout }) {
                issue("loadout-"+key,"Retained or inactive casting source has a loadout. Review it without changing acquisition history.")
            }
        }
        for (owner,pool) in pools {
            guard pool.capacities.indices.contains(level - 1) else { issue("pool-row-"+pool.id,"\(pool.name) has no explicit capacity row at this level."); continue }
            result.spellPools.append(.init(id:pool.id,sourceID:owner,name:pool.name,kind:pool.kind,recovery:pool.recovery,capacities:pool.capacities[level - 1]))
        }
        var visible = Set(result.spells.map(\.id))
        for (owner,policy) in policies {
            let maximum = policy.maximumSpellLevels.indices.contains(level - 1) ? policy.maximumSpellLevels[level - 1] : 0
            let additions = policy.alwaysGrantedSpellIDs ?? []
            let available = pack.spells.filter { policy.spellIDs.contains($0.id) && $0.level <= maximum && !additions.contains($0.id) && !(policy.mode == .prepared && result.grantedSpellIDs.contains($0.id)) }.map(\.id)
            let historical = history?.spells?[policy.id] ?? []
            let members = policy.hasEditableLoadout && policy.mode == .prepared ? available : historical
            let needed = policy.preparationCount(at:level,scores:result.scores,proficiency:result.proficiency)
            var selected = policy.mode == .book ? history?.prepared?[policy.id] ?? [] : historical
            if policy.hasEditableLoadout, useCurrent, let configured = build.castingLoadouts?[policy.id] { selected = configured }
            if policy.hasEditableLoadout {
                if selected.count != needed || Set(selected).count != selected.count || !Set(selected).isSubset(of:Set(members)) || !Set(selected).isDisjoint(with:additions) {
                    issue("loadout-"+policy.id,"\(policy.name): prepare \(needed) distinct eligible spells; automatic additions do not spend this allowance.")
                }
            }
            if let table=policy.preparation?.table, !table.indices.contains(level - 1) { issue("policy-row-"+policy.id,"\(policy.name) lacks a preparation row.") }
            let shown = policy.hasEditableLoadout && policy.mode == .prepared ? selected : members
            var labels: [String:String] = [:]
            for id in shown {
                labels[id] = policy.mode == .book ? (selected.contains(id) ? "Prepared (book)" : "Spellbook") : policy.mode.rawValue.capitalized
            }
            for id in additions { labels[id] = [.book,.prepared].contains(policy.mode) ? "Always prepared (additional)" : "Always granted (additional)"; result.grantedSpellIDs.insert(id) }
            for id in shown + additions {
                visible.insert(id)
                if let reason = pack.spells.first(where: { $0.id == id })?.unavailableReason { issue("casting-source-"+id,reason) }
            }
            let mod = Ability.modifier(result.scores[policy.ability.rawValue,default:10])
            result.castingSources.append(.init(id:policy.id,sourceID:owner,name:policy.name,ability:policy.ability,dc:8+result.proficiency+mod,attack:result.proficiency+mod,maximumSpellLevel:maximum,acquisitionPolicy:policy.mode,editableLoadout:policy.hasEditableLoadout,preparationCount:needed,poolIDs:policy.poolIDs ?? [],availableSpellIDs:available,memberSpellIDs:members,selectedLoadout:selected,spellLabels:labels))
            for poolID in policy.poolIDs ?? [] where !result.spellPools.contains(where: { $0.id == poolID }) {
                issue("pool-inactive-"+poolID,"\(policy.name) references an inactive capacity source.")
            }
        }
        for id in Set(result.castingSources.flatMap { $0.spellLabels.keys }) {
            let labels=result.castingSources.compactMap { $0.spellLabels[id] } + (grantedLabels[id] ?? [])
            result.spellLabels[id]=Set(labels).sorted().joined(separator:"; ")
        }
        let abilities = Set(result.castingSources.filter { !$0.spellLabels.isEmpty }.map(\.ability))
        if abilities.count > 1 { result.castingAbility=nil; result.spellDC=nil; result.spellAttack=nil }
        else if let ability=abilities.first {
            let modifier=Ability.modifier(result.scores[ability.rawValue,default:10])
            result.castingAbility=ability; result.spellDC=8+result.proficiency+modifier; result.spellAttack=result.proficiency+modifier
        }
        result.spells = pack.spells.filter { visible.contains($0.id) }.sorted { ($0.level,$0.name,$0.id) < ($1.level,$1.name,$1.id) }
    }
}
