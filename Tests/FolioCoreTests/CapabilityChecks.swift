import Foundation
import FolioCore

func capabilityReviewReplacementChecks() throws {
    var p = try ContentPack.sample(); p.schemaVersion = 2; p.capabilities = .init()
    let a = CapabilityOption(id: "a", name: "A", repeatable: true), other = CapabilityOption(id: "b", name: "B")
    var b = try FolioCoreTests().valid(2); b.rulesProfile = .init(edition: "2024")
    b.levels[0].capabilities = .init(groups: ["track": ["a", "a"]]); b.levels[1].capabilities = .init(groups: ["track": ["a", "b"]])
    for (locked, limit, shouldReject) in [(true, 1, true), (false, 0, true), (false, 1, false)] {
        p.classes[0].capabilities = .init(edition: "2024", groups: [.init(id: "track", name: "Track", counts: [2,2], options: [a,other], replacementLimits: [0,limit], locked: locked)])
        let result = RulesEngine.evaluate(b, in: p)
        try check(result.issues.contains { $0.code == "cap-replacement-track" } == shouldReject, "Repeatable removal must count occurrences (locked=\(locked), limit=\(limit))")
    }
}

func capabilityReviewOwnershipChecks() throws {
    var p = try ContentPack.sample(); p.schemaVersion = 2; p.capabilities = .init()
    let blocker = CapabilityOption(id: "blocker", name: "Blocker", exclusiveGroup: "style")
    var trainer = CapabilityOption(id: "trainer", name: "Trainer", grants: [.init(id: "training", kind: .proficiency, target: "Arcana", rank: .proficient)], exclusiveGroup: "style")
    let dependent = CapabilityOption(id: "dependent", name: "Dependent", prerequisite: .init(.proficiency, key: "Arcana"), grants: [.init(id: "dependent-speed", kind: .speed, value: .init(base: 10))])
    var b = try FolioCoreTests().valid(); b.rulesProfile = .init(edition: "2024")
    b.levels[0].capabilities = .init(groups: ["track": ["blocker", "trainer", "dependent"]])
    b.classSkills = ["Insight", "Religion"] // Arcana must come only from the candidate grant.
    p.classes[0].capabilities = .init(edition: "2024", groups: [.init(id: "track", name: "Track", counts: [3], options: [blocker,trainer,dependent])])
    var result = RulesEngine.evaluate(b, in: p)
    try check(result.speed == 30 && result.proficiencyRanks["Arcana"] != .proficient, "Rejected exclusive training must not grant ranks or unlock dependents: speed=\(result.speed), ranks=\(result.proficiencyRanks), issues=\(result.issues)")
    trainer.exclusiveGroup = nil; trainer.prerequisite = .init(.not, children: [.init(.selection, key: "blocker")])
    p.classes[0].capabilities?.groups?[0].options = [blocker,trainer,dependent]
    result = RulesEngine.evaluate(b, in: p)
    try check(result.speed == 30 && result.proficiencyRanks["Arcana"] != .proficient, "Shrinking negative prerequisites must remove provisional ranks and dependent grants")
    trainer.prerequisite = nil
    p.classes[0].capabilities?.groups?[0].options = [blocker,trainer,dependent]
    b.levels[0].capabilities?.groups = ["track": ["trainer", "trainer", "dependent"]]
    result = RulesEngine.evaluate(b, in: p)
    try check(result.issues.contains { $0.code == "cap-duplicate-trainer" } && result.speed == 40 && result.provenance.filter { $0.grantID == "training" }.count == 1, "Rejected duplicate must retain exactly one accepted training source")
}

