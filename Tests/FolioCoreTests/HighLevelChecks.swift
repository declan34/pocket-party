import Foundation
import FolioCore

// Original martial fixture: exact rows, deliberately nonstandard improvement schedule.
func highLevelFixture() throws -> (ContentPack, CharacterBuild) {
    var p = try ContentPack.sample()
    p.schemaVersion = 2; p.capabilities = .init()
    p.classes[0].capabilities = .init(edition: "2024")
    p.classes[0].spellAbility = nil; p.classes[0].spellIDs = []
    p.classes[0].talents = []
    for i in p.classes[0].subclasses.indices { p.classes[0].subclasses[i].spells = [] }
    p.classes[0].progression = (1...20).map { level in
        var row = p.classes[0].progression[0]
        row.level = level; row.talents = 0; row.cantrips = 0; row.spells = 0
        row.slots = 0; row.slotLevel = 0; row.improvement = false
        return row
    }
    var b = try FolioCoreTests().valid()
    b.rulesProfile = .init(edition: "2024"); b.levels[0].talentIDs = []
    return (p,b)
}

func highLevelProgressionChecks() throws {
    let (p, initial) = try highLevelFixture()
    try PackValidator.validate(p)
    var b = initial
    for level in 1...20 {
        if level >= 3 { b.levels[level - 1].subclassID = "waylight" }
        let s = RulesEngine.evaluate(b, in: p)
        try check(s.isValid, "Level \(level) must be valid: \(s.issues)")
        try check(s.proficiency == 2 + (level - 1) / 4, "Historical proficiency at \(level)")
        if level < 20 { b = try RulesEngine.advance(b, in: p) }
    }
    try check(RulesEngine.evaluate(b, in: p, through: 5).proficiency == 3, "Earlier replay must not use final PB")
    var capped = false
    do { _ = try RulesEngine.advance(b, in: p) } catch { capped = true }
    try check(capped && b.level == 20, "Boundary rejects advancement and preserves history")
    b.levels.append(.init(level: 21, previous: b.levels.last))
    try check(RulesEngine.evaluate(b, in: p).issues.contains { $0.code == "cap-invalid-content" }, "21 must fail structural validation")
    var missing = p; missing.classes[0].progression.remove(at: 8)
    var rejected = false
    do { try PackValidator.validate(missing) } catch { rejected = true }
    try check(rejected, "Never extrapolate a missing class row")
}

func highLevelTableChecks() throws {
    var (p,b) = try highLevelFixture()
    p.classes[0].capabilities?.grants = [.init(id: "focus", kind: .resource, target: "Focus", value: .init(table: Array(1...20)), level: 6, recovery: "long rest")]
    for level in 2...20 { b.levels.append(.init(level: level, previous: b.levels.last)); if level >= 3 { b.levels[level - 1].subclassID = "waylight" } }
    let s = RulesEngine.evaluate(b, in: p)
    try check(s.isValid && s.resources.first?.maximum == 20, "Level-indexed capacity must use level 20, not acquisition level: \(s.issues)")
    try check(RulesEngine.evaluate(b, in: p, through: 6).resources.first?.maximum == 6, "Resource historical scope")
    p.classes[0].capabilities?.grants?[0].value?.table = [1,2,3,4,5,6]
    try check(RulesEngine.evaluate(b, in: p).issues.contains { $0.code == "cap-value-row-focus" }, "Absent resource row must block, not silently use zero")
    p.classes[0].capabilities?.grants = []
    p.classes[0].capabilities?.groups = [.init(id: "training", name: "Training", counts: [0], options: [])]
    try check(RulesEngine.evaluate(b, in: p).issues.contains { $0.code == "cap-group-row-training" }, "Missing active group row must block")
    p.classes[0].capabilities?.groups = []
    p.classes[0].capabilities?.casting = [.init(id: "study", name: "Study", mode: .known, ability: .cha, spellIDs: [], counts: [0], maximumSpellLevels: [0])]
    try check(RulesEngine.evaluate(b, in: p).issues.contains { $0.code == "cap-policy-row-study" }, "Missing policy row must block")
}

