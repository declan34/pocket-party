import Foundation

public enum CapabilityEngine {
    public static func compatible(_ definition: DefinitionCapabilities?, edition: String, fallback: String) -> Bool {
        (definition?.edition ?? fallback) == edition || definition?.adapters?.contains(where: { $0.edition == edition }) == true
    }

    public static func evaluate(_ savedBuild: CharacterBuild, in pack: ContentPack, through requested: Int? = nil) -> CharacterSummary {
        let build: CharacterBuild
        do {
            try PackValidator.validateRecord(.init(pack: pack, build: savedBuild))
            build = try Multiclassing.replayChoices(savedBuild, in:pack)
        }
        catch {
            return CharacterSummary(scores: [:], proficiency: 0, hitPoints: 0, armorClass: 0, mantleArmorClass: nil, initiative: 0, speed: 0, spellDC: nil, spellAttack: nil, skills: [], features: [], talents: [], spells: [], grantedSpellIDs: [], slots: 0, slotLevel: 0, issues: [.init(code: "cap-invalid-content", message: error.localizedDescription)])
        }
        let level = min(max(requested ?? build.level, 1), max(build.level, 1))
        let edition = build.rulesProfile?.edition ?? "2024"
        var basePack = pack, baseBuild = build
        let cls = pack.classes.first { $0.id == build.classID }
        let classRows = Multiclassing.classes(build,in:pack,through:level)
        let species = pack.species.first { $0.id == build.speciesID }
        let background = pack.backgrounds.first { $0.id == build.backgroundID }
        // Ownership is pinned on each policy, never inferred from the combined
        // pack's union of required capabilities. Absence retains old semantics.
        // Reuse the stable creation/HP/ASI validator with capability-owned tracks disabled.
        for index in basePack.classes.indices where classRows.contains(where: { $0.id == basePack.classes[index].id }) {
            let cls = basePack.classes[index]
            let currentSubclass = cls.subclasses.first { $0.id == classRows.first(where: { $0.id == cls.id })?.subclassID }
            let replacesLegacyCasting = !(cls.capabilities?.casting ?? []).isEmpty || (currentSubclass?.capabilities?.casting ?? []).contains { $0.legacyClassCasting != .preserve }
            basePack.classes[index].subclassLevel = RulesEngine.subclassUnlockLevel(for: basePack.classes[index], build: build, in: pack)
            let hasGroups = !(cls.capabilities?.groups ?? []).isEmpty
            for i in basePack.classes[index].progression.indices {
                if hasGroups { basePack.classes[index].progression[i].talents = 0 }
                if replacesLegacyCasting { basePack.classes[index].progression[i].spells = 0; basePack.classes[index].progression[i].cantrips = 0 }
            }
            for i in baseBuild.levels.indices where (baseBuild.levels[i].classID ?? build.classID) == cls.id {
                if hasGroups { baseBuild.levels[i].talentIDs = [] }
                if replacesLegacyCasting { baseBuild.levels[i].spellIDs = []; baseBuild.levels[i].cantripIDs = [] }
            }
        }
        if edition == "2014" {
            baseBuild.backgroundBoosts = [:]
            for i in basePack.backgrounds.indices { basePack.backgrounds[i].originFeatID = "" }
        }
        var result = RulesEngine.evaluateLegacy(baseBuild, in: basePack, through: level)
        // Replay these below against historical capability-adjusted, pre-choice scores.
        // All other feat checks (level, duplication, allocation) remain legacy-owned.
        result.issues.removeAll { $0.code.hasPrefix("feat-prereq-") || $0.code.hasPrefix("score-cap-") }
        if edition == "2014" {
            result.issues.removeAll { $0.code.hasPrefix("background-boosts") || $0.code == "languages" }
            result.languages = []
        }
        // A grant gives access, not permission to spend a slot of insufficient level.
        result.issues.removeAll { $0.code.hasPrefix("high-grant-") }
        func issue(_ code: String, _ message: String, _ at: Int? = nil) { result.issues.append(.init(code: "cap-" + code, message: message, level: at)) }
        if build.rulesProfile?.evaluator != 2 || !["2014", "2024"].contains(edition) { issue("profile", "Choose an explicit supported rules profile (evaluator 2).") }
        if level > 20 { issue("level", "Capability evaluator 2 supports levels 1–20.") }
        if edition == "2014" && build.backgroundBoosts.values.contains(where: { $0 != 0 }) { issue("creation", "2014 does not use 2024 background ability bonuses.") }
        if edition == "2014" && !build.languages.isEmpty { issue("creation-languages", "2014 languages come from authored grants and choices. Clear retained 2024 standard-language selections after reviewing them.") }
        for message in build.upgradeReview ?? [] { issue("upgrade-\(message)", message) }
        let chosenFeats = pack.feats.filter { feat in build.levels.prefix(level).contains { $0.featID == feat.id } || (edition == "2024" && background?.originFeatID == feat.id) }
        var definitions: [(String, DefinitionCapabilities)] = []
        var unlocks: [String:Int] = [:]
        var featOwners: [String:String] = [:]
        for (id, data) in [(species?.id, species?.capabilities), (background?.id, background?.capabilities)] {
            guard let id else { continue }
            if !compatible(data, edition: edition, fallback: pack.ruleset) { issue("edition-\(id)", "This definition requires an explicit \(edition) adapter.") }
            if let data { definitions.append((id, data)) }
        }
        for row in classRows {
            guard let definition=pack.classes.first(where: { $0.id == row.id }) else { continue }
            if !compatible(definition.capabilities,edition:edition,fallback:pack.ruleset) { issue("edition-"+row.id,"This class requires an explicit \(edition) adapter.") }
            let entry=build.levels.first { ($0.classID ?? build.classID) == row.id }?.level ?? 1
            if var data=definition.capabilities {
                let training=entry > 1 ? definition.multiclass?.laterProficiencies ?? [] : definition.multiclass?.startingProficiencies ?? []
                data.grants = (data.grants ?? []) + training
                data.adapters=data.adapters?.map { var adapter=$0; adapter.replacementGrants += training; return adapter }
                definitions.append((row.id,Multiclassing.timeline(data,owner:row.id,build:build))); unlocks[row.id]=entry
            }
            if let sub=definition.subclasses.first(where: { $0.id == row.subclassID }), let data=sub.capabilities {
                let owner=row.id+":"+sub.id
                definitions.append((owner,Multiclassing.timeline(data,owner:row.id,build:build)))
                let local=RulesEngine.subclassUnlockLevel(for:definition,build:build,in:pack)
                unlocks[owner]=build.levels.first { Multiclassing.classLevel(row.id,build:build,through:$0.level) >= local }?.level ?? 21
                if !compatible(data,edition:edition,fallback:pack.ruleset) { issue("edition-"+sub.id,"This subclass requires an explicit rules-edition adapter.") }
            }
        }
        for feat in chosenFeats {
            if !compatible(feat.capabilities, edition: edition, fallback: pack.ruleset) { issue("edition-\(feat.id)", "The selected feat is incompatible with the rules profile.") }
            if let data = feat.capabilities { definitions.append((feat.id, data)) }
            unlocks[feat.id] = background?.originFeatID == feat.id ? 1 : (build.levels.first { $0.featID == feat.id }?.level ?? 1)
            featOwners[feat.id] = feat.id
            if feat.repeatable == true, let data = feat.capabilities {
                for acquisition in build.levels.prefix(level).filter({ $0.featID == feat.id }).dropFirst() {
                    let owner = feat.id + "@" + String(acquisition.level)
                    var repeated = DefinitionCapabilities(edition:data.edition)
                    repeated.grants = (data.grants ?? []).map { grant in var copy=grant; copy.id += "@" + String(acquisition.level); return copy }
                    repeated.adapters = (data.adapters ?? []).map { adapter in
                        var copy=adapter; copy.canonicalID += "@" + String(acquisition.level)
                        copy.replacementGrants = adapter.replacementGrants.map { grant in var value=grant; value.id += "@" + String(acquisition.level); return value }
                        return copy
                    }
                    definitions.append((owner,repeated)); unlocks[owner]=acquisition.level; featOwners[owner]=feat.id
                }
            }
        }
        let groups = definitions.flatMap { $0.1.groups ?? [] }
        typealias ExclusiveOwner = (id: String, track: String, exception: Bool)
        func exclusiveConflict(_ option: CapabilityOption, in group: CapabilityChoiceGroup, owners: [String: [ExclusiveOwner]], ignoringSameID: Bool) -> Bool {
            guard let family = option.exclusiveGroup, !family.isEmpty else { return false }
            let exception = group.exclusiveGroupExceptions?.contains(family) == true
            return (owners[family] ?? []).contains { owner in
                if owner.id == option.id { return !ignoringSameID }
                return owner.track == group.id || (!exception && !owner.exception)
            }
        }
        func registerExclusive(_ option: CapabilityOption, in group: CapabilityChoiceGroup, owners: inout [String: [ExclusiveOwner]]) {
            guard let family = option.exclusiveGroup, !family.isEmpty else { return }
            owners[family, default: []].append((option.id, group.id, group.exclusiveGroupExceptions?.contains(family) == true))
        }
        var canonicalDefinitions = Set<String>()
        for (id, data) in definitions {
            let canonical = data.edition == edition ? id : data.adapters?.first { $0.edition == edition }?.canonicalID ?? id
            if !canonicalDefinitions.insert(canonical).inserted { issue("canonical-\(canonical)", "The same adapted canonical definition cannot be selected twice.") }
        }
        let policies = definitions.flatMap { $0.1.casting ?? [] }
        let groupUnlocks = Dictionary(definitions.flatMap { owner, data in (data.groups ?? []).map { ($0.id, unlocks[owner] ?? 1) } }, uniquingKeysWith: max)
        let policyUnlocks = Dictionary(definitions.flatMap { owner, data in (data.casting ?? []).map { ($0.id, unlocks[owner] ?? 1) } }, uniquingKeysWith: max)
        let configIDs = Set(definitions.flatMap { ($0.1.configurations ?? []).map(\.id) })
        var finalGrants: [(String, CapabilityGrant)] = []
        var finalScores = result.scores
        var finalScoreProvenance: [CapabilityProvenance] = []
        var finalSelections = Set<String>()
        var previousGroups: [String:[String]] = [:], previousSpells: [String:[String]] = [:]
        var finalConfig = Set<String>()
        var spellIDs = Set(result.spells.map(\.id))
        var ranks = Dictionary(uniqueKeysWithValues: result.skills.map { ($0, ProficiencyRank.proficient) })
        var priorProficiencyRanks: [String:ProficiencyRank] = [:]
        var prerequisiteScores = result.scores
        var castingAbility = cls?.spellAbility
        func proficiencyTargets(_ target: String?) -> [String] {
            if target == "all-skills" { return Array(RulesEngine.skillAbilities.keys) }
            if target == "all-saves" { return Ability.allCases.map { "save." + $0.rawValue } }
            return [target ?? ""]
        }

        func matches(_ predicate: RulePredicate?, at: Int, selections: Set<String>, config: Set<String>, subclass: String) -> Bool {
            guard let p = predicate else { return true }
            switch p.kind {
            case .all: return (p.children ?? []).allSatisfy { matches($0, at: at, selections: selections, config: config, subclass: subclass) }
            case .any: return (p.children ?? []).contains { matches($0, at: at, selections: selections, config: config, subclass: subclass) }
            case .not: return p.children?.count == 1 && !matches(p.children?.first, at: at, selections: selections, config: config, subclass: subclass)
            case .level: return at >= (p.minimum ?? 1)
            case .ability: return prerequisiteScores[p.key ?? "", default: 0] >= (p.minimum ?? 0)
            case .selection: return selections.contains(p.key ?? "")
            case .configuration: return config.contains(p.key ?? "")
            case .subclass: return Multiclassing.classes(build,in:pack,through:at).contains { row in
                guard row.subclassID == p.key || Multiclassing.scopedSubclassID(row.id,row.subclassID) == p.key, let definition=pack.classes.first(where: { $0.id == row.id }) else { return false }
                return row.level >= RulesEngine.subclassUnlockLevel(for:definition,build:build,in:pack)
            }
            case .proficiency: return (ranks[p.key ?? ""] ?? .none).bonus(result.proficiency) >= result.proficiency
            }
        }
        for choice in build.levels.prefix(level) {
            let at = choice.level, selected = choice.capabilities?.groups ?? [:]
            if at > 1 { result.issues += Multiclassing.entryIssues(build,in:pack,at:at,scores:finalScores) }
            if at > 1 && Multiclassing.classLevel(choice.classID ?? build.classID,build:build,through:at) == 1 {
                for skill in choice.multiclassSkills ?? [] where priorProficiencyRanks[skill] == .proficient || priorProficiencyRanks[skill] == .expertise {
                    issue("multiclass-skill-"+skill,"\(skill) was already proficient before entering this class; choose a new class skill.",at)
                }
            }
            let raw=savedBuild.levels[at-1].capabilities
            let rawIDs=Set((raw?.groups ?? [:]).keys).union((raw?.spells ?? [:]).keys).union((raw?.prepared ?? [:]).keys).union(raw?.configurations ?? [])
            let foreign=pack.classes.filter { definition in definition.id != (choice.classID ?? build.classID) && classRows.contains { $0.id == definition.id } }.flatMap { [$0.capabilities].compactMap { $0 } + $0.subclasses.compactMap(\.capabilities) }
            let foreignIDs=Set(foreign.flatMap { ($0.groups ?? []).map(\.id) + ($0.casting ?? []).map(\.id) + ($0.configurations ?? []).map(\.id) })
            if !rawIDs.isDisjoint(with:foreignIDs) { issue("foreign-choice","This row retains choices owned by another class. Edit that class's own level or clear these retained choices.",at) }
            var beforeChoice = baseBuild
            beforeChoice.levels[at - 1].boosts = [:]
            let beforeChoiceSummary = RulesEngine.evaluateLegacy(beforeChoice, in: basePack, through: at)
            prerequisiteScores = beforeChoiceSummary.scores
            ranks = Dictionary(uniqueKeysWithValues: beforeChoiceSummary.skills.map { ($0, ProficiencyRank.proficient) })
            for ability in cls?.saves ?? [] { ranks["save." + ability.rawValue] = .proficient }
            let baselineRanks = ranks
            var config = Set(choice.capabilities?.configurations ?? [])
            if !config.isSubset(of: configIDs) { issue("configuration", "Unknown configuration value.", at) }
            if !Set(selected.keys).isSubset(of: Set(groups.map(\.id))) { issue("group", "Unknown choice track.", at) }
            let selectionSet = Set(selected.values.flatMap { $0 })
            let configurations = definitions.flatMap { $0.1.configurations ?? [] }
            let exclusiveConfigs = Dictionary(grouping: configurations.filter { config.contains($0.id) && $0.exclusiveGroup != nil }, by: { $0.exclusiveGroup! })
            for (key, conflicts) in exclusiveConfigs where conflicts.count > 1 {
                issue("configuration-exclusive-\(key)", "Choose only one configuration in \(key).", at)
                config.subtract(conflicts.map(\.id))
            }
            for _ in 0...configurations.count {
                var next = config
                for configured in configurations where config.contains(configured.id) {
                    if !matches(configured.prerequisite, at: at, selections: selectionSet, config: config, subclass: choice.subclassID) {
                        next.remove(configured.id); issue("configuration-\(configured.id)", "\(configured.name) is missing its required configuration or prerequisite.", at)
                    }
                }
                if next == config { break }; config = next
            }
            let policyIDs = Set(policies.map(\.id))
            if !Set((choice.capabilities?.spells ?? [:]).keys).isSubset(of: policyIDs) || !Set((choice.capabilities?.prepared ?? [:]).keys).isSubset(of: policyIDs) { issue("casting-policy", "Unknown casting policy.", at) }
            var grants: [(String, CapabilityGrant)] = []
            for (owner, data) in definitions {
                guard at >= unlocks[owner, default: 1] else { continue }
                let ownGrants = data.edition == edition ? data.grants ?? [] : data.adapters?.first { $0.edition == edition }?.replacementGrants ?? []
                grants += ownGrants.filter { ($0.level ?? 1) <= at }.map { (owner, $0) }
            }
            let beforeGrantScores = prerequisiteScores
            var scoreGrants = Set<String>()
            let priorOptionGrants = finalGrants.filter { selectionSet.contains($0.0) }
            for (owner, grant) in grants + priorOptionGrants where grant.kind == .abilityScore && !(featOwners[owner] == choice.featID && unlocks[owner] == at) {
                guard matches(grant.condition, at: at, selections: selectionSet, config: config, subclass: choice.subclassID), scoreGrants.insert(grant.id).inserted else { continue }
                prerequisiteScores[grant.target ?? "", default: 10] += grant.value?.resolve(level: at, scores: beforeGrantScores, proficiency: beforeChoiceSummary.proficiency) ?? 0
            }
            let advancingID=choice.classID ?? build.classID
            let advancingClass=pack.classes.first { $0.id == advancingID }
            if advancingClass?.at(Multiclassing.classLevel(advancingID,build:build,through:at))?.improvement == true,
               let feat = pack.feats.first(where: { $0.id == choice.featID && $0.category == "general" }) {
                for (key, minimum) in feat.abilityMinimums where prerequisiteScores[key, default: 0] < minimum {
                    result.issues.append(.init(code: "feat-prereq-\(key)", message: "\(feat.name) requires \(key.uppercased()) \(minimum) before taking it.", level: at))
                }
            }
            // Grow from grounded prerequisites: a choice cannot fund itself or a cycle.
            var eligibleSelections = Set<String>()
            let allOptions = groups.flatMap(\.options)
            func deriveRanks(_ candidates: [(String, CapabilityGrant)], selections: Set<String>) {
                for (_, grant) in candidates where grant.kind == .proficiency && matches(grant.condition, at: at, selections: selections, config: config, subclass: choice.subclassID) {
                    let targets = proficiencyTargets(grant.target)
                    for target in targets { if let rank = grant.rank, rank.bonus(result.proficiency) > (ranks[target] ?? .none).bonus(result.proficiency) { ranks[target] = rank } }
                }
            }
            deriveRanks(grants, selections: [])
            var rejectedSelections = Set<String>()
            var settled = false
            for _ in 0..<max(4, allOptions.count * 4) {
                let candidates = Set(selectionSet.subtracting(rejectedSelections).filter { id in
                    guard let option = allOptions.first(where: { $0.id == id }) else { return false }
                    return groups.contains { group in at >= groupUnlocks[group.id, default: 1] && (selected[group.id] ?? []).contains(id) && matches(group.condition, at: at, selections: eligibleSelections, config: config, subclass: choice.subclassID) }
                        && matches(option.prerequisite, at: at, selections: eligibleSelections, config: config, subclass: choice.subclassID)
                })
                // Resolve ownership before allowing an option to supply prerequisites.
                var next = Set<String>(), exclusiveOwners: [String: [ExclusiveOwner]] = [:]
                for group in groups where at >= groupUnlocks[group.id, default: 1] && matches(group.condition, at: at, selections: eligibleSelections, config: config, subclass: choice.subclassID) {
                    for id in selected[group.id] ?? [] where candidates.contains(id) {
                        guard let option = group.options.first(where: { $0.id == id }) else { continue }
                        if exclusiveConflict(option, in: group, owners: exclusiveOwners, ignoringSameID: true) { continue }
                        registerExclusive(option, in: group, owners: &exclusiveOwners)
                        next.insert(id)
                    }
                }
                let removed = eligibleSelections.subtracting(next)
                let rejected = candidates.subtracting(next)
                // A shrinking dependency set invalidates all provisional ranks. Restart
                // grounded replay without rejected roots so descendants cannot self-fund.
                if !removed.isEmpty || !rejected.isEmpty {
                    rejectedSelections.formUnion(removed.union(rejected))
                    eligibleSelections = []
                    ranks = baselineRanks; deriveRanks(grants, selections: [])
                    continue
                }
                let priorRanks = ranks
                ranks = baselineRanks
                deriveRanks(grants, selections: next)
                deriveRanks(allOptions.filter { next.contains($0.id) }.flatMap { $0.grants.filter { ($0.level ?? 1) <= at }.map { ("", $0) } }, selections: next)
                if next == eligibleSelections && ranks == priorRanks { settled = true; break }
                eligibleSelections = next
            }
            if !settled { eligibleSelections = []; ranks = baselineRanks; issue("dependency-resolution", "Capability dependencies did not settle within the bounded replay budget.", at) }
            var owned: Set<String> = [], exclusives: [String: [ExclusiveOwner]] = [:]
            for group in groups {
                let active = at >= groupUnlocks[group.id, default: 1] && matches(group.condition, at: at, selections: eligibleSelections, config: config, subclass: choice.subclassID)
                if at == level && active { result.activeGroupIDs.insert(group.id) }
                if active && (!group.counts.indices.contains(at - 1) || (group.replacementLimits.map { !$0.indices.contains(at - 1) } ?? false)) { issue("group-row-\(group.id)", "\(group.name) has no explicit row for this level.", at) }
                let ids = selected[group.id] ?? []
                if ids.count != (active ? group.count(at: at) : 0) { issue("count-\(group.id)", "Choose \(active ? group.count(at: at) : 0) for \(group.name).", at) }
                let checkRequirement = group.requirementTiming != .acquisition || (previousGroups[group.id] ?? []).isEmpty
                if active, checkRequirement, group.count(at: at) > 0, let mandatory = group.requiredOptionID,
                   !selected.contains(where: { $0.key != group.id && $0.value.contains(mandatory) }), !ids.contains(mandatory) {
                    issue("required-\(group.id)", "\(group.name) must grant its required option unless another track already owns it.", at)
                }
                let familyOwnedElsewhere = group.waiveRequiredFamilyIfOwned == true && selected.contains { entry in
                    entry.key != group.id && entry.value.contains { eligibleSelections.contains($0) && (group.requiredOptionIDs ?? []).contains($0) }
                }
                if active, checkRequirement, group.count(at: at) > 0, let family = group.requiredOptionIDs, !familyOwnedElsewhere, Set(ids).isDisjoint(with: family) {
                    issue("required-family-\(group.id)", "\(group.name) requires a choice from its mandatory family.", at)
                }
                var remaining = Dictionary(ids.map { ($0, 1) }, uniquingKeysWith: +)
                let removed = (previousGroups[group.id] ?? []).filter { id in
                    guard remaining[id, default: 0] > 0 else { return true }
                    remaining[id, default: 0] -= 1
                    return false
                }
                let replacements = group.replacementLimits.flatMap { $0.indices.contains(at - 1) ? $0[at - 1] : nil } ?? 0
                if !removed.isEmpty && (group.locked == true || removed.count > replacements) { issue("replacement-\(group.id)", "\(group.name) permits \(group.locked == true ? 0 : replacements) replacements here.", at) }
                for (occurrence, id) in ids.enumerated() {
                    guard let option = group.options.first(where: { $0.id == id }) else { issue("option-\(id)", "Unknown option in \(group.name).", at); continue }
                    guard active else { continue }
                    let legal = eligibleSelections.contains(id)
                    if !legal { issue("prerequisite-\(id)", "\(option.name) is missing a prerequisite.", at); continue }
                    if owned.contains(id) && option.repeatable != true { issue("duplicate-\(id)", "\(option.name) is already owned, including bonus tracks.", at); continue }
                    if exclusiveConflict(option, in: group, owners: exclusives, ignoringSameID: false) { issue("exclusive-\(id)", "Conflicting versions of \(option.name).", at); continue }
                    registerExclusive(option, in: group, owners: &exclusives)
                    owned.insert(id)
                    grants += option.grants.filter { ($0.level ?? 1) <= at }.map { grant in
                        var grant = grant
                        if option.repeatable == true { grant.id += "@\(group.id):\(occurrence)" }
                        return (id, grant)
                    }
                }
            }
            // Automatic grants merge, including later conditional grants of a learned
            // language. Only distinct choice slots may not spend picks on duplicates.
            var chosenLanguages = Set(edition == "2024" ? build.languages : [])
            for group in groups where group.languageChoices == true && at >= groupUnlocks[group.id, default: 1] && matches(group.condition, at: at, selections: eligibleSelections, config: config, subclass: choice.subclassID) {
                for id in selected[group.id] ?? [] where owned.contains(id) {
                    guard let option = group.options.first(where: { $0.id == id }) else { continue }
                    let languages = Set(option.grants.filter {
                        $0.kind == .language && ($0.level ?? 1) <= at && matches($0.condition, at: at, selections: eligibleSelections, config: config, subclass: choice.subclassID)
                    }.compactMap(\.target))
                    for language in languages where !chosenLanguages.insert(language).inserted {
                        issue("language-duplicate-\(language)", "Choose different languages; \(language) already occupies another language choice.", at)
                    }
                }
            }
            for policy in policies {
                let active = at >= policyUnlocks[policy.id, default: 1] && matches(policy.condition, at: at, selections: eligibleSelections, config: config, subclass: choice.subclassID)
                if at == level && active { result.activePolicyIDs.insert(policy.id) }
                if active && (!policy.counts.indices.contains(at - 1) || (policy.replacementLimits.map { !$0.indices.contains(at - 1) } ?? false) || (policy.preparedCounts.map { !$0.indices.contains(at - 1) } ?? false)) { issue("policy-row-\(policy.id)", "\(policy.name) has no explicit row for this level.", at) }
                let ids = choice.capabilities?.spells?[policy.id] ?? []
                let count = active && policy.counts.indices.contains(at - 1) ? policy.counts[at - 1] : 0
                let editableList = policy.hasEditableLoadout && policy.mode == .prepared
                if !editableList && (ids.count != count || Set(ids).count != ids.count) { issue("casting-count-\(policy.id)", "\(policy.name) requires \(count) distinct choices.", at) }
                let maximum = policy.maximumSpellLevels.indices.contains(at - 1) ? policy.maximumSpellLevels[at - 1] : 0
                for id in editableList ? [] : ids {
                    guard let spell = pack.spells.first(where: { $0.id == id }), policy.spellIDs.contains(id), spell.level <= maximum else { issue("casting-option-\(id)", "Spell is outside the policy's eligible list or level.", at); continue }
                    if let reason = spell.unavailableReason { issue("casting-source-\(id)", reason, at) }
                    if (policy.alwaysGrantedSpellIDs ?? []).contains(id) || ([.known, .prepared].contains(policy.mode) && grants.contains(where: { _, grant in
                        grant.kind == .spell && grant.target == id && matches(grant.condition, at: at, selections: eligibleSelections, config: config, subclass: choice.subclassID)
                    })) { issue("casting-granted-\(id)", "Additional granted spells do not consume \(policy.name) choices.", at) }
                }
                let removed = Set(previousSpells[policy.id] ?? []).subtracting(ids)
                let limit = policy.replacementLimits.flatMap { $0.indices.contains(at - 1) ? $0[at - 1] : nil } ?? 0
                if active && (policy.loadout == .retained || ![.prepared, .ritual].contains(policy.mode)) && removed.count > limit { issue("casting-replacement-\(policy.id)", "Too many replacements for \(policy.name).", at) }
                if active && policy.mode == .book && !policy.hasEditableLoadout {
                    let prepared = choice.capabilities?.prepared?[policy.id] ?? []
                    let needed = policy.preparedCounts.flatMap { $0.indices.contains(at - 1) ? $0[at - 1] : nil } ?? 0
                    if prepared.count != needed || Set(prepared).count != prepared.count || !Set(prepared).isSubset(of: Set(ids)) { issue("preparation-\(policy.id)", "Prepare \(needed) different spells from your book.", at) }
                }
                if at == level && active {
                    if !editableList { spellIDs.formUnion(ids) }
                    for id in ids { result.spellLabels[id] = policy.mode == .book ? ((choice.capabilities?.prepared?[policy.id] ?? []).contains(id) ? "Prepared (book)" : "Spellbook") : policy.mode.rawValue.capitalized }
                    if !ids.isEmpty {
                        castingAbility = policy.ability
                        let mod = Ability.modifier(result.scores[policy.ability.rawValue, default: 10])
                        result.spellDC = 8 + result.proficiency + mod; result.spellAttack = result.proficiency + mod
                    }
                }
            }
            // Selection and feat prerequisites above retain their pre-choice context.
            // Effects and caps share the post-improvement, pre-grant score snapshot.
            let historical = RulesEngine.evaluateLegacy(baseBuild, in: basePack, through: at)
            prerequisiteScores = historical.scores
            for (_, grant) in grants where matches(grant.condition, at: at, selections: eligibleSelections, config: config, subclass: choice.subclassID) {
                if let table = grant.value?.table, !table.indices.contains(at - 1) { issue("value-row-\(grant.id)", "\(grant.target ?? grant.id) has no explicit value at this level.", at) }
            }
            // Check each historical row, not just the final score. A later cap cannot
            // legalize an earlier overspend; current-level caps precede score grants.
            var rowScores = historical.scores, rowCaps: [String:Int] = [:], rowApplied = Set<String>()
            var rowScoreProvenance: [CapabilityProvenance] = []
            for (owner, grant) in grants where matches(grant.condition, at: at, selections: eligibleSelections, config: config, subclass: choice.subclassID) {
                guard rowApplied.insert(grant.id).inserted else { continue }
                let key = grant.target ?? ""
                if grant.kind == .abilityCap { rowCaps[key] = max(rowCaps[key, default: 20], grant.value?.base ?? 20) }
                if grant.kind == .abilityScore {
                    rowScores[key, default: 10] += grant.value?.resolve(level: at, scores: historical.scores, proficiency: historical.proficiency) ?? 0
                    rowScoreProvenance.append(.init(grantID:grant.id,sourceID:owner,level:grant.level ?? 1))
                }
            }
            for (key, value) in rowScores where value < 1 || value > rowCaps[key, default: 20] {
                issue("score-cap-\(key)", "\(key.uppercased()) must be between 1 and \(rowCaps[key, default: 20]) at this level.", at)
            }
            // Entry at the following row sees accepted grants with this row's
            // final scores/configuration, not just legacy skills or pre-ASI ranks.
            let replayRanks=ranks, replayScores=prerequisiteScores
            prerequisiteScores=rowScores; ranks=baselineRanks
            for _ in 0...grants.count {
                let previousRanks=ranks
                deriveRanks(grants,selections:eligibleSelections)
                if ranks == previousRanks { break }
            }
            priorProficiencyRanks=ranks
            ranks=replayRanks; prerequisiteScores=replayScores
            previousGroups = selected; previousSpells = choice.capabilities?.spells ?? [:]
            finalGrants = grants; finalSelections = eligibleSelections; finalConfig = config
            finalScores = rowScores; finalScoreProvenance = rowScoreProvenance
        }
        var skillAbilities = RulesEngine.skillAbilities, skillBonuses: [String:Int] = [:]
        prerequisiteScores = result.scores
        let originalScores = result.scores
        var applied = Set(finalScoreProvenance.map(\.grantID))
        result.scores = finalScores
        result.provenance.append(contentsOf:finalScoreProvenance)
        // Alternative formulas resolve before additive bonuses, independent of author ordering.
        let orderedGrants = finalGrants.sorted { lhs, rhs in
            let order: [CapabilityGrant.Kind:Int] = [.abilityScore:0, .armorFormula:1, .speedBase:1, .armorBonus:3]
            return (order[lhs.1.kind] ?? 2, lhs.1.id) < (order[rhs.1.kind] ?? 2, rhs.1.id)
        }
        let con = Ability.modifier(result.scores["con", default: 10]), oldCon = Ability.modifier(originalScores["con", default: 10])
        result.hitPoints += Multiclassing.baseHitPoints(build,in:pack,through:level,constitution:con) - Multiclassing.baseHitPoints(build,in:pack,through:level,constitution:oldCon)
        let dexDelta = Ability.modifier(result.scores["dex", default: 10]) - Ability.modifier(originalScores["dex", default: 10])
        result.armorClass += dexDelta; result.initiative += dexDelta
        if result.mantleArmorClass != nil { result.mantleArmorClass = 10 + con + Ability.modifier(result.scores["cha", default: 10]) }
        if let ability = castingAbility { let modifier = Ability.modifier(result.scores[ability.rawValue, default: 10]); result.spellDC = 8 + result.proficiency + modifier; result.spellAttack = result.proficiency + modifier }
        result.castingAbility = castingAbility
        for (owner, grant) in orderedGrants where grant.kind != .abilityScore {
            guard matches(grant.condition, at: level, selections: finalSelections, config: finalConfig, subclass: build.levels.prefix(level).last?.subclassID ?? "") else { continue }
            // Same canonical grant does not stack from two ownership paths.
            guard applied.insert(grant.id).inserted else { continue }
            let value = grant.value?.resolve(level: level, scores: result.scores, proficiency: result.proficiency) ?? 0
            result.provenance.append(.init(grantID: grant.id, sourceID: owner, level: grant.level ?? 1))
            switch grant.kind {
            case .abilityCap: break // Already checked in ordered historical replay.
            case .proficiency:
                let targets = proficiencyTargets(grant.target)
                for target in targets { if let rank = grant.rank, rank.bonus(result.proficiency) > (ranks[target] ?? .none).bonus(result.proficiency) { ranks[target] = rank } }
            case .skillAbility: skillAbilities[grant.target ?? ""] = grant.ability
            case .skillBonus: skillBonuses[grant.target ?? "", default: 0] += value
            case .armorFormula: result.armorClass = max(result.armorClass, value)
            case .armorBonus: result.armorClass += value
            case .hitPoints: result.hitPoints += value
            case .initiative: result.initiative += value
            case .speed: result.speed += value
            case .speedBase: result.speed = value
            case .size: result.size = grant.target
            case .language:
                if let language = grant.target, !result.languages.contains(language) { result.languages.append(language) }
            case .abilityScore: result.scores[grant.target ?? "", default: 10] += value
            case .resource: result.resources.append(.init(id: grant.id, name: grant.target ?? grant.id, maximum: max(0, value), recovery: grant.recovery ?? "unspecified"))
            case .trait:
                let label = grant.text ?? grant.target ?? grant.id
                result.traits.append(grant.value == nil ? label : "\(label): \(value)")
            case .manual: result.supportDiagnostics.append("Manual: " + (grant.text ?? grant.id))
            case .unsupported: issue("unsupported-\(grant.id)", grant.text ?? "Required mechanic is unsupported.")
            case .spell:
                if let id = grant.target, let spell = pack.spells.first(where: { $0.id == id }) {
                    spellIDs.insert(id); result.grantedSpellIDs.insert(id)
                    let label: String
                    switch grant.spellMode ?? .granted {
                    case .granted: label = "Granted"
                    case .prepared: label = "Prepared (granted)"
                    case .atWill: label = "At will (granted)"
                    case .limited: label = "Limited use (granted)"
                    case .ritual: label = "Ritual (granted)"
                    }
                    let labels = Set((result.spellLabels[id]?.components(separatedBy: "; ") ?? []) + [label])
                    result.spellLabels[id] = labels.sorted().joined(separator: "; ")
                    if let ability = grant.ability {
                        let modifier = Ability.modifier(result.scores[ability.rawValue,default:10])
                        let mode: CastingPolicy.Mode
                        switch grant.spellMode ?? .granted {
                        case .prepared: mode = .prepared
                        case .atWill: mode = .atWill
                        case .limited: mode = .limited
                        case .ritual: mode = .ritual
                        case .granted: mode = .granted
                        }
                        result.castingSources.append(.init(id:grant.id,sourceID:owner,name:grant.text ?? spell.name,ability:ability,dc:8+result.proficiency+modifier,attack:result.proficiency+modifier,maximumSpellLevel:spell.level,acquisitionPolicy:mode,editableLoadout:false,preparationCount:0,poolIDs:[],availableSpellIDs:[id],memberSpellIDs:[id],selectedLoadout:[id],spellLabels:[id:label]))
                    }
                    if let reason = spell.unavailableReason { issue("grant-source-\(id)", reason) }
                }
            }
        }
        result.proficiencyRanks = ranks
        for (skill, ability) in skillAbilities { result.skillModifiers[skill] = Ability.modifier(result.scores[ability.rawValue, default: 10]) + (ranks[skill] ?? .none).bonus(result.proficiency) + skillBonuses[skill, default: 0] }
        result.skills = ranks.filter { RulesEngine.skillAbilities[$0.key] != nil && ($0.value == .proficient || $0.value == .expertise) }.keys.sorted()
        result.spells = pack.spells.filter { spellIDs.contains($0.id) }.sorted { ($0.level, $0.name) < ($1.level, $1.name) }
        let activePools = definitions.flatMap { owner, data in
            (data.spellPools ?? []).filter { level >= unlocks[owner, default:1] && matches($0.condition, at:level, selections:finalSelections, config:finalConfig, subclass:build.levels.prefix(level).last?.subclassID ?? "") }.map { (owner,$0) }
        }
        let activePolicies = definitions.flatMap { owner, data in (data.casting ?? []).filter { result.activePolicyIDs.contains($0.id) }.map { (owner,$0) } }
        for row in classRows {
        guard let cls=pack.classes.first(where: { $0.id == row.id }) else { continue }
        let history=build.levels.prefix(level).last { ($0.classID ?? build.classID) == row.id }
        let sub=cls.subclasses.first { $0.id == row.subclassID }
        let replaced = !(cls.capabilities?.casting ?? []).isEmpty || (sub?.capabilities?.casting ?? []).contains { $0.legacyClassCasting != .preserve }
        let ids=Set((history?.spellIDs ?? []) + (history?.cantripIDs ?? []) + (sub?.spells.filter { $0.level <= row.level }.flatMap(\.spellIDs) ?? []))
        let legacyCastingSpells=pack.spells.filter { ids.contains($0.id) }
        let progression=cls.at(row.level)
        let slots=progression?.slots ?? 0, slotLevel=progression?.slotLevel ?? 0
        var legacyPoolIDs:[String]=[]
        if slots > 0, !activePools.isEmpty || classRows.count > 1,
           (cls.capabilities?.spellPools ?? []).isEmpty,
           !(cls.capabilities?.casting ?? []).contains(where: { !($0.poolIDs ?? []).isEmpty }) {
            // A separate species/subclass pool does not replace legacy class
            // capacity. Legacy data does not declare a pool kind or recovery;
            // retain that uncertainty instead of guessing or merging counters.
            // Reserve inactive declarations too, so toggling a pool condition
            // cannot rename this fallback or redirect its source reference.
            let authoredIDs=Set(definitions.flatMap { ($0.1.spellPools ?? []).map(\.id) })
            let base=cls.id+":legacy-slots"
            var id=base, suffix=1
            while authoredIDs.contains(id) { id=base+"#\(suffix)"; suffix += 1 }
            result.spellPools.append(.init(id:id,sourceID:cls.id,name:cls.name+" (legacy slots)",kind:.custom,recovery:"Unspecified (legacy source)",capacities:[slotLevel:slots]))
            legacyPoolIDs=[id]
        }
        if let ability=cls.spellAbility, !legacyCastingSpells.isEmpty, !replaced {
            let mod=Ability.modifier(result.scores[ability.rawValue,default:10])
            let ids=legacyCastingSpells.map(\.id)
            let labels=Dictionary(uniqueKeysWithValues:legacyCastingSpells.map { ($0.id,result.grantedSpellIDs.contains($0.id) ? "Granted (legacy)" : "Known (legacy)") })
            result.castingSources.append(.init(id:cls.id+":legacy",sourceID:cls.id,name:cls.name+" (legacy casting)",ability:ability,dc:8+result.proficiency+mod,attack:result.proficiency+mod,maximumSpellLevel:slotLevel,acquisitionPolicy:.known,editableLoadout:false,preparationCount:0,poolIDs:legacyPoolIDs,availableSpellIDs:cls.spellIDs,memberSpellIDs:ids,selectedLoadout:ids,spellLabels:labels))
        }
        }
        if classRows.count > 1 { result.slots=0; result.slotLevel=0 }
        Spellcasting.project(build:build, pack:pack, level:level, policies:activePolicies, pools:activePools, result:&result)
        Multiclassing.composePools(build,in:pack,level:level,result:&result)
        for i in result.classLevels.indices {
            let id=result.classLevels[i].id
            result.classLevels[i].castingSourceIDs=result.castingSources.filter { $0.sourceID == id || $0.sourceID.hasPrefix(id+":") }.map(\.id)
        }
        return result
    }
}
