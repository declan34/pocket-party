import Foundation

/// Source-authored entry/exit rules. Canonical identity intentionally survives
/// source qualification, unlike the selectable definition ID.
public struct MulticlassPolicy: Codable, Sendable, Hashable {
    public var startingProficiencies: [CapabilityGrant]? = nil
    public var laterSkillCount: Int? = nil
    public var canonicalID: String
    public var prerequisites: RulePredicate?
    public var laterProficiencies: [CapabilityGrant]
    public var casting: CasterContribution?
    public init(canonicalID: String, prerequisites: RulePredicate? = nil, laterProficiencies: [CapabilityGrant] = [], casting: CasterContribution? = nil) {
        self.canonicalID=canonicalID; self.prerequisites=prerequisites; self.laterProficiencies=laterProficiencies; self.casting=casting
    }
}

public struct CasterContribution: Codable, Sendable, Hashable {
    public enum Kind: String, Codable, Sendable { case ordinary, independent, none }
    public enum Rounding: String, Codable, Sendable { case down, up }
    public var kind: Kind
    public var divisor: Int
    public var rounding: Rounding
    public var startsAt: Int
    public var poolIDs: [String]
    public var reciprocalSlotUse: Bool
    public init(kind: Kind, divisor: Int = 1, rounding: Rounding = .down, startsAt: Int = 1, poolIDs: [String] = [], reciprocalSlotUse: Bool = false) {
        self.kind=kind; self.divisor=divisor; self.rounding=rounding; self.startsAt=startsAt; self.poolIDs=poolIDs; self.reciprocalSlotUse=reciprocalSlotUse
    }
    public func contribution(at level: Int) -> Int {
        guard kind == .ordinary, level >= startsAt, divisor > 0 else { return 0 }
        return (level + (rounding == .up ? divisor - 1 : 0)) / divisor
    }
}

public struct ClassLevelSummary: Sendable, Hashable, Identifiable {
    public var features: [Feature] = []
    public var castingSourceIDs: [String] = []
    public var id: String
    public var name: String
    public var level: Int
    public var hitDie: Int
    public var subclassID: String
    public var subclassName: String
}

public enum Multiclassing {
    static func scopedSubclassID(_ classID: String, _ subclassID: String) -> String { "\(classID.utf8.count):\(classID)\(subclassID)" }
    public static func classID(at level: Int, build: CharacterBuild) -> String {
        guard build.levels.indices.contains(level - 1) else { return build.classID }
        return build.levels[level - 1].classID ?? build.classID
    }
    public static func classLevel(_ id: String, build: CharacterBuild, through level: Int) -> Int {
        build.levels.prefix(level).filter { ($0.classID ?? build.classID) == id }.count
    }
    static func nextChoices(_ build: CharacterBuild, in pack: ContentPack, classID: String) throws -> CapabilityChoices? {
        guard let latest=try replayChoices(build,in:pack).levels.last?.capabilities else { return nil }
        let selected=Set(build.levels.map { $0.classID ?? build.classID })
        let foreign=pack.classes.filter { $0.id != classID && selected.contains($0.id) }.flatMap { [$0.capabilities].compactMap { $0 } + $0.subclasses.compactMap(\.capabilities) }
        let groups=Set(foreign.flatMap { ($0.groups ?? []).map(\.id) }), policies=Set(foreign.flatMap { ($0.casting ?? []).map(\.id) }), configs=Set(foreign.flatMap { ($0.configurations ?? []).map(\.id) })
        return .init(groups:(latest.groups ?? [:]).filter { !groups.contains($0.key) },configurations:(latest.configurations ?? []).filter { !configs.contains($0) },spells:(latest.spells ?? [:]).filter { !policies.contains($0.key) },prepared:(latest.prepared ?? [:]).filter { !policies.contains($0.key) })
    }
    public static func classes(_ build: CharacterBuild, in pack: ContentPack, through level: Int? = nil) -> [ClassLevelSummary] {
        var ids = Set<String>(), result: [ClassLevelSummary] = []
        let rows = Array(build.levels.prefix(level ?? build.level))
        for row in rows {
            let id = row.classID ?? build.classID
            guard ids.insert(id).inserted, let cls = pack.classes.first(where: { $0.id == id }) else { continue }
            let own = rows.filter { ($0.classID ?? build.classID) == id }
            let subID = own.last?.subclassID ?? ""
            let sub=cls.subclasses.first { $0.id == subID }
            result.append(.init(features:cls.features.filter { $0.level <= own.count } + (sub?.features.filter { $0.level <= own.count } ?? []),id:id,name:cls.name,level:own.count,hitDie:cls.hitDie,subclassID:subID,subclassName:sub?.name ?? ""))
        }
        return result
    }
    static func baseHitPoints(_ build: CharacterBuild, in pack: ContentPack, through level: Int, constitution: Int) -> Int {
        build.levels.prefix(level).enumerated().reduce(0) { total, pair in
            let die = pack.classes.first { $0.id == (pair.element.classID ?? build.classID) }?.hitDie ?? 8
            return total + max(1, (pair.offset == 0 ? die : die / 2 + 1) + constitution)
        }
    }