func highLevelImprovementChecks() throws {
    var (p,b) = try highLevelFixture()
    // Decode new authoring keys: absent repeatability still means nonrepeatable.
    var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(p)) as! [String:Any]
    var feats = object["feats"] as! [[String:Any]]
    let index = feats.firstIndex { $0["id"] as? String == "ability-improvement" }!
    feats[index]["repeatable"] = true; object["feats"] = feats
    p = try JSONDecoder().decode(ContentPack.self, from: JSONSerialization.data(withJSONObject: object))
    for level in [4,6,10,14,19] { p.classes[0].progression[level - 1].improvement = true }
    for level in 1...20 {
        if level > 1 { b.levels.append(.init(level: level, previous: b.levels.last)) }
        if level >= 3 { b.levels[level - 1].subclassID = "waylight" }
        if [4,6,10,14,19].contains(level) { b.levels[level - 1].featID = "ability-improvement"; b.levels[level - 1].boosts = ["con":1,"str":1] }
    }
    b.levels[3].boosts = ["con":2]
    let s = RulesEngine.evaluate(b, in: p)
    try check(s.isValid, "Explicit repeatable improvements on custom schedule: \(s.issues)")
    let hp = s.hitPoints
    b.levels[3].boosts = ["dex":2]
    try check(RulesEngine.evaluate(b, in: p).hitPoints == hp - 20, "Earlier Constitution change replays all HP")
    let before = RulesEngine.evaluate(b, in: p, through: 3)
    try check(before.scores["con"] == 14, "Historical result excludes later improvements")
    let last = b.levels.removeLast(); b = try RulesEngine.advance(b, in: p)
    try check(b.levels.last?.level == last.level && RulesEngine.evaluate(b, in: p).isValid, "Remove and re-add level recomputes without accumulation")
    object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(p)) as! [String:Any]
    feats = object["feats"] as! [[String:Any]]; feats[index]["repeatable"] = false; object["feats"] = feats
    p = try JSONDecoder().decode(ContentPack.self, from: JSONSerialization.data(withJSONObject: object))
    try check(RulesEngine.evaluate(b, in: p).issues.contains { $0.code == "feat-duplicate" && $0.level == 6 }, "Nonrepeatable feats remain rejected")
}

func highLevelCapChecks() throws {
    var (p,b) = try highLevelFixture()
    p.classes[0].capabilities?.grants = [.init(id: "apex-score", kind: .abilityScore, target: "cha", value: .init(base: 4), level: 20)]
    var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(p)) as! [String:Any]
    var classes = object["classes"] as! [[String:Any]]
    var cap = classes[0]["capabilities"] as! [String:Any]
    var grants = cap["grants"] as! [[String:Any]]
    grants.append(["id":"apex-cap", "kind":"abilityCap", "target":"cha", "value":["base":24], "level":20])
    cap["grants"] = grants; classes[0]["capabilities"] = cap; object["classes"] = classes
    do { p = try JSONDecoder().decode(ContentPack.self, from: JSONSerialization.data(withJSONObject: object)) }
    catch { throw FolioError.invalid("High-level explicit abilityCap grant is unsupported: \(error)") }
    for level in 2...20 { b.levels.append(.init(level: level, previous: b.levels.last)); if level >= 3 { b.levels[level - 1].subclassID = "waylight" } }
    let s = RulesEngine.evaluate(b, in: p)
    try check(s.isValid && s.scores["cha"] == 21, "Cap precedes score grant independently of author order: \(s.issues)")
    try check(RulesEngine.evaluate(b, in: p, through: 19).scores["cha"] == 17, "Apex grant cannot leak backward")
    p.classes[0].capabilities?.grants?[0].level = 19
    try check(RulesEngine.evaluate(b, in: p).issues.contains { $0.code == "cap-score-cap-cha" && $0.level == 19 }, "Later cap must not repair earlier over-cap score")
}

