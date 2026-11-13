import Foundation

public struct BuildIssue: Identifiable, Equatable, Sendable {
    public var code: String
    public var message: String
    public var level: Int?
    public var id: String { "\(level ?? 0):\(code)" }
}

public struct CharacterSummary: Sendable {
    public var classLevels: [ClassLevelSummary] = []
    public var hitDice: [Int:Int] = [:]
    public var spellPools: [SpellPoolSummary] = []
    public var castingSources: [CastingSourceSummary] = []
    public var languages: [String] = []
    public var size: String? = nil
    public var activeGroupIDs: Set<String> = []
    public var activePolicyIDs: Set<String> = []
    public var castingAbility: Ability? = nil
    public var proficiencyRanks: [String: ProficiencyRank] = [:]
    public var skillModifiers: [String: Int] = [:]
    public var traits: [String] = []
    public var resources: [ResourceCapacity] = []
    public var provenance: [CapabilityProvenance] = []
    public var supportDiagnostics: [String] = []
    public var spellLabels: [String: String] = [:]
    public var scores: [String: Int]
    public var proficiency: Int
    public var hitPoints: Int
    public var armorClass: Int
    public var mantleArmorClass: Int?
    public var initiative: Int
    public var speed: Int
    public var spellDC: Int?
    public var spellAttack: Int?
    public var skills: [String]
    public var features: [Feature]
    public var talents: [Talent]
    public var spells: [Spell]
    public var grantedSpellIDs: Set<String>
    public var slots: Int
    public var slotLevel: Int
    public var issues: [BuildIssue]
    public var isValid: Bool { issues.isEmpty }
}

public enum RulesEngine {
    /// Shared by replay and the editor; a legacy build never opts into an adapter implicitly.
    public static func subclassUnlockLevel(for definition: ClassDefinition, build: CharacterBuild, in pack: ContentPack) -> Int {
        guard build.rulesProfile != nil || (pack.schemaVersion == 2 && definition.capabilities != nil) else {
            return definition.subclassLevel
        }
        let edition = build.rulesProfile?.edition ?? "2024"
        return definition.capabilities?.adapters?.first { $0.edition == edition }?.subclassLevel ?? definition.subclassLevel
    }

    public static let standardArray = [15, 14, 13, 12, 10, 8]
    public static let skillAbilities: [String: Ability] = [
        "Acrobatics": .dex, "Animal Handling": .wis, "Arcana": .int, "Athletics": .str,
        "Deception": .cha, "History": .int, "Insight": .wis, "Intimidation": .cha,
        "Investigation": .int, "Medicine": .wis, "Nature": .int, "Perception": .wis,
        "Performance": .cha, "Persuasion": .cha, "Religion": .int, "Sleight of Hand": .dex,
        "Stealth": .dex, "Survival": .wis
    ]

    public static func evaluate(_ build: CharacterBuild, in pack: ContentPack, through requestedLevel: Int? = nil) -> CharacterSummary {
        if build.rulesProfile != nil || build.castingLoadouts != nil || build.levels.contains(where: { $0.classID != nil }) || (pack.schemaVersion == 2 && pack.classes.first(where: { $0.id == build.classID })?.capabilities != nil) {
            return CapabilityEngine.evaluate(build, in: pack, through: requestedLevel)
        }
        var result = evaluateLegacy(build, in: pack, through: requestedLevel)
        if pack.schemaVersion == 2 {
            let choices = Array(build.levels.prefix(max(1, requestedLevel ?? build.level)))
            let background = pack.backgrounds.first { $0.id == build.backgroundID }
            let subclass = pack.classes.first { $0.id == build.classID }?.subclasses.first { $0.id == choices.last?.subclassID }
            let definitions = [pack.species.first { $0.id == build.speciesID }?.capabilities, background?.capabilities, subclass?.capabilities].compactMap { $0 }
                + pack.feats.filter { feat in feat.id == background?.originFeatID || choices.contains { $0.featID == feat.id } }.compactMap(\.capabilities)
            if definitions.contains(where: { $0.edition != "2024" || !($0.grants ?? []).isEmpty || !($0.groups ?? []).isEmpty || !($0.casting ?? []).isEmpty || !($0.spellPools ?? []).isEmpty || !($0.configurations ?? []).isEmpty }) || choices.contains(where: { $0.capabilities != nil }) || build.castingLoadouts != nil {
                result.issues.append(.init(code: "cap-upgrade-required", message: "These selected choices require an explicit evaluator-2 review copy. Legacy rules have not been silently upgraded."))
            }
        }
        return result
    }