func capabilityDerivedChecks() throws {
    var p = try ContentPack.sample(); p.schemaVersion = 2; p.capabilities = .init()
    var b = try FolioCoreTests().valid(); b.rulesProfile = .init(edition: "2024")
    let baseline = RulesEngine.evaluate(b, in: p)
    p.classes[0].capabilities = .init(edition: "2024", grants: [
        .init(id: "constitution", kind: .abilityScore, target: "con", value: .init(base: 2)),
        .init(id: "dexterity", kind: .abilityScore, target: "dex", value: .init(base: 2)),
        .init(id: "charisma", kind: .abilityScore, target: "cha", value: .init(base: 2)),
        .init(id: "training", kind: .proficiency, target: "Arcana", rank: .proficient)
    ], groups: [.init(id: "expert", name: "Expert", counts: [1], options: [.init(id: "learned", name: "Learned", prerequisite: .init(.proficiency, key: "Arcana"), grants: [.init(id: "learned-speed", kind: .speed, value: .init(base: 5))])])])
    b.levels[0].capabilities = .init(groups: ["expert": ["learned"]])
    let s = RulesEngine.evaluate(b, in: p)
    try check(s.hitPoints == baseline.hitPoints + 1, "Ability grants must recompute Constitution HP")
    try check(s.armorClass == baseline.armorClass + 1 && s.initiative == baseline.initiative + 1, "Ability grants must recompute Dexterity defense")
    try check(s.spellDC == baseline.spellDC.map { $0 + 1 }, "Ability grants must recompute casting")
    try check(s.speed == baseline.speed + 5 && s.isValid, "Grant-derived proficiency must satisfy prerequisites")
}

func capabilityValidationHardeningChecks() throws {
    var p = try ContentPack.sample(); p.schemaVersion = 2; p.capabilities = .init()
    var a = CapabilityConfiguration(id: "a", name: "A"), b = CapabilityConfiguration(id: "b", name: "B")
    a.prerequisite = .init(.configuration, key: "b"); b.prerequisite = .init(.configuration, key: "a")
    p.classes[0].capabilities = .init(edition: "2024", configurations: [a, b])
    func rejected(_ pack: ContentPack) -> Bool { do { try PackValidator.validate(pack); return false } catch { return true } }
    try check(rejected(p), "Configuration dependency cycles must be rejected")
    p.classes[0].capabilities = .init(edition: "2024", grants: [.init(id: "collision", kind: .speed, value: .init(base: 5)), .init(id: "collision", kind: .speed, value: .init(base: 10))])
    try check(rejected(p), "Conflicting grant identities must be rejected")
    p.classes[0].capabilities = .init(edition: "2024", grants: [.init(id: "huge", kind: .speed, value: .init(minimum: Int.max))])
    try check(rejected(p), "All numeric fields must have bounded values")
    var build = try FolioCoreTests().valid(); build.rulesProfile = .init(edition: "2024")
    try check(RulesEngine.evaluate(build, in: p).issues.contains { $0.code == "cap-invalid-content" }, "Runtime evaluation must reject invalid packs before applying values")
}

func capabilityRepeatChecks() throws {
    var p = try ContentPack.sample(); p.schemaVersion = 2; p.capabilities = .init()
    let repeated = CapabilityOption(id: "practice", name: "Practice", grants: [.init(id: "practice-speed", kind: .speed, value: .init(base: 5))], repeatable: true)
    p.classes[0].capabilities = .init(edition: "2024", groups: [.init(id: "practice", name: "Practice", counts: [2], options: [repeated])])
    var b = try FolioCoreTests().valid(); b.rulesProfile = .init(edition: "2024"); b.levels[0].capabilities = .init(groups: ["practice": ["practice", "practice"]])
    try check(RulesEngine.evaluate(b, in: p).speed == 40, "Repeatable choices need separate occurrence grants")
}

func capabilityFamilyAndConfigurationChecks() throws {
    var p = try ContentPack.sample(); p.schemaVersion = 2; p.capabilities = .init()
    var group = CapabilityChoiceGroup(id: "bonus", name: "Bonus", counts: [1], options: [.init(id: "skill-a", name: "A"), .init(id: "skill-b", name: "B"), .init(id: "other", name: "Other")])
    group.requiredOptionIDs = ["skill-a", "skill-b"]
    var air = CapabilityConfiguration(id: "air", name: "Air"), earth = CapabilityConfiguration(id: "earth", name: "Earth")
    air.exclusiveGroup = "element"; earth.exclusiveGroup = "element"
    p.classes[0].capabilities = .init(edition: "2024", groups: [group], configurations: [air, earth])
    var b = try FolioCoreTests().valid(); b.rulesProfile = .init(edition: "2024")
    b.levels[0].capabilities = .init(groups: ["bonus": ["other"]])
    try check(!RulesEngine.evaluate(b, in: p).isValid, "Bonus must select its required family")
    b.levels[0].capabilities?.groups = ["bonus": ["skill-b"]]
    try check(RulesEngine.evaluate(b, in: p).isValid, "Any canonical family variant is valid")
    b.levels[0].capabilities?.configurations = ["air", "earth"]
    try check(!RulesEngine.evaluate(b, in: p).isValid, "Exclusive configurations cannot be active together")
}

