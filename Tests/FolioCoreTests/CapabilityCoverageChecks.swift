import Foundation
import FolioCore

func capabilityFamilyMatrixChecks() throws {
    let sample = try ContentPack.capabilitySample()
    let families = ["barbarian","bard","cleric","druid","fighter","monk","paladin","ranger","rogue","sorcerer","warlock","wizard","artificer"]
    for family in families {
        try check(sample.classes.contains { $0.id == "lab-" + family }, "Missing registered original \(family) mechanism scenario")
        for edition in ["2014","2024"] {
            var p = sample
            let index = p.classes.firstIndex { $0.id == "lab-" + family }!
            // Separate original edition fixtures, not implicit adaptation of real content.
            p.ruleset = edition; p.classes[index].capabilities?.edition = edition
            let cls = p.classes[index], caps = cls.capabilities!
            var b = try FolioCoreTests().valid(5); b.classID = cls.id; b.rulesProfile = .init(edition: edition)
            if edition == "2014" { b.backgroundBoosts = [:]; b.languages = [] }
            for i in b.levels.indices {
                b.levels[i].talentIDs = []; b.levels[i].spellIDs = []; b.levels[i].cantripIDs = []
                let groups = Dictionary(uniqueKeysWithValues: (caps.groups ?? []).map { group in (group.id, Array(group.options.prefix(group.count(at: i+1))).map(\.id)) })
                let spells = Dictionary(uniqueKeysWithValues: (caps.casting ?? []).map { policy in (policy.id, Array(policy.spellIDs.prefix(policy.counts[i]))) })
                let prepared = Dictionary(uniqueKeysWithValues: (caps.casting ?? []).filter { $0.mode == .book }.map { ($0.id, Array($0.spellIDs.prefix($0.preparedCounts![i]))) })
                b.levels[i].capabilities = .init(groups: groups, configurations: [family + "-active"], spells: spells, prepared: prepared)
            }
            let s = RulesEngine.evaluate(b, in: p)
            try check(s.isValid, "\(family) \(edition) fixture must be mechanically valid: \(s.issues)")
            let cha = Ability.modifier(s.scores["cha"]!), dex = Ability.modifier(s.scores["dex"]!), con = Ability.modifier(s.scores["con"]!), wis = Ability.modifier(s.scores["wis"]!)
            func capacity(_ name: String, _ value: Int) throws { try check(s.resources.contains { $0.name == name && $0.maximum == value }, "\(family) \(name) capacity must equal \(value)") }
            switch family {
            case "barbarian":
                try capacity("resolve",2); try check(s.armorClass == 10+dex+con && s.skillModifiers["Athletics"] == cha, "Rage-family conditional defense and substitution")
            case "bard":
                try capacity("inspiration",3); try check(s.proficiencyRanks["Arcana"] == .expertise && s.proficiencyRanks["Performance"] == .proficient && s.skillModifiers["Athletics"] == 1, "Expertise, extra training and rounded-down half proficiency")
                var cross = b; cross.levels[4].capabilities?.spells?[family+"-casting"] = ["keeper-call"]
                try check(RulesEngine.evaluate(cross, in: p).isValid, "Explicit cross-list spell access")
            case "cleric", "druid":
                try capacity("channel",2); try check(s.proficiencyRanks["History"] == .proficient && s.grantedSpellIDs.contains("keeper-call") && s.spellLabels["sheltering-glow"] == "Prepared", "Order, preparation and additional grants")
                var swapped = b; swapped.levels[4].capabilities?.spells?[family+"-casting"] = ["borrowed-dawn"]
                try check(RulesEngine.evaluate(swapped, in: p).isValid, "Preparation changes do not spend known replacement charges")
            case "fighter": try capacity("surge",1); try capacity("recovery",2); try check(s.armorClass == 13, "Conditional fighting style AC")
            case "monk":
                try capacity("focus",5); try check(s.armorClass == 10+dex+wis && s.speed == 40 && s.traits.contains("Focus die sides: 6") && RulesEngine.evaluate(b, in:p, through:2).traits.contains("Focus die sides: 4"), "Unarmed focus defense, movement and die progression")
                try check(!RulesEngine.evaluate(b, in:p, through:2).traits.contains { $0.contains("d6") }, "Low-level focus die facts must not contradict calculated four sides")
            case "paladin":
                try capacity("healing",25); try capacity("channel",1)
                var alternative = b
                for i in alternative.levels.indices { alternative.levels[i].capabilities?.groups?[family+"-style"] = [family+"-cantrips"] }
                let alternate = RulesEngine.evaluate(alternative, in: p)
                try check(alternate.isValid && alternate.grantedSpellIDs.contains("little-beacon") && alternate.armorClass == 12, "Style versus cantrip alternative removes the old defense")
            case "ranger", "rogue": try check(s.proficiencyRanks["Arcana"] == .expertise && s.languages.contains("Road Cant"), "Expertise and calculated language grant")
            case "sorcerer": try capacity("sorcery",5); try check(s.armorClass == 15 && s.hitPoints == (edition == "2024" ? 48 : 38) && s.grantedSpellIDs.contains("keeper-call"), "Draconic-family HP, defense and subclass grants")
            case "warlock":
                try check(s.speed == 40 && s.proficiencyRanks["History"] == .proficient, "Prerequisite invocation and pact choice")
                try capacity("limited-casts",1)
                try check(s.spellLabels["little-beacon"] == "At will (granted)" && s.spellLabels["keeper-circle"] == "Limited use (granted)", "Declared at-will and independently limited access")
                var orphan = b; orphan.levels[4].capabilities?.groups?[family+"-invocations"] = [family+"-dependent",family+"-repeat"]
                try check(RulesEngine.evaluate(orphan, in: p).issues.contains { $0.code == "cap-prerequisite-warlock-dependent" }, "Removing prerequisite invalidates the dependent invocation")
                var repeated = b
                for i in repeated.levels.indices { repeated.levels[i].capabilities?.groups?[family+"-invocations"] = Array(repeating: family+"-repeat", count: i == 0 ? 1 : 2) }
                try check(RulesEngine.evaluate(repeated, in: p).speed == 40, "Repeatable invocation grants stack per occurrence")
            case "wizard":
                try check(s.proficiencyRanks["Arcana"] == .expertise && s.spellLabels["sheltering-glow"] == "Prepared (book)" && s.spellLabels["borrowed-dawn"] == "Spellbook", "Acquired book and preparation are distinct")
                var outside = b; outside.levels[4].capabilities?.prepared?[family+"-casting"] = ["keeper-call"]
                try check(!RulesEngine.evaluate(outside, in: p).isValid, "Preparation cannot escape acquired book")
            case "artificer":
                try check(s.traits.contains { $0.contains("Dependent item recipe") } && s.spellLabels["sheltering-glow"] == "Prepared", "Original item recipe prerequisite and declared casting policy")
                var orphan = b; orphan.levels[4].capabilities?.groups?[family+"-recipes"] = [family+"-advanced"]
                try check(!RulesEngine.evaluate(orphan, in: p).isValid, "Advanced recipe cannot outlive its prerequisite")
            default: break
            }
            var inactive = b; inactive.levels[4].capabilities?.configurations = []
            let off = RulesEngine.evaluate(inactive, in: p)
            if ["barbarian","fighter","monk","sorcerer"].contains(family) { try check(off.armorClass == 12, "\(family) conditional defense removal") }
            try check(RulesEngine.evaluate(b, in: p).hitPoints == s.hitPoints, "\(family) repeat evaluation does not accumulate modifiers")
            if let policy = caps.casting?.first {
                var invalid = b; invalid.levels[4].capabilities?.spells?[policy.id] = ["lantern-bridge"]
                try check(!RulesEngine.evaluate(invalid, in: p).isValid, "\(family) policy rejects outside-list spells")
            }
        }
    }
}

