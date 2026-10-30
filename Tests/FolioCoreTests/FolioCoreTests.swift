import Foundation
import FolioCore

struct FolioCoreTests {
    func pack() throws -> ContentPack { try ContentPack.sample() }
    func valid(_ level: Int = 1) throws -> CharacterBuild {
        let p = try pack()
        var b = CharacterBuild(classID: "lantern-keeper")
        b.name = "Test traveler"; b.speciesID = "roadfolk"; b.backgroundID = "night-guide"
        b.backgroundBoosts = ["cha": 2, "con": 1]
        b.classSkills = ["Arcana", "Religion"]; b.languages = ["Elvish", "Dwarvish"]
        b.levels[0].talentIDs = ["listener"]
        if level >= 2 {
            b = try RulesEngine.advance(b, in: p)
            b.levels[1].talentIDs = ["listener", "letter-keeper"]
            b.levels[1].cantripIDs = ["little-beacon", "paper-bird"]
            b.levels[1].spellIDs = ["sheltering-glow", "borrowed-dawn"]
        }
        if level >= 3 {
            b = try RulesEngine.advance(b, in: p); b.levels[2].subclassID = "waylight"
        }
        if level >= 4 {
            b = try RulesEngine.advance(b, in: p)
            b.levels[3].talentIDs.append("gentle-hand")
            b.levels[3].cantripIDs.append("ember-script")
            b.levels[3].spellIDs.append("trail-whisper")
            b.levels[3].featID = "ability-improvement"; b.levels[3].boosts = ["cha": 2]
        }
        if level >= 5 { b = try RulesEngine.advance(b, in: p) }
        return b
    }
    func codes(_ b: CharacterBuild, _ p: ContentPack) -> [String] { RulesEngine.evaluate(b, in: p).issues.map(\.code) }

