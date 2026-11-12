import Foundation
import FolioCore

func capabilitySubclassEditorIntegrationChecks() throws {
    let source = try String(contentsOfFile: "Sources/FolioApp/CharacterView.swift", encoding: .utf8)
    try check(source.contains("RulesEngine.subclassUnlockLevel(for: definition, build: build, in: pack)"), "Subclass editor must consume the shared effective unlock resolver, not the raw definition level")
    try check(source.contains("|| !current.subclassID.isEmpty"), "Premature saved subclass selections must remain editable, not silently deleted")
    var pack = try ContentPack.sample(); pack.schemaVersion = 2; pack.capabilities = .init()
    var build = try FolioCoreTests().valid(3); build.rulesProfile = .init(edition: "2024")
    for unlock in [1, 5] {
        pack.classes[0].capabilities = .init(edition: "2014", adapters: [.init(edition: "2024", canonicalID: "adapted-class", label: "Original adapter", subclassLevel: unlock)])
        let definition = pack.classes[0]
        try check(RulesEngine.subclassUnlockLevel(for: definition, build: build, in: pack) == unlock, "Resolver must honor both earlier and later adapters")
        let result = RulesEngine.evaluate(build, in: pack)
        try check(result.issues.contains { $0.code == "early-subclass" } == (unlock == 5), "Evaluator and editor must agree on effective unlock")
        try check(build.levels[2].subclassID == "waylight", "Evaluation must preserve pending subclass history")
        if unlock == 1 {
            try check(result.issues.contains { $0.code == "subclass" && $0.level == 1 }, "Earlier adapter must request subclass at level one")
        }
    }
    var other = pack; other.id = "other-original-source"
    other.classes[0].capabilities?.adapters?[0].subclassLevel = 1
    let catalog = try ContentCatalog(packs: [pack, other])
    var resolved = Set<Int>()
    for entry in catalog.classes {
        let snapshot = try catalog.snapshot(for: entry.id)
        let definition = snapshot.classes.first { $0.id == entry.id }!
        build.classID = definition.id
        resolved.insert(RulesEngine.subclassUnlockLevel(for: definition, build: build, in: snapshot))
    }
    try check(resolved == [1,5], "Same-name source-qualified classes must retain distinct adapter unlocks")
    let legacy = try ContentPack.sample(); let legacyBuild = try FolioCoreTests().valid(3)
    try check(RulesEngine.subclassUnlockLevel(for: legacy.classes[0], build: legacyBuild, in: legacy) == 3, "Legacy default remains level three")
}

func capabilityLibraryRoundTripChecks() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let storage = LibraryStorage(directory: directory)
    var library = LibraryDocument()
    let pack = try ContentPack.capabilitySample()
    // Original public snapshots exceed the old aggregate 300,000-node limit.
    for index in 0..<130 {
        var build = CharacterBuild(classID: pack.classes[0].id)
        build.name = "Original traveler \(index)"; build.rulesProfile = .init(edition: "2024")
        library.characters.append(.init(pack: pack, build: build))
    }
    let encoded = try LibraryStorage.encoder.encode(library)
    var exceedsAggregateBudget = false
    do { try CapabilityValidation.preflight(encoded) } catch { exceedsAggregateBudget = true }
    try check(exceedsAggregateBudget, "Fixture must reproduce aggregate budget overflow")
    try storage.save(library)
    let loaded = try storage.load()
    try check(loaded.characters.map(\.id) == library.characters.map(\.id), "Every accepted save must reload all pinned records")
    try check(try LibraryStorage.encoder.encode(loaded) == encoded, "Reload must preserve complete pinned snapshots")
    try storage.save(loaded)
    try check(try Data(contentsOf: directory.appendingPathComponent("library.previous.json")) == encoded, "Large-library backup must remain intact")
    // A pre-existing file needs no rewrite/migration to become readable.
    try encoded.write(to: storage.file, options: .atomic)
    try check(try storage.load().characters.count == 130, "Existing larger libraries must load")
    var duplicate = library; duplicate.characters.append(library.characters[0])
    var rejected = false
    do { try storage.save(duplicate) } catch { rejected = true }
    try check(rejected, "Save must reject duplicate IDs that load rejects")
    var future = library; future.schemaVersion = 2; rejected = false
    do { try storage.save(future) } catch { rejected = true }
    try check(rejected, "Save must reject unsupported library versions before writing")
    try check(try Data(contentsOf: storage.file) == encoded, "Rejected saves preserve previous valid bytes")
    // Limits still apply within each snapshot, including unknown deeply nested data.
    var json = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
    var records = json["characters"] as! [[String: Any]]
    var nested: Any = "leaf"
    for _ in 0..<40 { nested = ["nested": nested] }
    records[0]["unknown"] = nested; json["characters"] = records
    try JSONSerialization.data(withJSONObject: json).write(to: storage.file)
    rejected = false
    do { _ = try storage.load() } catch { rejected = true }
    try check(rejected, "Per-record structural nesting limits must remain enforced")
}