    /// Historical rows contain the advancing class's tracks. Other classes retain
    /// their last acquisition choices; common species/background tracks stay global.
    static func replayChoices(_ build: CharacterBuild, in pack: ContentPack) throws -> CharacterBuild {
        let selected=Set(build.levels.map { $0.classID ?? build.classID })
        guard selected.count > 1 else { return build }
        try CapabilityValidation.validateTrackOwnership(pack,classIDs:selected)
        let owners = pack.classes.filter { selected.contains($0.id) }.flatMap { cls in
            ([cls.capabilities].compactMap { $0 } + cls.subclasses.compactMap(\.capabilities)).map { (cls.id,$0) }
        }
        let groupOwners = Dictionary(uniqueKeysWithValues:owners.flatMap { owner,data in (data.groups ?? []).map { ($0.id,owner) } })
        let policyOwners = Dictionary(uniqueKeysWithValues:owners.flatMap { owner,data in (data.casting ?? []).map { ($0.id,owner) } })
        let configOwners = Dictionary(uniqueKeysWithValues:owners.flatMap { owner,data in (data.configurations ?? []).map { ($0.id,owner) } })
        var result=build, groups:[String:[String]]=[:], spells:[String:[String]]=[:], prepared:[String:[String]]=[:], configs=Set<String>()
        for index in build.levels.indices {
            let row=build.levels[index], id=row.classID ?? build.classID, choices=row.capabilities ?? .init()
            func merge(_ old: inout [String:[String]], _ new: [String:[String]], owners: [String:String]) {
                old = old.filter { owners[$0.key] != nil && owners[$0.key] != id }
                for (key,value) in new { old[key]=value }
            }
            merge(&groups,choices.groups ?? [:],owners:groupOwners)
            merge(&spells,choices.spells ?? [:],owners:policyOwners)
            merge(&prepared,choices.prepared ?? [:],owners:policyOwners)
            configs = Set(configs.filter { configOwners[$0] != nil && configOwners[$0] != id }).union(choices.configurations ?? [])
            result.levels[index].capabilities = .init(groups:groups,configurations:configs.sorted(),spells:spells,prepared:prepared)
        }
        return result
    }

    /// Expand authored class-local tables onto the chronological replay timeline.
    /// This is a context projection, not a second evaluator: shared scores, PB,
    /// ownership and historical prerequisite checks remain in CapabilityEngine.
    public static func timeline(_ data: DefinitionCapabilities, owner: String, build: CharacterBuild) -> DefinitionCapabilities {
        let levels=build.levels.map { classLevel(owner,build:build,through:$0.level) }
        func unlock(_ local: Int) -> Int { (levels.firstIndex { $0 >= local }).map { $0 + 1 } ?? 21 }
        func table<T>(_ rows: [T], zero: T, replacements: Bool = false) -> [T] {
            var result:[T]=[]
            for (i,level) in levels.enumerated() {
                if level == 0 { result.append(zero); continue }
                guard rows.indices.contains(level - 1) else { break }
                result.append(replacements && classID(at:i + 1,build:build) != owner ? zero : rows[level - 1])
            }
            return result
        }
        func predicate(_ input: RulePredicate?) -> RulePredicate? {
            guard var p=input else { return nil }
            if p.kind == .level { p.minimum=unlock(p.minimum ?? 1) }
            if p.kind == .subclass, let key=p.key { p.key=scopedSubclassID(owner,key) }
            p.children=p.children?.compactMap(predicate); return p
        }
        func value(_ input: RuleValue?) -> RuleValue? {
            guard var v=input else { return nil }
            if let rows=v.table { v.table=table(rows,zero:0) }
            if let multiplier=v.levelMultiplier, multiplier != 0 {
                let rows=v.table ?? Array(repeating:0,count:levels.count)
                v.table=rows.enumerated().map { $0.element + levels[$0.offset] * multiplier }; v.levelMultiplier=0
            }
            return v
        }
        func grant(_ input: CapabilityGrant) -> CapabilityGrant {
            var g=input; g.level=unlock(g.level ?? 1); g.condition=predicate(g.condition); g.value=value(g.value); return g
        }
        var d=data
        d.grants=d.grants?.map(grant)
        d.adapters=d.adapters?.map { var a=$0; a.replacementGrants=a.replacementGrants.map(grant); return a }
        d.groups=d.groups?.map { input in
            var g=input; g.counts=table(g.counts,zero:0); g.replacementLimits=g.replacementLimits.map { table($0,zero:0,replacements:true) }; g.condition=predicate(g.condition)
            g.options=g.options.map { var o=$0; o.prerequisite=predicate(o.prerequisite); o.grants=o.grants.map(grant); return o }; return g
        }
        d.configurations=d.configurations?.map { var c=$0; c.prerequisite=predicate(c.prerequisite); return c }
        d.casting=d.casting?.map { input in
            var p=input; p.counts=table(p.counts,zero:0); p.maximumSpellLevels=table(p.maximumSpellLevels,zero:0)
            p.replacementLimits=p.replacementLimits.map { table($0,zero:0,replacements:true) }; p.preparedCounts=p.preparedCounts.map { table($0,zero:0) }
            p.preparation=value(p.preparation); p.condition=predicate(p.condition); return p
        }
        d.spellPools=d.spellPools?.map { var p=$0; p.capacities=table(p.capacities,zero:[:]); p.condition=predicate(p.condition); return p }
        return d
    }