func capabilityHistoricalPrerequisiteChecks() throws {
    var p = try ContentPack.sample(); p.schemaVersion = 2; p.capabilities = .init()
    var b = try FolioCoreTests().valid(4); b.rulesProfile = .init(edition: "2024")
    let threshold = RulesEngine.evaluate(b, in: p).scores["cha"]!
    p.classes[0].capabilities = .init(edition: "2024", groups: [.init(id: "advanced", name: "Advanced", counts: [0,0,0,1], options: [.init(id: "advanced", name: "Advanced", prerequisite: .init(.ability, key: "cha", minimum: threshold))])])
    b.levels[3].capabilities = .init(groups: ["advanced": ["advanced"]])
    try check(RulesEngine.evaluate(b, in: p).issues.contains { $0.code == "cap-prerequisite-advanced" }, "A same-level ASI cannot fund its own choice prerequisite")
}

func capabilityCatalogAndPolicyChecks() throws {
    let legacy = try ContentPack.sample()
    var p = legacy; p.id = "original-capability"; p.schemaVersion = 2; p.capabilities = .init()
    let replacementID = p.classes[0].subclasses[0].id
    p.classes[0].capabilities = .init(edition: "2024", casting: [.init(id: "known", name: "Known", mode: .known, ability: .cha, spellIDs: ["sheltering-glow"], counts: [1,1,1,1,1], maximumSpellLevels: [1,1,1,1,1], condition: .init(.not, children: [.init(.subclass, key: replacementID)]))])
    p.classes[0].subclasses[0].capabilities = .init(edition: "2024", casting: [.init(id: "prepared", name: "Prepared", mode: .prepared, ability: .int, spellIDs: ["borrowed-dawn"], counts: [0,0,1,1,1], maximumSpellLevels: [0,0,1,1,1])])
    var b = try FolioCoreTests().valid(3); b.rulesProfile = .init(edition: "2024")
    b.levels[0].capabilities = .init(spells: ["known": ["sheltering-glow"]]); b.levels[1].capabilities = b.levels[0].capabilities
    b.levels[2].capabilities = .init(spells: ["prepared": ["borrowed-dawn"]])
    try check(RulesEngine.evaluate(b, in: p).isValid, "Subclass preparation replaces rather than adds to the known policy")
    try check(RulesEngine.evaluate(b, in: p, through: 2).spellLabels["sheltering-glow"] == "Known", "Earlier replay retains known policy")
    let catalog = try ContentCatalog(packs: [legacy, p])
    let original = CharacterRecord(pack: legacy, build: try FolioCoreTests().valid(5))
    let expanded = try catalog.addingChoices(to: original)
    try check(expanded.build == original.build && RulesEngine.evaluate(expanded.build, in: expanded.pack).hitPoints == 43, "Adding schema 2 preserves legacy identity and evaluation")
    let snapshot = try catalog.snapshot(for: catalog.classes.first { $0.sourceLabel.hasPrefix(p.name) }!.id)
    try PackValidator.validate(snapshot)
    let projected = PrintableSheet(record: .init(pack: p, build: b))
    try check(projected.supplements.contains { $0.title == "Complete spell roster" && $0.text.contains("Prepared") }, "PDF roster must preserve policy labels")
    try check(projected.fields["spell.ability"] == Ability.int.name, "PDF uses policy casting ability, not class default")
}