func capabilityBonusFamilyAlternativeChecks() throws {
    var p = try ContentPack.sample(); p.schemaVersion = 2; p.capabilities = .init()
    let options = [CapabilityOption(id: "presence-a", name: "First presence"), .init(id: "presence-b", name: "Second presence"), .init(id: "other", name: "Other")]
    let json = """
    {"id":"bonus","name":"Bonus","counts":[1],"options":[],"locked":true,"requiredOptionIDs":["presence-a","presence-b"],"waiveRequiredFamilyIfOwned":true}
    """
    var bonus = try JSONDecoder().decode(CapabilityChoiceGroup.self, from: Data(json.utf8)); bonus.options = options
    p.classes[0].capabilities = .init(edition: "2024", groups: [.init(id: "main", name: "Main", counts: [1], options: options), bonus])
    var b = try FolioCoreTests().valid(); b.rulesProfile = .init(edition: "2024")
    b.levels[0].capabilities = .init(groups: ["main": ["presence-a"], "bonus": ["other"]])
    try check(RulesEngine.evaluate(b, in: p).isValid, "An already-owned family member permits a distinct general alternative")
    b.levels[0].capabilities?.groups = ["main": ["other"], "bonus": ["other"]]
    try check(RulesEngine.evaluate(b, in: p).issues.contains { $0.code == "cap-required-family-bonus" }, "No owned family means the required family remains mandatory")
    b.levels[0].capabilities?.groups = ["main": ["presence-a"], "bonus": ["presence-a"]]
    try check(RulesEngine.evaluate(b, in: p).issues.contains { $0.code == "cap-duplicate-presence-a" }, "Family waiver does not permit the same variant twice")
}