    func entireLevelOneToFivePath() throws {
        let p = try pack()
        for level in 1...5 {
            let result = RulesEngine.evaluate(try valid(level), in: p)
            try expect(result.isValid, "\(result.issues)")
        }
        let summary = RulesEngine.evaluate(try valid(5), in: p)
        try expect(summary.hitPoints == 43)
        try expect(summary.proficiency == 3)
        try expect(summary.scores["cha"] == 19)
        try expect(summary.spellDC == 15)
        try expect(summary.slots == 2 && summary.slotLevel == 2)
        try expect(summary.grantedSpellIDs == ["keeper-call", "keeper-circle"])
        try expect(summary.spells.count == 8)
    }
    func incompleteBuildCannotAdvance() throws {
        let p = try pack(); let b = CharacterBuild(classID: "lantern-keeper")
        try expectThrows { try RulesEngine.advance(b, in: p) }
    }
    func levelSixIsExplicitlyUnsupported() throws {
        let p = try pack(); let b = try valid(5)
        try expectThrows { try RulesEngine.advance(b, in: p) }
    }
    func duplicateStandardArrayScoreIsRejected() throws {
        let p = try pack(); var b = try valid(); b.baseScores["str"] = 15
        try expect(codes(b,p).contains("array"))
    }
    func illegalBackgroundAbilityAndOverspendingAreRejected() throws {
        let p = try pack(); var b = try valid(); b.backgroundBoosts = ["dex": 2, "cha": 2]
        try expect(codes(b,p).contains("background-boosts"))
        try expect(codes(b,p).contains("background-ability-dex"))
    }
    func threePlusOneBackgroundIsValid() throws {
        let p = try pack(); var b = try valid(); b.backgroundBoosts = ["wis": 1, "con": 1, "cha": 1]
        try expect(RulesEngine.evaluate(b,in:p).isValid)
    }
    func backgroundSkillCannotBeCountedTwice() throws {
        let p = try pack(); var b = try valid(); b.classSkills = ["Survival", "Religion"]
        try expect(codes(b,p).contains("duplicate-skill-Survival"))
    }
    func twoDistinctAdditionalLanguagesAreRequired() throws {
        let p = try pack(); var b = try valid(); b.languages = ["Elvish", "Elvish"]
        try expect(codes(b,p).contains("languages"))
    }
    func oneSubclassAtTheRightLevel() throws {
        let p = try pack(); var b = try valid(2); b.levels[1].subclassID = "waylight"
        try expect(codes(b,p).contains("early-subclass"))
        b = try valid(4); b.levels[3].subclassID = "memory-keeper"
        try expect(codes(b,p).contains("subclass-change"))
    }
    func spellLevelEnforcedAtAcquisition() throws {
        let p = try pack(); var b = try valid(5); b.levels[1].spellIDs = ["lantern-bridge", "borrowed-dawn"]
        try expect(RulesEngine.evaluate(b,in:p).issues.contains { $0.code == "spell-level-lantern-bridge" && $0.level == 2 })
    }
    func newSlotTierAllowsOneSpellReplacement() throws {
        let p = try pack(); var b = try valid(5); b.levels[4].spellIDs = ["lantern-bridge", "borrowed-dawn", "trail-whisper"]
        try expect(RulesEngine.evaluate(b,in:p).isValid)
        b.levels[4].spellIDs = ["lantern-bridge", "echo-room", "trail-whisper"]
        try expect(codes(b,p).contains("spell-replacement"))
    }
    func cantripsDoNotSilentlyChangeDuringLevelUp() throws {
        let p = try pack(); var b = try valid(3); b.levels[2].cantripIDs = ["ember-script", "quiet-thread"]
        try expect(codes(b,p).contains("cantrip-replacement"))
    }
    func subclassGrantsDoNotSpendKnownSpellChoices() throws {
        var p = try pack(); p.classes[0].spellIDs.append("keeper-call")
        var b = try valid(3); b.levels[2].spellIDs = ["keeper-call", "borrowed-dawn"]
        try expect(codes(b,p).contains("spell-granted-keeper-call"))
        let summary = RulesEngine.evaluate(try valid(3), in:p)
        try expect(summary.isValid && summary.spells.count == 5)
    }
    func unavailableGrantedSpellBlocksCleanValidation() throws {
        var p = try pack(); let index = try require(p.spells.firstIndex { $0.id == "keeper-call" })
        p.spells[index].unavailableReason = "Missing source"
        try expect(codes(try valid(3),p).contains("unresolved-grant-keeper-call"))
    }
    func talentPrerequisitesAndExclusiveVariantsAreChecked() throws {
        var p = try pack(); p.classes[0].talents[1].exclusiveGroup = "listener"
        try expect(codes(try valid(2),p).contains("talent-exclusive"))
        p = try pack(); var b = try valid(); b.levels[0].talentIDs = ["gentle-hand"]
        try expect(codes(b,p).contains("talent-level-gentle-hand"))
    }
    func earlierEditsInvalidateLaterChoices() throws {
        let p = try pack(); var b = try valid(4); b.levels[0].talentIDs = ["path-reader"]
        // Replacing one talent is legal. Replacing both previous choices later is not.
        b.levels[1].talentIDs = ["listener", "letter-keeper"]
        b.levels[2].talentIDs = ["path-reader", "gentle-hand"]
        try expect(codes(b,p).contains("talent-replacement"))
    }
    func featRequirementsAreMeasuredBeforeItsBoost() throws {
        var p = try pack(); let index = try require(p.feats.firstIndex { $0.id == "steady-flame" })
        p.feats[index].abilityMinimums = ["cha":18]
        var b = try valid(4); b.levels[3].featID = "steady-flame"; b.levels[3].boosts = ["cha":1]
        try expect(codes(b,p).contains("feat-prereq-cha"))
    }
    func constitutionIncreaseRetroactivelyUpdatesHP() throws {
        let p = try pack(); var b = try valid(4)
        b.levels[3].boosts = ["con":2]
        let summary = RulesEngine.evaluate(b,in:p)
        try expect(summary.hitPoints == 39) // 8+3 + 3*(5+3) + Weathered 4
        try expect(RulesEngine.evaluate(b,in:p,through:3).scores["con"] == 14)
    }
    func earlyAndOverspentImprovementsRejected() throws {
        let p = try pack(); var b = try valid(3); b.levels[1].boosts = ["cha":2]
        try expect(codes(b,p).contains("early-improvement"))
        b = try valid(4); b.levels[3].boosts = ["cha":2,"con":1]
        try expect(codes(b,p).contains("feat-boost"))
    }
    func malformedPacksAndMissingLinksRejected() throws {
        var p = try pack(); p.schemaVersion = 2
        try expectThrows { try PackValidator.validate(p) }
        p = try pack(); p.classes[0].spellIDs.append("does-not-exist")
        try expectThrows { try PackValidator.validate(p) }
        p = try pack(); p.backgrounds[0].originFeatID = "missing"
        try expectThrows { try PackValidator.validate(p) }
        p = try pack(); p.classes[0].progression.remove(at:2)
        try expectThrows { try PackValidator.validate(p) }
    }
    func unknownEditionAndUnsafeCountsRejected() throws {
        var p = try pack(); p.ruleset = "2014"
        try expectThrows { try PackValidator.validate(p) }
        p = try pack(); p.classes[0].progression[0].slots = -1
        try expectThrows { try PackValidator.validate(p) }
    }
    func exportRoundTripPreservesPinnedPackAndHistory() throws {
        let record = CharacterRecord(pack: try pack(), build: try valid(5))
        let data = try LibraryStorage.encoder.encode(record)
        let decoded = try LibraryStorage.decodeCharacter(data)
        try expect(decoded.build.levels == record.build.levels)
        try expect(decoded.pack == record.pack)
        try expect(RulesEngine.evaluate(decoded.build,in:decoded.pack).isValid)
    }
    func persistenceRecoversLastSaveWithoutChangingPinnedPack() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = LibraryStorage(directory: directory)
        var library = LibraryDocument(); library.packs = [try pack()]
        library.characters = [CharacterRecord(pack: try pack(),build: try valid(3))]
        try storage.save(library)
        library.packs[0].version = "2.0.0"; try storage.save(library)
        let loaded = try storage.load()
        try expect(loaded.packs[0].version == "2.0.0")
        try expect(loaded.characters[0].pack.version == "1.0.0")
        try expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("library.previous.json").path))
    }
    func corruptLibraryIsNeverOverwrittenByLoad() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        let storage = LibraryStorage(directory: directory)
        let bytes = Data("not json".utf8); try bytes.write(to: storage.file)
        try expectThrows { try storage.load() }
        try expect(try Data(contentsOf:storage.file) == bytes)
    }
    func narrativePromptUsesBoundedCharacterFacts() throws {
        var record = CharacterRecord(pack:try pack(),build:try valid())
        record.build.concept = String(repeating:"x",count:10_000)
        let prompt = StoryPrompt.make(record:record,kind:"backstory")
        try expect(prompt.contains("Test traveler"))
        try expect(prompt.contains("never mechanical abilities"))
        try expect(prompt.count < 3000)
    }
    func privateVesselConversionWhenPresent() throws {
        let root = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent("PrivatePacks/vessel-pack.json")
        guard FileManager.default.fileExists(atPath:url.path) else { return }
        let p = try PackValidator.decode(Data(contentsOf:url))
        let cls = try require(p.classes.first)
        try expect(cls.primaryAbility == .cha)
        try expect(cls.hitDie == 10)
        try expect(cls.at(5)?.slots == 2 && cls.at(5)?.slotLevel == 2)
        var b = CharacterBuild(classID:"vessel")
        b.name="Vessel fixture"; b.speciesID="dwarf"; b.backgroundID="farmer"
        b.backgroundBoosts=["con":2,"wis":1]; b.classSkills=["Acrobatics","Insight"]; b.languages=["Elvish","Dwarvish"]
        b.levels[0].talentIDs=["ethereal-tendril"]
        let choices = p.spells.filter { cls.spellIDs.contains($0.id) }
        let cantrips = choices.filter { $0.level == 0 }.prefix(3).map(\.id)
        let spells = choices.filter { $0.level == 1 }.prefix(3).map(\.id)
        try expect(cantrips.count == 3 && spells.count == 3)
        for level in 2...5 {
            b = try RulesEngine.advance(b,in:p)
            let i=level-1
            if level==2 { b.levels[i].talentIDs.append("spirit-sense"); b.levels[i].cantripIDs=Array(cantrips.prefix(2)); b.levels[i].spellIDs=Array(spells.prefix(2)) }
            if level==3 { b.levels[i].subclassID="the-trickster" }
            if level==4 { b.levels[i].talentIDs.append("uncanny-strength"); b.levels[i].cantripIDs=cantrips; b.levels[i].spellIDs=spells; b.levels[i].featID="ability-improvement"; b.levels[i].boosts=["con":1,"cha":1] }
        }
        let summary=RulesEngine.evaluate(b,in:p)
        try expect(summary.isValid,"\(summary.issues)")
        try expect(summary.scores["con"] == 16)
        try expect(summary.hitPoints == 64) // d10 fixed average + CON 3 retroactive + Dwarf 5 + Tough 10
        try expect(summary.mantleArmorClass == 16)
        try expect(summary.grantedSpellIDs.count == 4)
        try expect(cls.subclasses.map(\.id) == ["the-trickster"], "Subclasses with unmodeled bonus Aspect choices must not be advertised as supported")
        for i in 2...4 { b.levels[i].subclassID="the-cursed" }
        try expect(!RulesEngine.evaluate(b,in:p).isValid)
    }
}