func capabilityQualifiedIdentityChecks() throws {
    var a = try ContentPack.capabilitySample(), b = try ContentPack.capabilitySample()
    a.id = "a"; b.id = "b"
    a.classes[0].capabilities?.grants = [.init(id: "movement", kind: .speed, value: .init(base: 5))]
    b.species[0].capabilities = .init(edition: "2024", grants: [.init(id: "movement", kind: .speed, value: .init(base: 10))])
    let catalog = try ContentCatalog(packs: [a,b])
    let snapshot = try catalog.snapshot(for: catalog.classes[0].id)
    let classID = snapshot.classes.first { $0.capabilities?.grants?.contains { $0.id == "movement" } == true }?.capabilities?.grants?.first?.id
    try check(classID == nil, "Catalog must qualify capability identities, not only spell references")
}

func capabilityReplayMutationChecks() throws {
    var p = try ContentPack.sample(); p.schemaVersion = 2; p.capabilities = .init()
    let root = CapabilityOption(id: "root", name: "Root", grants: [.init(id: "root-speed", kind: .speed, value: .init(base: 5))])
    let child = CapabilityOption(id: "child", name: "Child", prerequisite: .init(.selection, key: "root"), grants: [.init(id: "child-speed", kind: .speed, value: .init(base: 10))])
    p.classes[0].capabilities = .init(edition: "2024", groups: [
        .init(id: "main", name: "Main", counts: [1,1,1], options: [root, .init(id: "other", name: "Other")], replacementLimits: [0,1,0]),
        .init(id: "second", name: "Second", counts: [0,1,1], options: [child])
    ])
    var b = try FolioCoreTests().valid(2); b.rulesProfile = .init(edition: "2024")
    b.levels[0].capabilities = .init(groups: ["main": ["root"]])
    b.levels[1].capabilities = .init(groups: ["main": ["root"], "second": ["child"]])
    try check(RulesEngine.evaluate(b, in: p).speed == 45, "Independent tracks combine eligible grants")
    b.levels[1].capabilities?.groups?["main"] = ["other"]
    try check(RulesEngine.evaluate(b, in: p).speed == 30, "Replacing a prerequisite removes both its effect and dependent effects")
    try check(RulesEngine.evaluate(b, in: p, through: 1).speed == 35, "Earlier replay must retain earlier choices")
    try check(RulesEngine.evaluate(b, in: p).speed == 30, "Repeat replay must not restore removed grants")
    p.classes[0].capabilities = .init(edition: "2024", casting: [.init(id: "book", name: "Book", mode: .book, ability: .int, spellIDs: ["sheltering-glow", "borrowed-dawn"], counts: [1,2], maximumSpellLevels: [1,1], preparedCounts: [1,1])])
    b.levels[0].capabilities = .init(spells: ["book": ["sheltering-glow"]], prepared: ["book": ["sheltering-glow"]])
    b.levels[1].capabilities = .init(spells: ["book": ["sheltering-glow", "borrowed-dawn"]], prepared: ["book": ["borrowed-dawn"]])
    try check(RulesEngine.evaluate(b, in: p).isValid, "Book acquisition and preparation are independent")
    b.levels[1].capabilities?.prepared = ["book": ["keeper-call"]]
    try check(!RulesEngine.evaluate(b, in: p).isValid, "Preparation cannot escape the acquired book")
}

func capabilityRuntimeSequenceChecks() throws {
    var p = try ContentPack.sample(); p.schemaVersion = 2; p.capabilities = .init()
    var b = try FolioCoreTests().valid(); b.rulesProfile = .init(edition: "2024"); b.levels[0].level = 5
    var rejected = false
    do { try PackValidator.validateRecord(.init(pack: p, build: b)) } catch { rejected = true }
    try check(rejected, "Malformed level sequence must be rejected before indexed replay")
}