func capabilityMovementBaseChecks() throws {
    var p = try ContentPack.sample(); p.schemaVersion = 2; p.capabilities = .init()
    let json = """
    {"id":"form-speed","kind":"speedBase","value":{"base":40},"condition":{"kind":"configuration","key":"form"}}
    """
    let replacement = try JSONDecoder().decode(CapabilityGrant.self, from: Data(json.utf8))
    p.classes[0].capabilities = .init(edition: "2024", grants: [replacement, .init(id: "slow", kind: .speed, value: .init(base: -10), condition: .init(.configuration, key: "form"))], configurations: [.init(id: "form", name: "Form")])
    var b = try FolioCoreTests().valid(); b.rulesProfile = .init(edition: "2024")
    b.levels[0].capabilities = .init(configurations: ["form"])
    try check(RulesEngine.evaluate(b, in: p).speed == 30, "Form base speed replaces species speed before additive reductions")
    b.levels[0].capabilities?.configurations = []
    try check(RulesEngine.evaluate(b, in: p).speed == 30, "Removing form restores species speed")
}

func capabilitySelectedCoverageChecks() throws {
    let original = try ContentPack.sample()
    var unrelated = try ContentPack.sample(); unrelated.id = "unrelated"; unrelated.name = "Unrelated source"
    unrelated.coverageNotes = ["Unrelated subclass restriction"]
    let catalog = try ContentCatalog(packs: [original, unrelated])
    let record = CharacterRecord(pack: original, build: try FolioCoreTests().valid())
    let expanded = try catalog.addingChoices(to: record)
    let notes = PrintableSheet(record: expanded).supplements.first { $0.title == "Reading this sheet" }!.text
    try check(!notes.contains("Unrelated subclass restriction"), "Unselected source restrictions must not describe this build")
    try check(notes.contains(original.coverageNotes[0]), "Selected source diagnostics remain visible")
}