    static func entryIssues(_ build: CharacterBuild, in pack: ContentPack, at level: Int, scores: [String:Int]) -> [BuildIssue] {
        let id=classID(at:level,build:build)
        guard level > 1, !build.levels.prefix(level - 1).contains(where: { ($0.classID ?? build.classID) == id }) else { return [] }
        var issues:[BuildIssue]=[]
        func issue(_ code: String,_ message: String) { issues.append(.init(code:"multiclass-"+code,message:message,level:level)) }
        let ids=Set(build.levels.prefix(level).map { $0.classID ?? build.classID })
        var canonical=Set<String>()
        func meets(_ p: RulePredicate?) -> Bool {
            guard let p else { return true }
            switch p.kind {
            case .ability: return scores[p.key ?? "",default:0] >= (p.minimum ?? 13)
            case .all: return (p.children ?? []).allSatisfy { meets($0) }
            case .any: return (p.children ?? []).contains { meets($0) }
            default: return false
            }
        }
        for id in ids.sorted() {
            guard let cls=pack.classes.first(where: { $0.id == id }), let policy=cls.multiclass else { issue("policy-"+id,"This class has no explicit multiclass entry policy."); continue }
            if !canonical.insert(policy.canonicalID).inserted { issue("canonical-"+policy.canonicalID,"Two versions of the same canonical class cannot be combined.") }
            if !meets(policy.prerequisites) { issue("prerequisite-"+id,"\(cls.name) entry/exit ability prerequisites were not met before this level.") }
        }
        return issues
    }

    // SRD 5.2.1 pp.24–26 / SRD 5.1 pp.56–58, Multiclass Spellcaster table.
    static let ordinaryRows: [[Int]] = [
        [2],[3],[4,2],[4,3],[4,3,2],[4,3,3],[4,3,3,1],[4,3,3,2],
        [4,3,3,3,1],[4,3,3,3,2],[4,3,3,3,2,1],[4,3,3,3,2,1],
        [4,3,3,3,2,1,1],[4,3,3,3,2,1,1],[4,3,3,3,2,1,1,1],
        [4,3,3,3,2,1,1,1],[4,3,3,3,2,1,1,1,1],[4,3,3,3,3,1,1,1,1],
        [4,3,3,3,3,2,1,1,1],[4,3,3,3,3,2,2,1,1]
    ]
    static func composePools(_ build: CharacterBuild, in pack: ContentPack, level: Int, result: inout CharacterSummary) {
        guard result.classLevels.count > 1 else { return }
        var ordinary: [(ClassLevelSummary,CasterContribution)] = []
        for row in result.classLevels {
            guard let cls=pack.classes.first(where: { $0.id == row.id }) else { continue }
            let hasCasting=cls.spellAbility != nil || !(cls.capabilities?.casting ?? []).isEmpty || !(cls.capabilities?.spellPools ?? []).isEmpty || cls.subclasses.contains { $0.id == row.subclassID && (!($0.capabilities?.casting ?? []).isEmpty || !($0.capabilities?.spellPools ?? []).isEmpty) }
            guard let policy=cls.multiclass?.casting else {
                if hasCasting { result.issues.append(.init(code:"multiclass-casting-"+row.id,message:"\(row.name) needs an explicit multiclass caster contribution policy.",level:level)) }
                continue
            }
            if policy.reciprocalSlotUse { result.traits.append("\(row.name): reciprocal spell-slot use is permitted; access and pool recovery remain separate.") }
            if policy.kind == .ordinary && row.level >= policy.startsAt && policy.poolIDs.contains(where: { id in result.spellPools.contains { $0.id == id } }) { ordinary.append((row,policy)) }
        }
        // Martial + one caster retains its own table, even a fractional caster.
        guard ordinary.count > 1 else { return }
        let casterLevel=ordinary.reduce(0) { $0 + $1.1.contribution(at:$1.0.level) }
        let replaced=Set(ordinary.flatMap { $0.1.poolIDs })
        var id="multiclass:ordinary"; while result.spellPools.contains(where: { $0.id == id }) { id += ":shared" }
        let capacities = casterLevel > 0 && ordinaryRows.indices.contains(casterLevel-1) ? Dictionary(uniqueKeysWithValues:ordinaryRows[casterLevel-1].enumerated().map { ($0.offset+1,$0.element) }) : [:]
        result.spellPools.removeAll { replaced.contains($0.id) }
        result.spellPools.insert(.init(id:id,sourceID:build.classID,name:"Shared Spellcasting",kind:.ordinary,recovery:"long rest",capacities:capacities),at:0)
        for i in result.castingSources.indices {
            if !Set(result.castingSources[i].poolIDs).isDisjoint(with:replaced) {
                result.castingSources[i].poolIDs = [id] + result.castingSources[i].poolIDs.filter { !replaced.contains($0) }
            }
        }
    }
}