    static func evaluateLegacy(_ build: CharacterBuild, in pack: ContentPack, through requestedLevel: Int? = nil) -> CharacterSummary {
        let level = min(max(requestedLevel ?? build.level, 1), max(build.level, 1))
        var issues: [BuildIssue] = []
        func issue(_ code: String, _ message: String, _ at: Int? = nil) {
            issues.append(BuildIssue(code: code, message: message, level: at))
        }
        let definition = pack.classes.first { $0.id == build.classID }
        if let first=build.levels.first?.classID, first != build.classID { issue("starting-class","The starting-class identity must match level one.",1) }
        let species = pack.species.first { $0.id == build.speciesID }
        let background = pack.backgrounds.first { $0.id == build.backgroundID }
        if definition == nil { issue("class", "Choose a class from this content pack.") }
        if species == nil { issue("species", "Choose your species.") }
        if background == nil { issue("background", "Choose your background.") }
        if build.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issue("name", "Give your character a name.") }
        if build.levels.isEmpty || build.levels.enumerated().contains(where: { $0.element.level != $0.offset + 1 }) {
            issue("sequence", "Level history must start at 1 and contain no gaps.")
        }
        if build.baseScores.keys.sorted() != Ability.allCases.map(\.rawValue).sorted()
            || build.baseScores.values.sorted() != standardArray.sorted() {
            issue("array", "Assign each standard-array score once: 15, 14, 13, 12, 10, 8.")
        }
        var scores = build.baseScores
        let backgroundValues = build.backgroundBoosts.values.filter { $0 != 0 }.sorted()
        if backgroundValues != [1, 2] && backgroundValues != [1, 1, 1] {
            issue("background-boosts", "Allocate +2 and +1, or three +1s, to your background's abilities.")
        }
        for (key, value) in build.backgroundBoosts where value != 0 {
            if !((background?.abilities.map(\.rawValue) ?? []).contains(key)) || !(0...2).contains(value) {
                issue("background-ability-\(key)", "Your background cannot increase \(key.uppercased()) by \(value).")
            }
            scores[key, default: 10] += value
        }
        if build.languages.count != 2 || Set(build.languages).count != 2 || build.languages.contains(where: { !pack.languages.contains($0) || $0 == "Common" }) {
            issue("languages", "Choose two different standard languages in addition to Common.")
        }
        var skills = Set(background?.skills ?? [])
        if let definition {
            if build.classSkills.count != definition.skillCount || Set(build.classSkills).count != build.classSkills.count {
                issue("skills-count", "Choose \(definition.skillCount) different class skills.")
            }
            for skill in build.classSkills {
                if !definition.skillPool.contains(skill) { issue("skill-\(skill)", "\(skill) is not an available class skill.") }
                if skills.contains(skill) { issue("duplicate-skill-\(skill)", "Your background already grants \(skill); choose a different class skill.") }
                skills.insert(skill)
            }
        }
        var feats: [Feat] = []
        if let id = background?.originFeatID, let feat = pack.feats.first(where: { $0.id == id }) { feats.append(feat) }
        var previousByClass: [String:LevelChoice] = [:]
        var counts: [String:Int] = [:]
        var talentsByClass: [String:[Talent]] = [:]
        var subclassesByClass: [String:Subclass] = [:]
        var grantsByClass: [String:Set<String>] = [:]
        var grantedIDs = Set<String>()
        var activeTalents: [Talent] = []
        var activeSubclass: Subclass?
        for choice in build.levels.prefix(level) {
            let classID = choice.classID ?? build.classID
            counts[classID, default:0] += 1
            let classLevel = counts[classID]!
            let previous = previousByClass[classID]
            let priorClassLevel = classLevel - 1
            if choice.level > (build.rulesProfile?.evaluator == 2 ? 20 : 5) {
                issue("unsupported-level", "This evaluator does not support level \(choice.level).", choice.level); continue
            }
            guard let definition = pack.classes.first(where: { $0.id == classID }), let progression = definition.at(classLevel) else {
                issue("unsupported-level", "This pack does not support level \(choice.level).", choice.level); continue
            }
            if classLevel == 1 && choice.level > 1 {
                let picked=choice.multiclassSkills ?? [], needed=definition.multiclass?.laterSkillCount ?? 0
                if picked.count != needed || Set(picked).count != picked.count || picked.contains(where: { !definition.skillPool.contains($0) || skills.contains($0) }) { issue("multiclass-skills","Choose \(needed) new skills from \(definition.name)'s class list.",choice.level) }
                skills.formUnion(picked.filter { definition.skillPool.contains($0) })
            } else if !(choice.multiclassSkills ?? []).isEmpty { issue("multiclass-skills","Later-class skill choices belong only to that class's entry level.",choice.level) }
            if classLevel >= definition.subclassLevel {
                activeSubclass = definition.subclasses.first { $0.id == choice.subclassID }
                if activeSubclass == nil { issue("subclass", "Choose your subclass.", choice.level) }
                if let previous, priorClassLevel >= definition.subclassLevel, previous.subclassID != choice.subclassID {
                    issue("subclass-change", "Your subclass must match your earlier level choice.", choice.level)
                }
            } else {
                activeSubclass = nil
                if !choice.subclassID.isEmpty { issue("early-subclass", "Your subclass is chosen at class level \(definition.subclassLevel).", choice.level) }
            }
            subclassesByClass[classID] = activeSubclass
            grantedIDs = Set((activeSubclass?.spells ?? []).filter { $0.level <= classLevel }.flatMap(\.spellIDs))
            grantsByClass[classID] = grantedIDs
            for id in grantedIDs {
                if let spell = pack.spells.first(where: { $0.id == id }) {
                    if let reason = spell.unavailableReason { issue("unresolved-grant-\(id)", "\(spell.name): \(reason)", choice.level) }
                    if spell.level > progression.slotLevel { issue("high-grant-\(id)", "\(spell.name) exceeds your slot level; this source mapping needs review.", choice.level) }
                }
            }
            let talents = choice.talentIDs.compactMap { id in definition.talents.first { $0.id == id } }
            if talents.count != choice.talentIDs.count { issue("unknown-talent", "An option in this level is missing from the pack.", choice.level) }
            if choice.talentIDs.count != progression.talents || Set(choice.talentIDs).count != choice.talentIDs.count {
                issue("talent-count", "Choose \(progression.talents) \(definition.talentLabel.lowercased()) in total.", choice.level)
            }
            let groups = talents.map(\.exclusiveGroup).filter { !$0.isEmpty }
            if Set(groups).count != groups.count { issue("talent-exclusive", "Different versions of the same option cannot be taken together.", choice.level) }
            for talent in talents {
                if talent.minimumLevel > classLevel { issue("talent-level-\(talent.id)", "\(talent.name) requires class level \(talent.minimumLevel).", choice.level) }
                if !Set(talent.requires).isSubset(of: Set(choice.talentIDs)) { issue("talent-prereq-\(talent.id)", "\(talent.name) is missing a required option.", choice.level) }
            }
            if let previous, Set(previous.talentIDs).subtracting(choice.talentIDs).count > 1 {
                issue("talent-replacement", "You may replace at most one earlier option at a level-up.", choice.level)
            }
            activeTalents = talents
            talentsByClass[classID] = talents
            for (ids, required, cantrip) in [(choice.cantripIDs, progression.cantrips, true), (choice.spellIDs, progression.spells, false)] {
                let label = cantrip ? "cantrips" : "spells"
                if ids.count != required || Set(ids).count != ids.count { issue("\(label)-count", "Choose \(required) \(label) in total; subclass grants are additional.", choice.level) }
                for id in ids {
                    guard let spell = pack.spells.first(where: { $0.id == id }), definition.spellIDs.contains(id) else {
                        issue("missing-\(id)", "A selected spell is not on this class's spell list.", choice.level); continue
                    }
                    if let reason = spell.unavailableReason { issue("unresolved-spell-\(id)", "\(spell.name): \(reason)", choice.level) }
                    if cantrip ? spell.level != 0 : !(1...max(1, progression.slotLevel)).contains(spell.level) || progression.slotLevel == 0 {
                        issue("spell-level-\(id)", "\(spell.name) is not available at this level.", choice.level)
                    }
                    if grantedIDs.contains(id) { issue("spell-granted-\(id)", "\(spell.name) is already granted by your subclass; choose another spell.", choice.level) }
                }
            }
            if let previous {
                let removedSpells = Set(previous.spellIDs).subtracting(choice.spellIDs).subtracting(grantedIDs)
                if removedSpells.count > 1 { issue("spell-replacement", "Replace at most one previously known spell per level.", choice.level) }
                if !Set(previous.cantripIDs).isSubset(of: Set(choice.cantripIDs).union(grantedIDs)) {
                    issue("cantrip-replacement", "This MVP does not support replacing earlier cantrip choices.", choice.level)
                }
            }
            if progression.improvement {
                if let feat = pack.feats.first(where: { $0.id == choice.featID && $0.category == "general" }) {
                    if feat.minimumLevel > choice.level { issue("feat-level", "\(feat.name) requires level \(feat.minimumLevel).", choice.level) }
                    for (key, minimum) in feat.abilityMinimums where scores[key, default: 0] < minimum {
                        issue("feat-prereq-\(key)", "\(feat.name) requires \(key.uppercased()) \(minimum) before taking it.", choice.level)
                    }
                    if feats.contains(where: { $0.id == feat.id }) && !(build.rulesProfile?.evaluator == 2 && feat.repeatable == true) { issue("feat-duplicate", "\(feat.name) is already granted.", choice.level) }
                    let boosts = choice.boosts.filter { $0.value != 0 }
                    if boosts.values.reduce(0, +) != feat.abilityPoints || boosts.contains(where: { !feat.abilityOptions.map(\.rawValue).contains($0.key) || $0.value < 0 || $0.value > 2 }) {
                        issue("feat-boost", "Allocate \(feat.abilityPoints) ability points for \(feat.name).", choice.level)
                    }
                    for (key, value) in boosts { scores[key, default: 10] += value }
                    feats.append(feat)
                } else { issue("improvement", "Choose an ability-score improvement or a supported feat.", choice.level) }
            } else if !choice.featID.isEmpty || choice.boosts.values.contains(where: { $0 != 0 }) {
                issue("early-improvement", "No feat or ability improvement is granted at this level.", choice.level)
            }
            for (key, value) in scores where value > 20 || value < 1 { issue("score-cap-\(key)", "\(key.uppercased()) must be between 1 and 20.", choice.level) }
            previousByClass[classID] = choice
        }
        activeTalents = talentsByClass.keys.sorted().flatMap { talentsByClass[$0] ?? [] }
        grantedIDs = Set(grantsByClass.values.flatMap { $0 })
        for talent in activeTalents { skills.formUnion(talent.skills) }
        for feat in feats { skills.formUnion(feat.skills) }
        let proficiency = 2 + (level - 1) / 4
        let con = Ability.modifier(scores["con", default: 10])
        let dex = Ability.modifier(scores["dex", default: 10])
        let hpBonus = (species?.hpPerLevel ?? 0) + feats.reduce(0) { $0 + $1.hpPerLevel }
        let hp = Multiclassing.baseHitPoints(build, in:pack, through:level, constitution:con) + level * hpBonus
        let spellIDs = Set(previousByClass.values.flatMap { $0.cantripIDs + $0.spellIDs }).union(grantedIDs)
        var featureIDs = Set<String>()
        let classLevels = Multiclassing.classes(build, in:pack, through:level)
        let features = classLevels.flatMap { row in
            let local=(pack.classes.first { $0.id == row.id }?.features.filter { $0.level <= row.level } ?? []) + (subclassesByClass[row.id]?.features.filter { $0.level <= row.level } ?? [])
            return local.filter { featureIDs.insert($0.canonicalID ?? Multiclassing.scopedSubclassID(row.id,$0.id)).inserted }.map { feature in
                var copy=feature
                if classLevels.count > 1 { copy.id=feature.canonicalID ?? Multiclassing.scopedSubclassID(row.id,feature.id) }
                return copy
            }
        }
        let spellMod = definition?.spellAbility.map { Ability.modifier(scores[$0.rawValue, default: 10]) }
        let progression = definition?.at(level)
        return CharacterSummary(
            classLevels: classLevels, hitDice: Dictionary(classLevels.map { ($0.hitDie,$0.level) }, uniquingKeysWith:+),
            languages: ["Common"] + build.languages,
            scores: scores, proficiency: proficiency, hitPoints: hp, armorClass: 10 + dex,
            mantleArmorClass: definition?.armorFormula == "vessel-mantle" ? 10 + con + Ability.modifier(scores["cha", default: 10]) : nil,
            initiative: dex + (feats.contains { $0.initiativeProficiency } ? proficiency : 0),
            speed: species?.speed ?? 30, spellDC: spellMod.map { 8 + proficiency + $0 }, spellAttack: spellMod.map { proficiency + $0 },
            skills: skills.sorted(), features: features, talents: activeTalents,
            spells: pack.spells.filter { spellIDs.contains($0.id) }.sorted { ($0.level, $0.name) < ($1.level, $1.name) },
            grantedSpellIDs: grantedIDs, slots: progression?.slots ?? 0, slotLevel: progression?.slotLevel ?? 0, issues: issues
        )
    }

    public static func advance(_ build: CharacterBuild, in pack: ContentPack) throws -> CharacterBuild {
        try advance(build,in:pack,classID:build.levels.last?.classID ?? build.classID)
    }

    public static func advance(_ build: CharacterBuild, in pack: ContentPack, classID: String) throws -> CharacterBuild {
        let summary = evaluate(build, in: pack)
        guard summary.isValid else { throw FolioError.invalid("Resolve the current build's choices before advancing.") }
        guard build.level < (build.rulesProfile?.evaluator == 2 ? 20 : 5), let definition = pack.classes.first(where: { $0.id == classID }), Multiclassing.classLevel(classID,build:build,through:build.level) < definition.maxLevel else {
            throw FolioError.invalid("You have reached this pack's supported level limit.")
        }
        var next = build
        let explicit = pack.capabilities?.required.contains("multiclass") == true && build.rulesProfile?.evaluator == 2
        if classID != build.classID && !explicit { throw FolioError.invalid("This pinned character does not support multiclass history.") }
        var row=LevelChoice(level:build.level + 1,previous:build.levels.last { ($0.classID ?? build.classID) == classID })
        row.capabilities=try Multiclassing.nextChoices(build,in:pack,classID:classID)
        if explicit {
            for i in next.levels.indices { next.levels[i].classID = next.levels[i].classID ?? build.classID }
            row.classID=classID
        }
        next.levels.append(row)
        let issues=Multiclassing.entryIssues(next,in:pack,at:next.level,scores:summary.scores)
        guard issues.isEmpty else { throw FolioError.invalid(issues.map(\.message).joined(separator:" ")) }
        try CapabilityValidation.validateTrackOwnership(pack,classIDs:Set(next.levels.map { $0.classID ?? next.classID }))
        next.updatedAt = Date()
        return next
    }
}