func highLevelConditionalCapChecks() throws {
    var (p,b) = try highLevelFixture()
    p.classes[0].progression[3].improvement=true
    for at in 2...5 { b.levels.append(.init(level:at,previous:b.levels.last)); if at>=3 { b.levels[at-1].subclassID="waylight" } }
    b.levels[3].featID="ability-improvement"; b.levels[3].boosts=["cha":2]
    let threshold=RulePredicate(.ability,key:"cha",minimum:19)
    p.classes[0].capabilities?.grants=[.init(id:"conditional-score",kind:.abilityScore,target:"cha",value:.init(base:2),condition:threshold,level:4)]
    let uncapped=RulesEngine.evaluate(b,in:p)
    try check(uncapped.scores["cha"] == 21 && uncapped.issues.contains { $0.code == "cap-score-cap-cha" && $0.level == 4 }, "Current improvement activates score grant and must fail that historical row's cap")
    p.classes[0].capabilities?.grants?.append(.init(id:"conditional-cap",kind:.abilityCap,target:"cha",value:.init(base:22),condition:threshold,level:4))
    let capped=RulesEngine.evaluate(b,in:p)
    try check(capped.isValid && capped.scores["cha"] == 21, "Same post-improvement context must activate the conditional cap")
    try check(RulesEngine.evaluate(b,in:p,through:3).scores["cha"] == 17, "Conditional score/cap cannot leak before improvement")
    p.classes[0].capabilities?.grants?[1].level=5
    try check(RulesEngine.evaluate(b,in:p).issues.contains { $0.code == "cap-score-cap-cha" && $0.level == 4 }, "Later conditional cap cannot legalize the earlier row")
    p.classes[0].capabilities?.grants?[1].level=4
    b.levels[3].boosts=["dex":2]
    let edited=RulesEngine.evaluate(b,in:p)
    try check(edited.isValid && edited.scores["cha"] == 17, "Earlier edit removes both conditional score and cap without stale effects")
}

func highLevelSaveAndFeatGrantChecks() throws {
    var (p,b) = try highLevelFixture()
    p.classes[0].saves = [.str,.con]
    for level in 2...20 { b.levels.append(.init(level:level,previous:b.levels.last)); if level>=3 { b.levels[level-1].subclassID="waylight" } }
    p.classes[0].capabilities?.grants = [.init(id:"save-training",kind:.proficiency,target:"save.wis",rank:.proficient,level:14)]
    var s = RulesEngine.evaluate(b,in:p)
    try check(s.isValid && s.proficiencyRanks["save.wis"] == .proficient, "High-level saving throw training must calculate: \(s.issues)")
    let sheet = PrintableSheet(record:.init(pack:p,build:b))
    try check(sheet.checks.contains("wis.save") && sheet.fields["wis.save"] == "+7", "Calculated save training reaches PDF")
    try check(RulesEngine.evaluate(b,in:p,through:13).proficiencyRanks["save.wis"] != .proficient, "Save training stays historical")
    let i = p.feats.firstIndex { $0.id == "ability-improvement" }!
    p.feats[i].repeatable=true; p.feats[i].abilityPoints=0; p.feats[i].abilityOptions=[]
    p.feats[i].capabilities = .init(edition:"2024",grants:[.init(id:"practice",kind:.speed,value:.init(base:5))])
    for at in [6,14] { p.classes[0].progression[at-1].improvement=true; b.levels[at-1].featID="ability-improvement" }
    s = RulesEngine.evaluate(b,in:p)
    try check(s.isValid && s.speed == 40, "Repeatable feat grants stack once per acquisition: \(s.issues)")
    try check(RulesEngine.evaluate(b,in:p,through:13).speed == 35, "Later repeated feat grant cannot leak backward")
    p.feats[i].capabilities = .init(edition:"2014",adapters:[.init(edition:"2024",canonicalID:"adapted-practice",label:"Revised practice",replacementGrants:[.init(id:"adapted-speed",kind:.speed,value:.init(base:3))])])
    try check(RulesEngine.evaluate(b,in:p).speed == 36, "Every repeated acquisition must use its explicit edition adapter")
}