func capabilityGrantedPrerequisiteChecks() throws {
    var p = try ContentPack.sample(); p.schemaVersion = 2; p.capabilities = .init()
    var b = try FolioCoreTests().valid(2); b.rulesProfile = .init(edition: "2024")
    let score = RulesEngine.evaluate(b, in: p).scores["con"]! + 2
    p.classes[0].capabilities = .init(edition: "2024", grants: [
        .init(id: "constitution", kind: .abilityScore, target: "con", value: .init(base: 2)),
        .init(id: "z-training", kind: .proficiency, target: "Arcana", rank: .proficient),
        .init(id: "a-trained-speed", kind: .speed, value: .init(base: 5), condition: .init(.proficiency, key: "Arcana"))
    ], groups: [.init(id: "advanced", name: "Advanced", counts: [0,1], options: [.init(id: "durable", name: "Durable", prerequisite: .init(.ability, key: "con", minimum: score))])])
    b.levels[1].capabilities = .init(groups: ["advanced": ["durable"]])
    let result = RulesEngine.evaluate(b, in: p)
    try check(result.isValid, "Earlier permanent ability grants must satisfy later prerequisites")
    try check(result.speed == 35, "Conditional grants must see grant-derived proficiency independent of ID order")
}

func capabilityBoundedContractChecks() throws {
    var base = try ContentPack.sample(); base.schemaVersion = 2; base.capabilities = .init()
    func reject(_ data: DefinitionCapabilities, _ message: String) throws {
        var p = base; p.classes[0].capabilities = data
        var rejected = false; do { try PackValidator.validate(p) } catch { rejected = true }
        try check(rejected, message)
    }
    let a = CapabilityOption(id: "a", name: "A", prerequisite: .init(.selection, key: "b"))
    let b = CapabilityOption(id: "b", name: "B", prerequisite: .init(.selection, key: "a"))
    try reject(.init(edition: "2024", groups: [.init(id: "cycle", name: "Cycle", counts: [1], options: [a,b])]), "Selection cycles fail import")
    try reject(.init(edition: "2024", groups: [.init(id: "huge", name: "Huge", counts: [Int.max], options: [])]), "Unsafe choice counts fail import")
    var predicate = RulePredicate(.level, minimum: 1)
    for _ in 0..<10 { predicate = .init(.all, children: [predicate]) }
    try reject(.init(edition: "2024", grants: [.init(id: "deep", kind: .trait, condition: predicate)]), "Recursive predicate depth is bounded")
    var build = try FolioCoreTests().valid(); build.rulesProfile = .init(edition: "2024")
    base.classes[0].capabilities = .init(edition: "2024", grants: [.init(id: "manual", kind: .manual, text: "Narrative combat adjudication")])
    try check(RulesEngine.evaluate(build, in: base).isValid, "Manual combat description does not fabricate a blocker")
    base.classes[0].capabilities?.grants = [.init(id: "required", kind: .unsupported, text: "Required unsupported subsystem")]
    try check(!RulesEngine.evaluate(build, in: base).isValid, "Required unsupported mechanics block completion")
}

func capabilityMartialChecks() throws {
    var p = try ContentPack.sample(); p.schemaVersion = 2; p.capabilities = .init()
    p.classes[0].spellAbility = nil
    for i in p.classes[0].progression.indices { p.classes[0].progression[i].spells = 0; p.classes[0].progression[i].cantrips = 0; p.classes[0].progression[i].slots = 0; p.classes[0].progression[i].slotLevel = 0 }
    for i in p.classes[0].subclasses.indices { p.classes[0].subclasses[i].spells = [] }
    p.classes[0].capabilities = .init(edition: "2024", grants: [.init(id: "resolve", kind: .resource, target: "Resolve", value: .init(table: [1,2,2,3,3]), recovery: "long rest")])
    var b = try FolioCoreTests().valid(5); b.rulesProfile = .init(edition: "2024")
    for i in b.levels.indices { b.levels[i].spellIDs = []; b.levels[i].cantripIDs = [] }
    let result = RulesEngine.evaluate(b, in: p)
    try check(result.isValid && result.spellDC == nil && result.spells.isEmpty && result.resources.first?.maximum == 3, "Original martial fixture has resources without invented casting")
    try check(RulesEngine.evaluate(b, in: p, through: 1).resources.first?.maximum == 1, "Resource tables replay at historical level")
}