private func expect(_ condition: @autoclosure () throws -> Bool, _ message: String = "Expectation failed", file: StaticString = #filePath, line: UInt = #line) throws {
    if try !condition() { throw FolioError.invalid("\(file):\(line): \(message)") }
}
private func require<T>(_ value: T?) throws -> T {
    guard let value else { throw FolioError.invalid("Required value missing") }; return value
}
private func expectThrows<T>(_ body: () throws -> T) throws {
    do { _ = try body() } catch { return }; throw FolioError.invalid("Expected an error, but operation succeeded")
}
@main struct CheckRunner {
    static func main() {
        let tests = FolioCoreTests()
        let checks: [(String, () throws -> Void)] = [
            ("catalogChecks", catalogChecks),
            ("sheetChecks", sheetChecks),
            ("entireLevelOneToFivePath", tests.entireLevelOneToFivePath),
            ("incompleteBuildCannotAdvance", tests.incompleteBuildCannotAdvance),
            ("levelSixIsExplicitlyUnsupported", tests.levelSixIsExplicitlyUnsupported),
            ("duplicateStandardArrayScoreIsRejected", tests.duplicateStandardArrayScoreIsRejected),
            ("illegalBackgroundAbilityAndOverspendingAreRejected", tests.illegalBackgroundAbilityAndOverspendingAreRejected),
            ("threePlusOneBackgroundIsValid", tests.threePlusOneBackgroundIsValid),
            ("backgroundSkillCannotBeCountedTwice", tests.backgroundSkillCannotBeCountedTwice),
            ("twoDistinctAdditionalLanguagesAreRequired", tests.twoDistinctAdditionalLanguagesAreRequired),
            ("oneSubclassAtTheRightLevel", tests.oneSubclassAtTheRightLevel),
            ("spellLevelEnforcedAtAcquisition", tests.spellLevelEnforcedAtAcquisition),
            ("newSlotTierAllowsOneSpellReplacement", tests.newSlotTierAllowsOneSpellReplacement),
            ("cantripsDoNotSilentlyChangeDuringLevelUp", tests.cantripsDoNotSilentlyChangeDuringLevelUp),
            ("subclassGrantsDoNotSpendKnownSpellChoices", tests.subclassGrantsDoNotSpendKnownSpellChoices),
            ("unavailableGrantedSpellBlocksCleanValidation", tests.unavailableGrantedSpellBlocksCleanValidation),
            ("talentPrerequisitesAndExclusiveVariantsAreChecked", tests.talentPrerequisitesAndExclusiveVariantsAreChecked),
            ("earlierEditsInvalidateLaterChoices", tests.earlierEditsInvalidateLaterChoices),
            ("featRequirementsAreMeasuredBeforeItsBoost", tests.featRequirementsAreMeasuredBeforeItsBoost),
            ("constitutionIncreaseRetroactivelyUpdatesHP", tests.constitutionIncreaseRetroactivelyUpdatesHP),
            ("earlyAndOverspentImprovementsRejected", tests.earlyAndOverspentImprovementsRejected),
            ("malformedPacksAndMissingLinksRejected", tests.malformedPacksAndMissingLinksRejected),
            ("unknownEditionAndUnsafeCountsRejected", tests.unknownEditionAndUnsafeCountsRejected),
            ("exportRoundTripPreservesPinnedPackAndHistory", tests.exportRoundTripPreservesPinnedPackAndHistory),
            ("persistenceRecoversLastSaveWithoutChangingPinnedPack", tests.persistenceRecoversLastSaveWithoutChangingPinnedPack),
            ("corruptLibraryIsNeverOverwrittenByLoad", tests.corruptLibraryIsNeverOverwrittenByLoad),
            ("narrativePromptUsesBoundedCharacterFacts", tests.narrativePromptUsesBoundedCharacterFacts),
            ("privateVesselConversionWhenPresent", tests.privateVesselConversionWhenPresent)
        ]
        var failures = 0
        for (name, run) in checks {
            do { try run(); print("PASS \(name)") }
            catch { failures += 1; print("FAIL \(name): \(error.localizedDescription)") }
        }
        print("\(checks.count - failures)/\(checks.count) checks passed")
        if failures > 0 { exit(1) }
    }
}