func vesselHighLevelSourceChecks() throws {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("PrivatePacks/vessel-pack.json")
    guard FileManager.default.fileExists(atPath: url.path) else { print("SKIP vesselHighLevelSourceChecks: private sources absent"); return }
    let p = try PackValidator.decode(Data(contentsOf: url)), c = p.classes[0]
    try check(c.maxLevel == 20 && c.progression.count == 20, "Actual Vessel needs all 20 explicit source rows")
    try check(c.at(20)?.slots == 4 && c.at(20)?.slotLevel == 5 && c.at(20)?.spells == 11 && c.at(20)?.cantrips == 4, "Source level-20 uniform pool and acquisition counts")
    let aspects = c.capabilities!.groups!.first { $0.id == "aspects" }!
    try check(aspects.options.count == 26 && aspects.count(at: 20) == 7, "All 24 Aspects, with three Presence variants")
    try check(aspects.options.first { $0.id == "minor-magick" }?.repeatable == true, "Minor Magick prose explicitly permits repetition")
    try check(aspects.options.first { $0.id == "colossal-archon" }?.prerequisite?.kind == .all, "Colossal requires both level and Dire Stature")
    let ascended = c.subclasses.first { $0.id == "the-ascended" }!.capabilities!
    let fifth = ascended.casting!.first { $0.id == "ascended-arcanum-5" }!
    let sixth = ascended.casting!.first { $0.id == "ascended-arcanum-6" }!
    try check(fifth.counts[14] == 1 && fifth.counts[13] == 0 && sixth.counts[19] == 1 && sixth.counts[18] == 0, "Arcanum unlocks independently at 15/20")
    try check(fifth.spellIDs.allSatisfy { id in p.spells.contains { $0.id == id && $0.level == 5 } } && sixth.spellIDs.allSatisfy { id in p.spells.contains { $0.id == id && $0.level == 6 } }, "Arcanum exact spell tiers, not lower-tier alternatives")
    try check(c.subclasses.first { $0.id == "the-fallen" }!.capabilities!.groups!.contains { $0.id == "fallen-bonus" && $0.counts[14] == 1 && $0.requiredOptionID == "aether-wings" && $0.locked == true }, "Fallen level-15 locked bonus Aspect")
    try check(c.features.contains { $0.id == "unchained-power" && $0.level == 18 && $0.text.contains("indefinitely") }, "Reviewed original unchained duration replaces broken extraction")
    func build(_ sub: String, affinity: String = "earth") -> CharacterBuild {
        var b = CharacterBuild(classID: c.id); b.rulesProfile = .init(edition:"2024")
        b.name = "High source acceptance"; b.speciesID = "dwarf"; b.backgroundID = "farmer"
        b.backgroundBoosts = ["con":2,"wis":1]; b.classSkills = ["Acrobatics","Religion"]; b.languages = ["Elvish","Dwarvish"]
        let policies = c.capabilities!.casting! + c.subclasses.first { $0.id == sub }!.capabilities!.casting.orEmpty
        let granted = Set(c.subclasses.flatMap { ($0.capabilities?.grants ?? []).filter { $0.kind == .spell }.compactMap(\.target) })
        var previous: [String:[String]] = [:]
        for at in 1...20 {
            var row = LevelChoice(level:at)
            if at >= 3 { row.subclassID = sub }
            let options = ["uncanny-strength","spirit-sense","iridescent-shield","dire-stature","minor-magick","minor-magick","colossal-archon"]
            var groups = ["aspects":Array(options.prefix(aspects.count(at:at)))]
            if at >= 3 && sub == "the-cataclysm" { groups["affinity"] = ["affinity-"+affinity] }
            if at >= 3 && sub == "the-cursed" { groups["cursed-bonus"] = ["striking-presence-deception"] }
            if at >= 3 && sub == "the-formless" { groups["formless-bonus"] = ["ethereal-tendril"] }
            if at >= 15 && sub == "the-fallen" { groups["fallen-bonus"] = ["aether-wings"] }
            var spells: [String:[String]] = [:]
            for policy in policies {
                if policy.id == "vessel-known" && sub == "the-ascended" && at >= 3 { continue }
                if policy.id != "vessel-known" && policy.id != "vessel-cantrips" && at < 3 { continue }
                let count = policy.counts[at - 1]
                var picks = previous[policy.id] ?? []
                let eligible = p.spells.filter { policy.spellIDs.contains($0.id) && $0.unavailableReason == nil && $0.level <= policy.maximumSpellLevels[at - 1] && !granted.contains($0.id) }.sorted { ($0.level,$0.id) < ($1.level,$1.id) }
                for spell in eligible where picks.count < count && !picks.contains(spell.id) { picks.append(spell.id) }
                spells[policy.id] = picks; previous[policy.id] = picks
            }
            row.capabilities = .init(groups:groups,configurations:["no-armor-shield",at >= 3 ? "archon":"cloak"],spells:spells)
            if [4,8,12,16,19].contains(at) { row.featID = "ability-improvement"; row.boosts = ["str":1,"dex":1] }
            if at == 1 { b.levels = [row] } else { b.levels.append(row) }
        }
        return b
    }
    for sub in c.subclasses {
        var b = build(sub.id); b.equipment = .init()
        let s = RulesEngine.evaluate(b,in:p)
        let unresolvedTargets: Set<String> = Set([
            "the-ascended":["spell.minute-meteors"],
            "the-cataclysm":["spell.elemental-blade","spell.pillars-of-earth"],
            "the-cursed":["spell.flame-whip","spell.dominate-creature","spell.destructive-wave"],
            "the-fallen":["spell.ethereal-anchor","spell.crusaders-mantle","spell.circle-of-power"],
            "the-formless":["spell.grasping-vine","spell.eldritch-tentacles"],
            "the-trickster":[]
        ][sub.id]!)
        try check(Set(s.issues.map(\.code)) == Set(unresolvedTargets.map { "cap-grant-source-"+$0 }), "Only exact unresolved selected source grants block \(sub.id): \(s.issues)")
        try check(s.slots == 4 && s.slotLevel == 5 && s.proficiency == 6 && s.hitPoints == 224, "Source HP/PB/uniform pool at 20 for \(sub.id): HP \(s.hitPoints)")
        try check(s.traits.contains("Iridescent Strike die sides: 12"), "Actual high-level die scaling")
        for (level,die) in [(1,6),(5,8),(11,10),(17,12)] {
            let attack=RulesEngine.evaluate(b,in:p,through:level).equipment?.attacks.first { $0.id == "iridescent-attack" }
            try check(attack?.damage == "1d\(die) +2 radiant","Actual \(sub.id) Iridescent Strike at class level \(level)")
        }
        try check(s.resources.filter { $0.name.hasPrefix("Minor Magick") }.count == 2, "Repeatable Minor Magick retains two distinct capacities")
        if sub.id == "the-ascended" { try check(s.traits.contains("fly speed (ft): 30") && s.spellPools.filter { $0.name.hasPrefix("Ascended Arcanum") && $0.kind == .limited && $0.recovery == "long rest" }.count == 2, "Ascended capstone movement and separate limited uses") }
        if sub.id == "the-fallen" { try check(s.traits.contains("fly speed (ft): 60"), "Fallen bonus Wings calculate flight") }
        if sub.id == "the-cataclysm" {
            try check(!s.resources.contains { $0.id == "cataclysmic-eruption-uses" } && s.traits.contains("Cataclysmic Eruption: at will in Archon Form"), "Reviewed Cataclysm20 grants at-will eruption, not a misleading limited capacity")
            var mortal=b; mortal.levels[19].capabilities?.configurations=["cloak","no-armor-shield"]
            try check(RulesEngine.evaluate(mortal,in:p).resources.contains { $0.id == "cataclysmic-eruption-uses" && $0.maximum == 2 }, "Outside Archon the limited eruption capacity remains")
        }
        var huge = b; huge.levels[19].capabilities?.configurations?.append("colossal-archon-active")
        let grown = RulesEngine.evaluate(huge,in:p)
        try check(grown.size == "Huge" && grown.armorClass == s.armorClass + 2, "Colossal size and actual Ethereal Armor modifier")
    }
}