func capabilityLegacySelectionBoundaryChecks() throws {
    var p = try ContentPack.sample(); p.schemaVersion = 2; p.capabilities = .init()
    let b = try FolioCoreTests().valid()
    let index = p.species.firstIndex { $0.id == b.speciesID }!
    p.species[index].capabilities = .init(edition: "2024", grants: [.init(id: "new-movement", kind: .speed, value: .init(base: 5))])
    try check(!RulesEngine.evaluate(b, in: p).isValid, "Legacy builds cannot silently ignore newly selected capability mechanics")
}

func legacyCapabilityCharacterization() throws {
    let fixture = FolioCoreTests()
    var record = CharacterRecord(pack: try fixture.pack(), build: try fixture.valid(5))
    record.build.updatedAt = Date(timeIntervalSince1970: 1_700_000_000)
    let data = try LibraryStorage.encoder.encode(record)
    let decoded = try LibraryStorage.decodeCharacter(data)
    try check(record == decoded, "Old format must round trip without an implicit upgrade")
    try check(RulesEngine.evaluate(decoded.build, in: decoded.pack).hitPoints == 43, "Legacy calculations drifted")
    try fixture.persistenceRecoversLastSaveWithoutChangingPinnedPack()
    try fixture.corruptLibraryIsNeverOverwrittenByLoad()
}

func capabilityContractChecks() throws {
    let legacy = try ContentPack.sample()
    var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as! [String: Any]
    json["schemaVersion"] = 2
    json["capabilities"] = ["version": 1, "required": ["choices", "modifiers", "casting", "editions"]]
    let pack = try PackValidator.decode(JSONSerialization.data(withJSONObject: json))
    try check(pack.schemaVersion == 2, "Explicit capability packs must decode")
}

func capabilityReplayChecks() throws {
    var p = try ContentPack.sample()
    p.schemaVersion = 2; p.capabilities = PackCapabilities()
    let trained = CapabilityOption(id: "trained", name: "Scholar", grants: [.init(id: "expert", kind: .proficiency, target: "Arcana", rank: .expertise)])
    let mobile = CapabilityOption(id: "mobile", name: "Runner", grants: [.init(id: "movement", kind: .speed, value: .init(base: 10))])
    p.classes[0].capabilities = .init(edition: "2024", grants: [
        .init(id: "half", kind: .proficiency, target: "all-skills", rank: .half),
        .init(id: "focus", kind: .resource, target: "Focus", value: .init(levelMultiplier: 2), recovery: "short rest"),
        .init(id: "defense", kind: .armorFormula, value: .init(base: 10, abilities: [.con, .cha]), condition: .init(.configuration, key: "mantle"))
    ], groups: [
        .init(id: "training", name: "Training", counts: [1, 1, 1, 1, 1], options: [trained, mobile], replacementLimits: [0, 1, 0, 1, 0]),
        .init(id: "style", name: "Style", counts: [1, 1, 1, 1, 1], options: [.init(id: "calm", name: "Calm", grants: [.init(id: "calm-skill", kind: .skillAbility, target: "Athletics", ability: .cha)])])
    ], configurations: [.init(id: "mantle", name: "Mantle")])
    var b = try FolioCoreTests().valid()
    b.rulesProfile = .init(edition: "2024")
    b.levels[0].capabilities = .init(groups: ["training": ["trained"], "style": ["calm"]], configurations: ["mantle"])
    let s = RulesEngine.evaluate(b, in: p)
    try check(s.armorClass == 15, "Typed conditional defense should replace baseline AC")
    try check(s.isValid, "Schema-2 independent groups should validate: \(s.issues)")
    try check(s.skillModifiers["Arcana"] == 3 && s.proficiencyRanks["Arcana"] == .expertise, "Expertise must double proficiency")
    try check(s.skillModifiers["Athletics"] == 4, "Conditional ability substitution and partial proficiency")
    try check(s.resources.first?.maximum == 2, "Resource capacity is calculated")
    try check(RulesEngine.evaluate(b, in: p).armorClass == s.armorClass, "Replay must be idempotent")
    b.levels[0].capabilities?.groups?["training"] = []
    try check(!RulesEngine.evaluate(b, in: p).isValid, "Missing independent track must block")
}

