import Foundation
import FolioCore

func catalogChecks() throws {
    let a = try ContentPack.sample()
    var b = a; b.id = "second"; b.name = "Second source"; b.isPrivate = true
    b.classes[0].name = "Other class"; b.species[0].name = "Other species"
    b.feats[0].hpPerLevel = 3
    let catalog = try ContentCatalog(packs: [a,b])
    try check(catalog.classes.count == 2, "catalog combines classes")
    let snapshot = try catalog.snapshot(for: catalog.classes.first { $0.name == "Other class" }!.id)
    try check(snapshot.species.count == a.species.count + b.species.count, "shared species preserve source variants")
    try check(snapshot.isPrivate, "private provenance retained")
    try PackValidator.validate(snapshot)
    let background = snapshot.backgrounds.first { $0.id != a.backgrounds[0].id }!
    try check(snapshot.feats.contains { $0.id == background.originFeatID }, "origin feat rewritten")
    try check(Set(snapshot.spells.map(\.id)).count == snapshot.spells.count, "colliding spells are unique")
    try check(snapshot.classes.allSatisfy { Set($0.spellIDs).isSubset(of: Set(snapshot.spells.map(\.id))) }, "spell references resolve")
    var newer = a; newer.version = "next"; newer.classes[0].name = "Updated class"
    let updated = try ContentCatalog(packs:[a,b,newer])
    try check(updated.classes.count == 2 && updated.classes.contains { $0.name == "Updated class" }, "latest installed revision wins only for new builds")
    let reversed = try ContentCatalog(packs:[b,a])
    try check(catalog.classes.map(\.id) == reversed.classes.map(\.id), "catalog order deterministic")
    var partial = a; partial.id = "species-only"; partial.classes=[]; partial.backgrounds=[]; partial.feats=[]; partial.spells=[]; partial.languages=[]
    try PackValidator.validate(partial)
    var invalid = a; invalid.backgrounds[0].originFeatID = "missing"
    do { _ = try ContentCatalog(packs:[invalid]); throw CheckError.failed("missing dependency accepted") } catch is CheckError { throw CheckError.failed("missing dependency accepted") } catch {}
    var original = CharacterRecord(pack:a,build:try FolioCoreTests().valid(3))
    original.build.updatedAt = Date(timeIntervalSince1970: 1_700_000_000)
    let expanded = try catalog.addingChoices(to:original)
    try check(expanded.build == original.build, "existing choices never rewritten")
    try check(expanded.pack.classes.first { $0.id == original.build.classID } == a.classes[0], "existing class pinned")
    let before = RulesEngine.evaluate(original.build,in:a)
    let after = RulesEngine.evaluate(expanded.build,in:expanded.pack)
    try check(after.isValid && before.scores == after.scores && before.hitPoints == after.hitPoints && before.spells == after.spells, "refresh preserves evaluated mechanics")
    try check(try catalog.addingChoices(to:expanded) == expanded, "refresh idempotent")
    let roundTrip = try LibraryStorage.decodeCharacter(LibraryStorage.encoder.encode(expanded))
    try check(roundTrip.pack == expanded.pack && roundTrip.build == expanded.build, "snapshot export roundtrip")
    var huge = a; huge.species = Array(repeating:a.species[0],count:101)
    do { _ = try ContentCatalog(packs:[huge]); throw CheckError.failed("unbounded source accepted") } catch is CheckError { throw CheckError.failed("unbounded source accepted") } catch {}
    var conflict = a; conflict.classes[0].name = "Conflicting revision"
    do { _ = try ContentCatalog(packs:[a,conflict]); throw CheckError.failed("same source revision overwritten") } catch is CheckError { throw CheckError.failed("same source revision overwritten") } catch {}
}

enum CheckError: LocalizedError {
    case failed(String)
    var errorDescription: String? { switch self { case .failed(let message): message } }
}
func check(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
    if try !condition() { throw CheckError.failed(message) }
}