private extension Optional where Wrapped == [CastingPolicy] {
    var orEmpty: [CastingPolicy] { self ?? [] }
}

func highLevelPublicFixtureChecks() throws {
    let p = try ContentPack.capabilitySample()
    guard let c = p.classes.first(where: { $0.id == "summit-warden" }) else { throw FolioError.invalid("Generated original high-level fixture is missing") }
    var b = try FolioCoreTests().valid(); b.classID=c.id; b.name="I2 Summit Smoke"; b.rulesProfile = .init(edition:"2024")
    b.levels = (1...20).map { at in
        var row=LevelChoice(level:at); if at>=3 { row.subclassID="waylight" }
        if let ability=[4:"con",6:"str",10:"dex",14:"wis",19:"int"][at] { row.featID="ability-improvement";row.boosts=[ability:2] }
        return row
    }
    let s=RulesEngine.evaluate(b,in:p)
    try check(s.isValid && s.proficiency == 6 && s.resources.first?.maximum == 8, "Public high-level original fixture: \(s.issues)")
    let sheet=PrintableSheet(record:.init(pack:p,build:b))
    try check(sheet.fields["level"] == "20" && sheet.fields["proficiency"] == "+6" && sheet.fields["slots.6"] == nil, "Level-20 projection never invents higher spell tiers")
    let data=try LibraryStorage.encoder.encode(CharacterRecord(pack:p,build:b))
    let restored=try LibraryStorage.decoder.decode(CharacterRecord.self,from:data)
    try PackValidator.validateRecord(restored)
    try check(RulesEngine.evaluate(restored.build,in:restored.pack).hitPoints == s.hitPoints, "Level-20 roundtrip remains replay-equivalent")
    if let path=ProcessInfo.processInfo.environment["FOLIO_I2_SMOKE_LIBRARY"] {
        let storage=LibraryStorage(directory:URL(fileURLWithPath:path))
        guard !FileManager.default.fileExists(atPath:storage.file.path) else { throw FolioError.invalid("Smoke target must be an unused disposable directory") }
        b.levels.removeLast();var library=LibraryDocument();library.packs=[p];library.characters=[.init(pack:p,build:b)]
        try storage.save(library); print("Original level-19 smoke library: \(storage.file.path)")
    }
}