func capabilityEditionAndSafetyChecks() throws {
    var p = try ContentPack.sample(); p.schemaVersion = 2; p.ruleset = "2014"; p.capabilities = .init()
    for i in p.backgrounds.indices { p.backgrounds[i].abilities = []; p.backgrounds[i].originFeatID = "" }
    var b = try FolioCoreTests().valid(); b.rulesProfile = .init(edition: "2014"); b.backgroundBoosts = [:]; b.languages = []
    try PackValidator.validate(p)
    try check(RulesEngine.evaluate(b, in: p).isValid, "Pure 2014 must not require revised background bonuses or feat")
    p.species[0].capabilities = .init(edition: "2024")
    try check(!RulesEngine.evaluate(b, in: p).isValid, "Unadapted editions must not mix")
    p.species[0].capabilities?.adapters = [.init(edition: "2014", canonicalID: "roadfolk-legacy", label: "Custom legacy adapter", replacementGrants: [.init(id: "adapted", kind: .trait, text: "Adapted")])]
    try check(RulesEngine.evaluate(b, in: p).isValid, "Explicit edition adapter should succeed")
    try check(RulesEngine.evaluate(b, in: p).traits.contains("Adapted"), "Adapter replacement grants must apply")
    p.capabilities?.required = ["future-combat"]
    do { try PackValidator.validate(p); throw CheckError.failed("Required unknown capability was accepted") } catch is CheckError { throw CheckError.failed("Required unknown capability was accepted") } catch {}
}

func capabilityCastingChecks() throws {
    for mode in [CastingPolicy.Mode.known, .prepared, .book, .limited, .ritual, .atWill] {
        var p = try ContentPack.sample(); p.schemaVersion = 2; p.capabilities = .init()
        p.classes[0].capabilities = .init(edition: "2024", casting: [.init(id: "spell-policy", name: "Original policy", mode: mode, ability: .int, spellIDs: ["sheltering-glow", "borrowed-dawn"], counts: [1, 1, 1, 1, 1], maximumSpellLevels: [1, 1, 1, 1, 1], preparedCounts: [1, 1, 1, 1, 1])])
        var b = try FolioCoreTests().valid(); b.rulesProfile = .init(edition: "2024")
        b.levels[0].capabilities = .init(spells: ["spell-policy": ["sheltering-glow"]], prepared: ["spell-policy": ["sheltering-glow"]])
        try check(RulesEngine.evaluate(b, in: p).isValid, "Policy must validate: \(mode)")
        b.levels[0].capabilities?.spells = ["spell-policy": ["keeper-call"]]
        try check(!RulesEngine.evaluate(b, in: p).isValid, "Policy must reject off-list spells")
    }
}

func capabilityBoundaryChecks() throws {
    var p = try ContentPack.sample(); p.schemaVersion = 2; p.capabilities = .init()
    let prerequisite = CapabilityOption(id: "root", name: "Root", prerequisite: .init(.level, minimum: 3), grants: [.init(id: "root-speed", kind: .speed, value: .init(base: 10))])
    let dependent = CapabilityOption(id: "child", name: "Child", prerequisite: .init(.selection, key: "root"), grants: [.init(id: "child-speed", kind: .speed, value: .init(base: 20))])
    p.classes[0].capabilities = .init(edition: "2024", groups: [.init(id: "chain", name: "Chain", counts: [2,2,2,2,2], options: [prerequisite, dependent])])
    var b = try FolioCoreTests().valid(); b.rulesProfile = .init(edition: "2024"); b.levels[0].capabilities = .init(groups: ["chain": ["root", "child"]])
    let summary = RulesEngine.evaluate(b, in: p)
    try check(summary.speed == 30, "A dependent of an illegal selection must not grant statistics")
    b.levels[0].capabilities?.spells = ["unknown": ["sheltering-glow"]]
    try check(RulesEngine.evaluate(b, in: p).issues.contains { $0.code == "cap-casting-policy" }, "Unknown casting policy must not disappear silently")
}