func capabilityFeatIntegrationChecks() throws {
    var pack = try ContentPack.sample(); pack.schemaVersion = 2; pack.capabilities = .init()
    pack.classes[0].capabilities = .init(edition: "2024")
    var build = try FolioCoreTests().valid(4); build.rulesProfile = .init(edition: "2024")
    let featIndex = pack.feats.firstIndex { $0.id == "steady-flame" }!
    pack.feats[featIndex].abilityMinimums = ["cha": 18]
    build.levels[3].featID = "steady-flame"; build.levels[3].boosts = ["cha": 1]
    let grant = CapabilityGrant(id: "ancestry-charisma", kind: .abilityScore, target: "cha", value: .init(base: 2))
    pack.species[0].capabilities = .init(edition: "2024", grants: [grant])
    var summary = RulesEngine.evaluate(build, in: pack)
    try check(!summary.issues.contains { $0.code == "feat-prereq-cha" }, "Permanent earlier ancestry grant must satisfy ordinary feat prerequisite")
    try check(summary.scores["cha"] == 20, "Prerequisite integration must not double-apply grant")
    try check(RulesEngine.evaluate(build, in: pack).scores == summary.scores, "Repeated evaluation must not accumulate prerequisite grants")
    try check(RulesEngine.evaluate(build, in: pack, through: 3).scores["cha"] == 19, "Historical evaluation excludes current feat boost")
    pack.species[0].capabilities?.grants = []
    summary = RulesEngine.evaluate(build, in: pack)
    try check(summary.issues.contains { $0.code == "feat-prereq-cha" && $0.level == 4 }, "Removing earlier grant must invalidate later feat")
    try check(summary.scores["cha"] == 18, "Same-choice boost cannot fund its own prerequisite")
    pack.feats[featIndex].capabilities = .init(edition: "2024", grants: [grant])
    try check(RulesEngine.evaluate(build, in: pack).issues.contains { $0.code == "feat-prereq-cha" }, "Current feat capability grant cannot self-fund")
    pack.feats[featIndex].capabilities = nil
    let option = CapabilityOption(id: "earlier-training", name: "Earlier training", grants: [grant])
    pack.classes[0].capabilities?.groups = [.init(id: "training", name: "Training", counts: [1,1,1,1], options: [option])]
    for i in build.levels.indices { build.levels[i].capabilities = .init(groups: ["training": [option.id]]) }
    try check(!RulesEngine.evaluate(build, in: pack).issues.contains { $0.code == "feat-prereq-cha" }, "Earlier option grant must satisfy feat prerequisite")
    for i in 0..<3 { build.levels[i].capabilities?.groups = [:] }
    try check(RulesEngine.evaluate(build, in: pack).issues.contains { $0.code == "feat-prereq-cha" }, "A newly acquired same-level option cannot self-fund the feat")
    let legacyPack = try ContentPack.sample()
    var legacyBuild = try FolioCoreTests().valid(4)
    legacyBuild.levels[3].featID = "steady-flame"; legacyBuild.levels[3].boosts = ["cha": 1]
    var restricted = legacyPack; restricted.feats[featIndex].abilityMinimums = ["cha":18]
    try check(RulesEngine.evaluate(legacyBuild, in: restricted).issues.contains { $0.code == "feat-prereq-cha" }, "Legacy pre-boost prerequisite behavior remains unchanged")
}

func capabilityFeatHistoricalScalingChecks() throws {
    var pack = try ContentPack.sample(); pack.schemaVersion = 2; pack.capabilities = .init()
    pack.classes[0].capabilities = .init(edition: "2024")
    pack.species[0].capabilities = .init(edition: "2024", grants: [.init(id: "scaled-ancestry", kind: .abilityScore, target: "cha", value: .init(proficiencyMultiplier: 1))])
    let feat = pack.feats.firstIndex { $0.id == "steady-flame" }!
    pack.feats[feat].abilityMinimums = ["cha":20]
    var build = try FolioCoreTests().valid(5); build.rulesProfile = .init(edition: "2024")
    build.levels[3].featID = "steady-flame"; build.levels[3].boosts = ["cha":1]
    for through in [4,5] {
        try check(RulesEngine.evaluate(build, in: pack, through: through).issues.contains { $0.code == "feat-prereq-cha" && $0.level == 4 }, "Level-five proficiency cannot retroactively qualify a level-four feat")
    }
}