func highLevelFamilyMatrixChecks() throws {
    // Original mechanism probes, not official content conversions. Each family
    // asserts its high-level output and verifies that it does not leak into level 5.
    let scaling = [1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10]
    let cases: [(String, CapabilityGrant, (CharacterSummary)->Bool)] = [
        ("barbarian", .init(id:"apex",kind:.abilityScore,target:"str",value:.init(base:4),level:20), { $0.scores["str"] == 14 }),
        ("bard", .init(id:"additional-expertise",kind:.proficiency,target:"History",rank:.expertise,level:10), { $0.skillModifiers["History"] == 11 }),
        ("cleric", .init(id:"divine-strike",kind:.trait,value:.init(base:2),level:14,text:"Radiant dice"), { $0.traits.contains("Radiant dice: 2") }),
        ("druid", .init(id:"elder-form",kind:.size,target:"Large",level:18), { $0.size == "Large" }),
        ("fighter", .init(id:"extra-attacks",kind:.trait,value:.init(base:4),level:20,text:"Attacks"), { $0.traits.contains("Attacks: 4") }),
        ("monk", .init(id:"all-save-training",kind:.proficiency,target:"all-saves",rank:.proficient,level:14), { summary in Ability.allCases.allSatisfy { summary.proficiencyRanks["save."+$0.rawValue] == .proficient } }),
        ("paladin", .init(id:"aura",kind:.trait,value:.init(abilities:[.cha],minimum:1),level:6,text:"Aura bonus"), { $0.traits.contains("Aura bonus: 3") }),
        ("ranger", .init(id:"superior-movement",kind:.speed,value:.init(base:10),level:6), { $0.speed == 40 }),
        ("rogue", .init(id:"precision",kind:.trait,value:.init(table:scaling),level:6,text:"Precision dice"), { $0.traits.contains("Precision dice: 10") }),
        ("sorcerer", .init(id:"sorcery",kind:.resource,target:"Sorcery",value:.init(levelMultiplier:1),level:6,recovery:"long rest"), { $0.resources.first?.maximum == 20 }),
        ("warlock", .init(id:"arcanum",kind:.resource,target:"Arcanum",value:.init(base:1),level:11,recovery:"long rest"), { $0.resources.first?.maximum == 1 }),
        ("wizard", .init(id:"signature",kind:.resource,target:"Signature",value:.init(base:2),level:20,recovery:"short rest"), { $0.resources.first?.maximum == 2 }),
        ("artificer", .init(id:"applications",kind:.trait,value:.init(base:6),level:18,text:"Application capacity"), { $0.traits.contains("Application capacity: 6") })
    ]
    for (family,grant,accept) in cases {
        var (p,b)=try highLevelFixture(); p.classes[0].capabilities?.grants=[grant]
        for at in 2...20 { b.levels.append(.init(level:at,previous:b.levels.last)); if at>=3 { b.levels[at-1].subclassID="waylight" } }
        let s=RulesEngine.evaluate(b,in:p), early=RulesEngine.evaluate(b,in:p,through:5)
        try check(s.isValid && accept(s), "Original \(family) high-level mechanism: \(s.issues)")
        try check(early.isValid && !accept(early), "Original \(family) cannot apply high-level mechanism early")
    }
    // Additional/replacement choices and prerequisite invalidation at high levels.
    var (p,b)=try highLevelFixture()
    p.classes[0].capabilities?.groups=[.init(id:"advanced",name:"Advanced training",counts:[1,1,1,1,1,1,1,1,1,2,2,2,2,2,2,2,2,2,2,2],options:[.init(id:"root",name:"Root"),.init(id:"other",name:"Other"),.init(id:"child",name:"Child",prerequisite:.init(.selection,key:"root"))],replacementLimits:[0,0,0,0,0,1,0,0,0,1,0,0,0,0,0,0,0,0,0,0])]
    for at in 1...20 {
        if at>1 { b.levels.append(.init(level:at,previous:b.levels.last)) }
        if at>=3 { b.levels[at-1].subclassID="waylight" }
        b.levels[at-1].capabilities = .init(groups:["advanced":at<6 ? ["other"] : at<10 ? ["root"] : ["root","child"]])
    }
    try check(RulesEngine.evaluate(b,in:p).isValid, "Additional expertise/style/form/mastery choices use authored high-level schedules")
    b.levels[9].capabilities?.groups?["advanced"]=["other","child"]
    try check(RulesEngine.evaluate(b,in:p).issues.contains { $0.code == "cap-prerequisite-child" && $0.level == 10 }, "High-level replacement invalidates its dependent")
}