func capabilityLockedAndConditionChecks() throws {
    var p = try ContentPack.sample(); p.schemaVersion = 2; p.capabilities = .init()
    let root = CapabilityOption(id: "limb", name: "Limb", grants: [.init(id: "limb-trait", kind: .trait, text: "A manifested limb")])
    let other = CapabilityOption(id: "sense", name: "Sense")
    var bonus = CapabilityChoiceGroup(id: "bonus", name: "Locked bonus", counts: [1,1,1,1,1], options: [root, other], locked: true)
    bonus.requiredOptionID = "limb"
    var archon = CapabilityConfiguration(id: "archon", name: "Archon")
    archon.prerequisite = .init(.configuration, key: "mantle")
    p.classes[0].capabilities = .init(edition: "2024", groups: [.init(id: "main", name: "Main", counts: [1,1,1,1,1], options: [root, other]), bonus], configurations: [.init(id: "mantle", name: "Mantle"), archon])
    var b = try FolioCoreTests().valid(); b.rulesProfile = .init(edition: "2024")
    b.levels[0].capabilities = .init(groups: ["main": ["sense"], "bonus": ["limb"]], configurations: ["archon"])
    try check(RulesEngine.evaluate(b, in: p).issues.contains { $0.code == "cap-configuration-archon" }, "Archon configuration must imply mantle")
    b.levels[0].capabilities?.configurations = ["archon", "mantle"]
    try check(RulesEngine.evaluate(b, in: p).isValid, "Required locked grant should succeed")
    b.levels[0].capabilities?.groups = ["main": ["limb"], "bonus": ["sense"]]
    try check(RulesEngine.evaluate(b, in: p).isValid, "Already-owned mandatory option permits an alternative")
    b.levels[0].capabilities?.groups = ["main": ["sense"], "bonus": ["sense"]]
    try check(RulesEngine.evaluate(b, in: p).issues.contains { $0.code == "cap-required-bonus" }, "Bonus cannot evade mandatory grant")
}

func capabilityHistoricalChecks() throws {
    var p = try ContentPack.sample(); p.schemaVersion = 2; p.capabilities = .init()
    p.classes[0].capabilities = .init(edition: "2024")
    p.classes[0].subclasses[0].capabilities = .init(edition: "2024", groups: [.init(id: "sub-choice", name: "Subclass training", counts: [1,1,1,1,1], options: [.init(id: "sub-option", name: "Training")])])
    var b = try FolioCoreTests().valid(3); b.rulesProfile = .init(edition: "2024")
    b.levels[2].capabilities = .init(groups: ["sub-choice": ["sub-option"]])
    try check(RulesEngine.evaluate(b, in: p).isValid, "Subclass choices must not be required before subclass unlock")
    p.classes[0].capabilities?.grants = [.init(id: "defense-plus", kind: .armorBonus, value: .init(base: 2)), .init(id: "defense-base", kind: .armorFormula, value: .init(base: 17))]
    try check(RulesEngine.evaluate(b, in: p).armorClass == 19, "Armor formulas resolve before additive bonuses regardless of declaration order")
}

func capabilityCopyAndBoundsChecks() throws {
    let original = CharacterRecord(pack: try ContentPack.sample(), build: try FolioCoreTests().valid(3))
    let copy = try RulesUpgrade.copy(original)
    try check(copy.id != original.id && copy.build.levels == original.build.levels && copy.build.backstory == original.build.backstory && copy.build.portrait == original.build.portrait, "Upgrade must copy identity and preserve decisions and story")
    try check(original.build.rulesProfile == nil && original.pack.schemaVersion == 1, "Original must stay untouched")
    try check(!RulesEngine.evaluate(copy.build, in: copy.pack).isValid, "Upgrade differences require review")
    var malformed = copy; malformed.build.rulesProfile?.evaluator = 999
    var rejected = false
    do { try PackValidator.validateRecord(malformed) } catch { rejected = true }
    try check(rejected, "Unsupported pinned evaluator must be rejected at persistence boundary")
}