func capabilityFormSizeChecks() throws {
    var p = try ContentPack.sample(); p.schemaVersion = 2; p.capabilities = .init()
    let json = """
    {"id":"form-size","kind":"size","target":"Large","condition":{"kind":"configuration","key":"form"}}
    """
    let form = try JSONDecoder().decode(CapabilityGrant.self, from: Data(json.utf8))
    p.classes[0].capabilities = .init(edition: "2024", grants: [form], configurations: [.init(id: "form", name: "Form")])
    var b = try FolioCoreTests().valid(); b.rulesProfile = .init(edition: "2024"); b.levels[0].capabilities = .init(configurations: ["form"])
    try check(PrintableSheet(record: .init(pack: p, build: b)).fields["size"] == "Large", "Active form size overrides species size in the actual sheet field")
    b.levels[0].capabilities?.configurations = []
    try check(PrintableSheet(record: .init(pack: p, build: b)).fields["size"] == "Medium", "Removing form restores species size")
}

func capabilityComputedTraitChecks() throws {
    var p = try ContentPack.sample(); p.schemaVersion = 2; p.capabilities = .init()
    p.classes[0].capabilities = .init(edition: "2024", grants: [.init(id: "count", kind: .trait, value: .init(abilities: [.cha], minimum: 0), text: "Declared limbs")])
    var b = try FolioCoreTests().valid(5); b.rulesProfile = .init(edition: "2024")
    try check(RulesEngine.evaluate(b, in: p).traits.contains("Declared limbs: 4"), "Numeric traits resolve from current ability scores")
}

func capabilityAdditionalSpellGrantChecks() throws {
    var p = try ContentPack.sample(); p.schemaVersion = 2; p.capabilities = .init()
    p.classes[0].capabilities = .init(edition: "2024", grants: [.init(id: "additional", kind: .spell, target: "sheltering-glow")], casting: [.init(id: "prepare", name: "Prepare", mode: .prepared, ability: .cha, spellIDs: ["sheltering-glow","borrowed-dawn"], counts: [1], maximumSpellLevels: [1])])
    var b = try FolioCoreTests().valid(); b.rulesProfile = .init(edition: "2024"); b.levels[0].capabilities = .init(spells: ["prepare": ["sheltering-glow"]])
    try check(!RulesEngine.evaluate(b, in: p).isValid, "An additional grant cannot consume a required preparation choice")
    b.levels[0].capabilities?.spells = ["prepare": ["borrowed-dawn"]]
    try check(RulesEngine.evaluate(b, in: p).isValid, "Preparation plus a distinct additional grant is valid")
    let json = """
    {"id":"additional","kind":"spell","target":"sheltering-glow","spellMode":"prepared"}
    """
    p.classes[0].capabilities?.grants = [try JSONDecoder().decode(CapabilityGrant.self, from: Data(json.utf8))]
    try check(RulesEngine.evaluate(b, in: p).spellLabels["sheltering-glow"] == "Prepared (granted)", "Always-prepared grants preserve preparation classification without spending picks")
}

func capabilityAcquisitionRequirementChecks() throws {
    var p = try ContentPack.sample(); p.schemaVersion = 2; p.capabilities = .init()
    let options = [CapabilityOption(id: "family", name: "Family"), .init(id: "alternate", name: "Alternate"), .init(id: "later", name: "Later")]
    let json = """
    {"id":"bonus","name":"Bonus","counts":[0,0,1,1],"options":[],"locked":true,"requiredOptionID":"family","requirementTiming":"acquisition"}
    """
    var bonus = try JSONDecoder().decode(CapabilityChoiceGroup.self, from: Data(json.utf8)); bonus.options = options
    p.classes[0].capabilities = .init(edition: "2024", groups: [.init(id: "main", name: "Main", counts: [1,1,1,1], options: options, replacementLimits: [0,1,0,1]), bonus])
    var b = try FolioCoreTests().valid(4); b.rulesProfile = .init(edition: "2024")
    for i in b.levels.indices { b.levels[i].capabilities = .init(groups: i < 2 ? ["main":["family"]] : ["main":[i == 3 ? "later" : "family"],"bonus":["alternate"]]) }
    try check(RulesEngine.evaluate(b, in: p).isValid, "Acquisition-time alternative remains valid after original family is legally replaced")
    for i in 0...2 { b.levels[i].capabilities?.groups?["main"] = ["later"] }
    try check(RulesEngine.evaluate(b, in: p).issues.contains { $0.code == "cap-required-bonus" && $0.level == 3 }, "Earlier edits still invalidate the historical acquisition waiver")
}

