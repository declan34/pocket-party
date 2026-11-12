import Foundation
import FolioCore

func vesselCapabilityChecks() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let url = root.appendingPathComponent("PrivatePacks/vessel-pack.json")
    guard FileManager.default.fileExists(atPath: url.path) else {
        print("SKIP vesselCapabilityChecks: PrivatePacks/vessel-pack.json is absent")
        return
    }
    let pack = try PackValidator.decode(Data(contentsOf: url))
    try check(pack.schemaVersion == 2, "Private Vessel must use explicit capability contracts")
    try check(Set(pack.classes[0].subclasses.map(\.id)) == Set(["the-ascended", "the-cataclysm", "the-cursed", "the-fallen", "the-formless", "the-trickster"]), "All six supplied Vessel subclasses must be represented")
    let cls = pack.classes[0]
    let cantrips = cls.capabilities!.casting!.first { $0.id == "vessel-cantrips" }!.spellIDs.filter { id in pack.spells.contains { $0.id == id && $0.unavailableReason == nil } }
    let additional = Set(cls.subclasses.flatMap { ($0.capabilities?.grants ?? []).filter { $0.kind == .spell }.compactMap(\.target) })
    let known = cls.capabilities!.casting!.first { $0.id == "vessel-known" }!.spellIDs.filter { id in !additional.contains(id) && pack.spells.contains { $0.id == id && $0.level == 1 && $0.unavailableReason == nil } }
    func build(_ subclass: String, level: Int = 5, affinity: String = "earth", primary: String = "uncanny-strength", bonus: String? = nil) -> CharacterBuild {
        var b = CharacterBuild(classID: cls.id); b.rulesProfile = .init(edition: "2024")
        b.name = "Private acceptance"; b.speciesID = "dwarf"; b.backgroundID = "farmer"
        b.backgroundBoosts = ["con":2,"wis":1]; b.classSkills = ["Acrobatics","Religion"]; b.languages = ["Elvish","Dwarvish"]
        b.levels = (1...level).map { at in
            var row = LevelChoice(level: at)
            var options = [primary]; if at >= 2 { options.append("spirit-sense") }; if at >= 4 { options.append("iridescent-shield") }
            var groups = ["aspects": options]
            if at >= 3 {
                row.subclassID = subclass
                if subclass == "the-cataclysm" { groups["affinity"] = ["affinity-" + affinity] }
                if subclass == "the-cursed" { groups["cursed-bonus"] = [bonus ?? "striking-presence-deception"] }
                if subclass == "the-formless" { groups["formless-bonus"] = [bonus ?? "ethereal-tendril"] }
            }
            let count = at == 1 ? 0 : at < 4 ? 2 : 3
            let policy = at >= 3 && subclass == "the-ascended" ? "ascended-prepared" : "vessel-known"
            row.capabilities = .init(groups: groups, configurations: ["no-armor-shield", at >= 3 ? "archon" : "cloak"], spells: ["vessel-cantrips": Array(cantrips.prefix(count)), policy: Array(known.prefix(count))])
            if at == 4 { row.featID = "ability-improvement"; row.boosts = ["con":1,"cha":1] }
            return row
        }
        return b
    }
    var ordinaryPresence = build("the-trickster", level: 2, primary: "striking-presence-deception")
    ordinaryPresence.levels[1].capabilities?.groups?["aspects"] = ["striking-presence-deception", "striking-presence-intimidation"]
    try check(!RulesEngine.evaluate(ordinaryPresence, in: pack).isValid, "Ordinary Aspect purchases cannot acquire two Presence variants")
    let cursedPresence = build("the-cursed", level: 3, primary: "striking-presence-deception", bonus: "striking-presence-intimidation")
    try check(RulesEngine.evaluate(cursedPresence, in: pack).isValid, "Only Cursed bonus explicitly permits a second distinct Presence variant")
    var formlessPresence = build("the-formless", level: 3, primary: "ethereal-tendril", bonus: "striking-presence-intimidation")
    for i in 1...2 { formlessPresence.levels[i].capabilities?.groups?["aspects"] = ["ethereal-tendril", "striking-presence-deception"] }
    try check(!RulesEngine.evaluate(formlessPresence, in: pack).isValid, "Formless general alternative does not authorize a second Presence variant")
    let duplicatePresence = build("the-cursed", level: 3, primary: "striking-presence-deception", bonus: "striking-presence-deception")
    try check(RulesEngine.evaluate(duplicatePresence, in: pack).issues.contains { $0.code == "cap-duplicate-striking-presence-deception" }, "Cursed exception never duplicates the same canonical skill variant")
    for sub in cls.subclasses {
        let b = build(sub.id), result = RulesEngine.evaluate(b, in: pack)
        let profileLanguage = ["the-ascended":"Primordial", "the-cataclysm":"Terran", "the-cursed":"Infernal", "the-fallen":"Celestial", "the-formless":"Primordial", "the-trickster":"Sylvan"][sub.id]!
        try check(result.languages.contains(profileLanguage) && !pack.languages.contains(profileLanguage), "Actual profile language must calculate without expanding standard creation choices")
        var languageInactive = b; languageInactive.levels[4].capabilities?.configurations = ["no-armor-shield"]
        try check(!RulesEngine.evaluate(languageInactive, in: pack).languages.contains(profileLanguage), "Removing actual Archon configuration must remove its conditional language")
        try check(PrintableSheet(record: .init(pack: pack, build: b)).fields["languages"]?.contains(profileLanguage) == true, "Actual profile language must reach PDF projection")
        let expectedBlocked = ["the-cataclysm","the-cursed","the-fallen"].contains(sub.id)
        try check(result.issues.allSatisfy { $0.code.hasPrefix("cap-grant-source-") }, "Unexpected \(sub.id) mechanics issues: \(result.issues)")
        try check(result.isValid != expectedBlocked, "Only actual unresolved source grants block \(sub.id)")
        try check(result.hitPoints == 64 && result.slots == 2 && result.slotLevel == 2, "Actual \(sub.id) HP and pool remain correct")
        try check(result.resources.contains { $0.id == "archon-uses" && $0.maximum == 1 }, "Archon free-use capacity")
        try check(result.skillModifiers["Athletics"] == 6, "Archon implies cloak and conditional Charisma substitution")
        var uncloaked = b; uncloaked.levels[4].capabilities?.configurations = []
        let inactive = RulesEngine.evaluate(uncloaked, in: pack)
        try check(inactive.proficiencyRanks["Athletics"] == .proficient && inactive.skillModifiers["Athletics"] == Ability.modifier(inactive.scores["str"]!) + 3, "Uncanny proficiency remains, conditional substitution ends")
        try check(inactive.spells.map(\.id) == result.spells.map(\.id), "Removing cloak never deletes acquired spells")
        try check(RulesEngine.evaluate(b, in: pack, through: 2).resources.isEmpty, "Archon capacity is not available before subclass unlock")
    }
    for (affinity, speed, bonus) in [("air",20,0),("earth",30,2),("fire",40,0),("water",30,0)] {
        let result = RulesEngine.evaluate(build("the-cataclysm", affinity: affinity), in: pack)
        let language = ["air":"Auran", "earth":"Terran", "fire":"Ignan", "water":"Aquan"][affinity]!
        try check(result.languages.contains(language) && result.languages.filter { ["Auran","Terran","Ignan","Aquan"].contains($0) }.count == 1, "Actual affinity must grant only its own source language")
        try check(result.speed == speed && result.armorClass == 16 + bonus, "Actual \(affinity) profile movement/AC")
        try check(result.grantedSpellIDs.contains("spell.absorb-elements") && result.grantedSpellIDs.contains("spell.elemental-blade"), "Shared affinity grants retained")
        if affinity == "fire" { try check(result.grantedSpellIDs.contains("spell.flaming-sphere") && result.grantedSpellIDs.contains("spell.misty-step"), "Both source Fire-5 grants survive manifest conversion") }
        if affinity != "fire" { try check(!result.grantedSpellIDs.contains("spell.flaming-sphere"), "Other affinities cannot leak Fire spells") }
    }
    let ascended = RulesEngine.evaluate(build("the-ascended"), in: pack)
    try check(ascended.spellLabels["spell.shield"] == "Prepared (granted)", "Actual Ascended always-prepared classification")
    try check(ascended.spells.contains { $0.id == "spell.locate-creature" && $0.level == 4 } && ascended.slotLevel == 2, "Grant access never downgrades Locate Creature or invents slots")
    let preparation = cls.subclasses.first { $0.id == "the-ascended" }!.capabilities!.casting![0]
    let wizardOnly = preparation.spellIDs.first { id in !cls.spellIDs.contains(id) && !additional.contains(id) && pack.spells.contains { $0.id == id && $0.level == 1 } }
    try check(wizardOnly != nil, "Verified Wizard list adds cross-list eligibility")
    var prepared = build("the-ascended", level: 3)
    prepared.levels[2].capabilities?.spells?["ascended-prepared"] = [wizardOnly!,known[1]]
    try check(RulesEngine.evaluate(prepared, in: pack).isValid, "Actual Wizard-only selection is accepted by Ascended preparation")
    prepared.levels[2].capabilities?.spells?["ascended-prepared"] = ["spell.shield",known[1]]
    try check(RulesEngine.evaluate(prepared, in: pack).issues.contains { $0.code == "cap-casting-granted-spell.shield" }, "Ascended always-prepared Shield does not consume preparation")
    var form = build("the-formless"); form.speciesID = "halfling"
    let formSummary = RulesEngine.evaluate(form, in: pack)
    try check(formSummary.size == "Medium" && PrintableSheet(record: .init(pack: pack, build: form)).fields["size"] == "Medium", "Actual Archon size overrides a Small species in sheet projection")
    try check(formSummary.traits.contains("Additional pseudopods: 3"), "Actual Formless pseudopods resolve Charisma")
    form.levels[4].capabilities?.configurations = ["archon"]
    try check(RulesEngine.evaluate(form, in: pack).armorClass == 12, "Archon bonus cannot leak when no-armor/no-shield condition is undeclared")
    form = build("the-formless"); form.levels[3].capabilities?.groups?["aspects"] = ["uncanny-strength","spirit-sense","opalescent-armor"]
    let fortifiedGroups = form.levels[3].capabilities?.groups
    form.levels[4].capabilities?.groups = fortifiedGroups
    form.levels[4].capabilities?.configurations = ["archon","no-armor-shield","fortified"]
    let fortified = RulesEngine.evaluate(form, in: pack)
    try check(fortified.isValid && fortified.speed == 20 && fortified.traits.contains("climb speed (ft): 20"), "Optional fortification reduces actual form movement")
    for skill in ["deception","intimidation","persuasion"] {
        let result = RulesEngine.evaluate(build("the-cursed", level: 3, bonus: "striking-presence-" + skill), in: pack)
        try check(result.isValid, "Cursed canonical skill variant \(skill) is valid: \(result.issues)")
    }
    try check(RulesEngine.evaluate(build("the-cursed", level: 3, primary: "striking-presence-deception", bonus: "ethereal-tendril"), in: pack).isValid, "Already-owned Presence permits general alternate Aspect")
    try check(!RulesEngine.evaluate(build("the-cursed", level: 3, bonus: "ethereal-tendril"), in: pack).isValid, "No Presence ownership cannot bypass mandatory family")
    try check(RulesEngine.evaluate(build("the-formless", level: 3, primary: "ethereal-tendril", bonus: "uncanny-strength"), in: pack).isValid, "Formless already-owned Tendril permits eligible alternative")
    for (subclass, original, bonus) in [("the-formless","ethereal-tendril","uncanny-strength"),("the-cursed","striking-presence-deception","ethereal-tendril")] {
        var acquired = build(subclass, level: 4, primary: original, bonus: bonus)
        acquired.levels[3].capabilities?.groups?["aspects"] = ["vexing-strike","spirit-sense","iridescent-shield"]
        try check(RulesEngine.evaluate(acquired, in: pack).isValid, "Actual \(subclass) acquisition alternative survives later replacement of original purchased Aspect")
        for i in 0...2 { acquired.levels[i].capabilities?.groups?["aspects"] = i == 0 ? ["uncanny-strength"] : ["uncanny-strength","spirit-sense"] }
        try check(!RulesEngine.evaluate(acquired, in: pack).isValid, "Earlier \(subclass) edit invalidates original alternate acquisition")
    }
    var illegal = build("the-formless"); illegal.levels[4].capabilities?.groups?["formless-bonus"] = ["vexing-strike"]
    try check(RulesEngine.evaluate(illegal, in: pack).issues.contains { $0.code == "cap-replacement-formless-bonus" }, "Locked subclass bonus cannot be replaced")
    illegal = build("the-trickster"); illegal.levels[2].capabilities?.groups?["aspects"] = ["uncanny-strength","vexing-strike"]
    try check(RulesEngine.evaluate(illegal, in: pack).issues.contains { $0.code == "cap-replacement-aspects" && $0.level == 3 }, "Aspects cannot replace on a non-acquisition level")
    illegal = build("the-trickster", level: 3); illegal.levels[2].capabilities?.spells?["vessel-known"] = [known[2],known[1]]
    try check(RulesEngine.evaluate(illegal, in: pack).isValid, "One known-spell replacement per Vessel level")
    illegal.levels[2].capabilities?.spells?["vessel-cantrips"] = Array(cantrips.suffix(2))
    try check(RulesEngine.evaluate(illegal, in: pack).issues.contains { $0.code.hasPrefix("cap-casting-replacement") }, "Cantrip replacement remains disallowed")
    let unresolvedList = cls.spellIDs.compactMap { id in pack.spells.first { $0.id == id && $0.unavailableReason != nil } }
    try check(unresolvedList.count == 4 && unresolvedList.allSatisfy { $0.name.contains("(LL)") }, "LL-only class-list references remain distinct unavailable choices, not omissions or substitutions")
    var trickster = build("the-trickster")
    try check(RulesEngine.evaluate(trickster, in: pack).spellLabels["spell.disguise-self"]?.contains("At will") == true, "Actual Trickster cloak grants at-will classification")
    trickster.levels[4].capabilities?.configurations = []
    try check(RulesEngine.evaluate(trickster, in: pack).spellLabels["spell.disguise-self"] == "Granted", "Uncloaking removes free casting, not the permanent spell grant")
}
