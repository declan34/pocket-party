import Foundation
import FolioCore

func capabilityLanguageCreationChecks() throws {
    var pack = try ContentPack.sample(); pack.schemaVersion = 2; pack.ruleset = "2014"; pack.capabilities = .init()
    pack.classes[0].capabilities = .init(edition: "2014")
    var build = try FolioCoreTests().valid(); build.rulesProfile = .init(edition: "2014")
    build.backgroundBoosts = [:]; build.languages = []
    try check(RulesEngine.evaluate(build, in: pack).isValid, "2014 must not inherit universal two-language allocation")
    try check(PrintableSheet(record: .init(pack: pack, build: build)).fields["languages"] == "", "2014 must not invent automatic Common")
}

func capabilityLanguageContractChecks() throws {
    let data = Data(#"{"id":"original-tongue","kind":"language","target":"Road Cant"}"#.utf8)
    let grant = try JSONDecoder().decode(CapabilityGrant.self, from: data)
    var pack = try ContentPack.sample(); pack.schemaVersion = 2; pack.capabilities = .init()
    pack.classes[0].capabilities = .init(edition: "2024", grants: [grant])
    var build = try FolioCoreTests().valid(); build.rulesProfile = .init(edition: "2024")
    try check(PrintableSheet(record: .init(pack: pack, build: build)).fields["languages"]?.contains("Road Cant") == true, "Semantic granted languages must reach sheet projection")
    let legacy = try FolioCoreTests().valid()
    try check(RulesEngine.evaluate(legacy, in: ContentPack.sample()).languages == ["Common", "Elvish", "Dwarvish"], "Legacy language order and semantics stay unchanged")
    try check(RulesEngine.evaluate(build, in: pack).languages == ["Common", "Elvish", "Dwarvish", "Road Cant"], "2024 keeps Common and two standards plus fixed grants")
    build.languages = ["Elvish", "Road Cant"]
    try check(RulesEngine.evaluate(build, in: pack).issues.contains { $0.code == "languages" }, "Fixed exotic access must not authorize a standard creation selection")
    build.languages = ["Elvish", "Elvish"]
    try check(RulesEngine.evaluate(build, in: pack).issues.contains { $0.code == "languages" }, "Duplicate 2024 creation choices stay invalid")
    for target in ["", " ", String(repeating: "a", count: 121), "Road\nCant"] {
        pack.classes[0].capabilities?.grants?[0].target = target
        var rejected = false
        do { try PackValidator.validate(pack) } catch { rejected = true }
        try check(rejected, "Malformed language grants must fail import")
    }
}

func capabilityLanguageReplayChecks() throws {
    var pack = try ContentPack.capabilitySample()
    var build = try FolioCoreTests().valid(2); build.classID = "lab-2014-wayfarer"
    build.speciesID = "roadfolk-2014"; build.backgroundID = "guide-2014"
    build.rulesProfile = .init(edition: "2014"); build.backgroundBoosts = [:]; build.languages = []
    for i in build.levels.indices { build.levels[i].capabilities = .init(groups: ["guide-language": ["guide-language-0"]]) }
    var result = RulesEngine.evaluate(build, in: pack)
    try check(result.isValid && Set(result.languages) == ["Common", "Road Cant", "Harbor Speech"], "Original 2014 species grants and one background choice must produce exactly authored languages")
    try check(Set(PrintableSheet(record: .init(pack: pack, build: build)).fields["languages"]!.components(separatedBy: ", ")) == Set(result.languages), "PDF projection must use calculated languages")
    let catalog = try ContentCatalog(packs: [pack])
    let entry = catalog.classes.first { $0.name == "Old Road Wayfarer" }!
    let snapshot = try catalog.snapshot(for: entry.id)
    var qualified = build; qualified.classID = entry.id
    qualified.speciesID = snapshot.species.first { $0.name == "Old Roadfolk" }!.id
    let background = snapshot.backgrounds.first { $0.name == "Old Road Guide" }!
    qualified.backgroundID = background.id
    let group = background.capabilities!.groups![0]
    for i in qualified.levels.indices { qualified.levels[i].talentIDs = [snapshot.classes.first { $0.id == entry.id }!.talents.first { $0.name == "Listener" }!.id] }
    // Keep legacy class track choices source-qualified too.
    qualified.levels = [qualified.levels[0]]
    qualified.levels[0].capabilities = .init(groups: [group.id: [group.options[0].id]])
    let catalogResult = RulesEngine.evaluate(qualified, in: snapshot)
    try check(catalogResult.isValid && Set(catalogResult.languages) == Set(result.languages), "Source-qualified language groups retain semantics without qualifying language names")
    let cls = pack.classes.firstIndex { $0.id == build.classID }!
    pack.classes[cls].capabilities?.configurations = [.init(id: "form", name: "Form")]
    pack.classes[cls].capabilities?.grants = [
        .init(id: "later-harbor", kind: .language, target: "Harbor Speech", condition: .init(.configuration, key: "form"), level: 2),
        .init(id: "form-cant", kind: .language, target: "Mist Speech", condition: .init(.configuration, key: "form"), level: 2),
        .init(id: "duplicate-fixed-common", kind: .language, target: "Common")
    ]
    build.levels[1].capabilities?.configurations = ["form"]
    result = RulesEngine.evaluate(build, in: pack)
    try check(result.isValid && result.languages.filter { $0 == "Harbor Speech" }.count == 1, "Later fixed duplicate must not invalidate earlier learned language")
    try check(result.languages.contains("Mist Speech") && !RulesEngine.evaluate(build, in: pack, through: 1).languages.contains("Mist Speech"), "Conditional languages follow historical unlocks")
    try check(RulesEngine.evaluate(build, in: pack).languages == result.languages, "Repeated replay must not accumulate languages")
    build.levels[1].capabilities?.configurations = []
    result = RulesEngine.evaluate(build, in: pack)
    try check(result.isValid && result.languages.contains("Harbor Speech") && !result.languages.contains("Mist Speech"), "Form removal keeps learned overlap but removes only conditional language")
    build.levels[0].capabilities?.groups?["guide-language"] = ["guide-language-1"]
    try check(RulesEngine.evaluate(build, in: pack).issues.contains { $0.code == "cap-replacement-guide-language" }, "Earlier language edit must invalidate later locked replacement")
    build.levels[1].capabilities?.groups?["guide-language"] = ["missing-language"]
    try check(RulesEngine.evaluate(build, in: pack).issues.contains { $0.code == "cap-option-missing-language" }, "Unknown language choice must remain invalid")
    build.languages = ["Elvish"]
    try check(RulesEngine.evaluate(build, in: pack).issues.contains { $0.code == "cap-creation-languages" }, "Retained 2024 choices require explicit clearing, not silent conversion")
    let record = CharacterRecord(pack: pack, build: build)
    let restored = try LibraryStorage.decodeCharacter(LibraryStorage.encoder.encode(record))
    try check(restored.build.languages == ["Elvish"] && restored.build.levels[1].capabilities?.groups?["guide-language"] == ["missing-language"], "Incomplete language history survives save/export round trip")
}

func capabilityLanguageChoiceChecks() throws {
    var pack = try ContentPack.sample(); pack.schemaVersion = 2; pack.capabilities = .init()
    let language = CapabilityGrant(id: "road-cant", kind: .language, target: "Road Cant")
    let first = CapabilityOption(id: "first", name: "First", grants: [language])
    let second = CapabilityOption(id: "second", name: "Second", grants: [.init(id: "other-road-cant", kind: .language, target: "Road Cant")])
    var a = CapabilityChoiceGroup(id: "a", name: "A", counts: [1], options: [first])
    var b = CapabilityChoiceGroup(id: "b", name: "B", counts: [1], options: [second])
    a.languageChoices = true; b.languageChoices = true
    pack.classes[0].capabilities = .init(edition: "2024", groups: [a,b])
    var build = try FolioCoreTests().valid(); build.rulesProfile = .init(edition: "2024")
    build.levels[0].capabilities = .init(groups: ["a": ["first"], "b": ["second"]])
    try check(RulesEngine.evaluate(build, in: pack).issues.contains { $0.code == "cap-language-duplicate-Road Cant" }, "Distinct language-choice slots cannot select the same language")
    // Ordinary selected features can overlap in a fixed language without wasting slots.
    a.languageChoices = nil; b.languageChoices = nil
    a.options[0].grants.append(.init(id: "feature-speed", kind: .speed, value: .init(base: 5)))
    pack.classes[0].capabilities?.groups = [a,b]
    let result = RulesEngine.evaluate(build, in: pack)
    try check(result.isValid && result.languages.filter { $0 == "Road Cant" }.count == 1 && result.speed == 35, "Bundled feature grants must deduplicate without rejecting feature choices")
    a.languageChoices = true; pack.classes[0].capabilities?.groups = [a,b]
    var rejected = false
    do { try PackValidator.validate(pack) } catch { rejected = true }
    try check(rejected, "Explicit language-choice slots cannot hide unrelated bundled feature grants")
    let source = try String(contentsOfFile: "Sources/FolioApp/CharacterView.swift", encoding: .utf8)
    try check(source.contains("summary.languages.joined") && !source.contains("Text(\"Common, \""), "Native summary must consume calculated languages rather than invent Common")
}