func capabilityTrackExclusivityChecks() throws {
    var p = try ContentPack.sample(); p.schemaVersion = 2; p.capabilities = .init()
    let options = [CapabilityOption(id: "first", name: "First", grants: [.init(id: "first-training", kind: .proficiency, target: "History", rank: .proficient)], exclusiveGroup: "family"), .init(id: "second", name: "Second", grants: [.init(id: "second-training", kind: .proficiency, target: "Performance", rank: .proficient)], exclusiveGroup: "family")]
    let json = """
    {"id":"bonus","name":"Specific bonus","counts":[1],"options":[],"exclusiveGroupExceptions":["family"]}
    """
    var bonus = try JSONDecoder().decode(CapabilityChoiceGroup.self, from: Data(json.utf8)); bonus.options = options
    let main = CapabilityChoiceGroup(id: "main", name: "Main", counts: [1], options: options)
    p.classes[0].capabilities = .init(edition: "2024", groups: [main, bonus])
    var b = try FolioCoreTests().valid(); b.rulesProfile = .init(edition: "2024"); b.levels[0].capabilities = .init(groups: ["main":["first"], "bonus":["second"]])
    var summary = RulesEngine.evaluate(b, in:p)
    try check(summary.isValid && summary.proficiencyRanks["History"] == .proficient && summary.proficiencyRanks["Performance"] == .proficient, "Explicit track exception permits distinct cross-track family variants")
    p.classes[0].capabilities?.groups = [bonus, main]
    try check(RulesEngine.evaluate(b, in:p).isValid, "Track exception semantics are independent of group ordering")
    // An otherwise identical track without the explicit exception must remain restricted.
    let plain = CapabilityChoiceGroup(id: "ordinary", name: "Ordinary bonus", counts: [1], options: options)
    p.classes[0].capabilities?.groups = [main, plain]
    b.levels[0].capabilities?.groups = ["main":["first"], "ordinary":["second"]]
    summary = RulesEngine.evaluate(b, in:p)
    try check(!summary.isValid && summary.proficiencyRanks["Performance"] != .proficient, "Ordinary bonus cannot leak the rejected family's training")
    bonus.counts = [2]; p.classes[0].capabilities?.groups = [bonus]
    b.levels[0].capabilities?.groups = ["bonus":["first","second"]]
    try check(!RulesEngine.evaluate(b, in:p).isValid, "Exception does not permit two variants within its own track")
    bonus.counts = [1]; p.classes[0].capabilities?.groups = [main,bonus]
    b.levels[0].capabilities?.groups = ["main":["first"],"bonus":["first"]]
    try check(RulesEngine.evaluate(b, in:p).issues.contains { $0.code == "cap-duplicate-first" }, "Exception never overrides canonical duplicate ownership")
    let catalog = try ContentCatalog(packs: [p])
    let snapshot = try catalog.snapshot(for: catalog.classes[0].id)
    let qualified = snapshot.classes[0].capabilities!.groups!.first { $0.name == "Specific bonus" }!
    try check(qualified.exclusiveGroupExceptions == [qualified.options[0].exclusiveGroup!] && qualified.exclusiveGroupExceptions != ["family"], "Catalog qualifies exception family identities alongside option families")
    var invalid = p; invalid.classes[0].capabilities?.groups?[1].exclusiveGroupExceptions = ["missing"]
    var rejected = false; do { try PackValidator.validate(invalid) } catch { rejected = true }
    try check(rejected, "An exception must name an actual option family in its own track")
}
