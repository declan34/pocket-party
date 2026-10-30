import Foundation
import Observation
import FolioCore

@MainActor @Observable
final class AppStore {
    var library = LibraryDocument()
    var error: String?
    var readOnly = false
    let storage: LibraryStorage

    init() {
        let base: URL
        if let override = ProcessInfo.processInfo.environment["FOLIO_LIBRARY_PATH"] {
            base = URL(fileURLWithPath: override, isDirectory: true)
        } else {
            base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("CharacterFolio", isDirectory: true)
        }
        storage = LibraryStorage(directory: base)
        do {
            library = try storage.load()
            if library.packs.isEmpty {
                library.packs = [try ContentPack.sample()]
                try storage.save(library)
            }
        } catch {
            self.error = "Could not open your library. Your existing file has not been changed. \(error.localizedDescription)"
            readOnly = true
        }
    }
    var packs: [ContentPack] { library.packs.sorted { $0.name < $1.name } }
    var characters: [CharacterRecord] { library.characters.sorted { $0.build.updatedAt > $1.build.updatedAt } }

    @discardableResult func commit(_ next: LibraryDocument) -> Bool {
        guard !readOnly else { error = "The library is read-only until its load error is resolved."; return false }
        do { try storage.save(next); library = next; return true }
        catch { self.error = "Could not save. Your previous library is preserved. \(error.localizedDescription)"; return false }
    }
    @discardableResult func save(_ record: CharacterRecord) -> Bool {
        var next = library
        var record = record
        record.build.updatedAt = Date()
        if let index = next.characters.firstIndex(where: { $0.id == record.id }) { next.characters[index] = record }
        else { next.characters.append(record) }
        return commit(next)
    }
    func duplicate(_ record: CharacterRecord) -> CharacterRecord? {
        var copy = record; copy.build.id = UUID(); copy.build.name += " · alternate"; copy.build.updatedAt = Date()
        return save(copy) ? copy : nil
    }
    func importFile(_ data: Data) throws -> String {
        if let object = try JSONSerialization.jsonObject(with: data) as? [String: Any], object["build"] != nil {
            var record = try LibraryStorage.decodeCharacter(data)
            record.build.id = UUID() // Import creates a copy, never overwrites an existing build.
            guard save(record) else { throw FolioError.invalid(error ?? "Could not save character.") }
            return "Imported \(record.build.name). Its content pack is included in the character file."
        }
        let pack = try PackValidator.decode(data)
        guard pack.sources == nil else { throw FolioError.invalid("This is a combined snapshot. Import the original source packs or a character export instead.") }
        if let existing = library.packs.first(where: { $0.id == pack.id && $0.version == pack.version }) {
            guard existing == pack else { throw FolioError.invalid("A different pack already uses this ID and version. Give the edited pack a new version.") }
            return "This pack is already installed."
        }
        var next = library; next.packs.append(pack)
        guard commit(next) else { throw FolioError.invalid(error ?? "Could not save pack.") }
        return "Installed \(pack.name) \(pack.version). Existing characters keep their original version."
    }
    func addDemoCharacter() -> CharacterRecord? {
        let pack: ContentPack
        do { pack = try ContentPack.sample() }
        catch { self.error = error.localizedDescription; return nil }
        var b = CharacterBuild(classID: "lantern-keeper")
        b.name = "Mara Vale"; b.pronouns = "she / her"; b.speciesID = "roadfolk"; b.backgroundID = "night-guide"
        b.backgroundBoosts = ["cha": 2, "con": 1]; b.classSkills = ["Insight", "Religion"]; b.languages = ["Elvish", "Dwarvish"]
        b.concept = "A former night guide looking for the person who keeps relighting an abandoned lighthouse."
        b.levels[0].talentIDs = ["letter-keeper"]
        b = (try? RulesEngine.advance(b, in: pack)) ?? b
        b.levels[1].talentIDs.append("gentle-hand")
        b.levels[1].cantripIDs = ["little-beacon", "paper-bird"]
        b.levels[1].spellIDs = ["sheltering-glow", "borrowed-dawn"]
        b = (try? RulesEngine.advance(b, in: pack)) ?? b
        b.levels[2].subclassID = "waylight"
        b.backstory = "Mara used to know every light along the coast. When her work as a night guide took her inland, she left a lantern in the window for her younger brother. Years later, strangers began thanking her for a light that guided them through storms—at a lighthouse abandoned before she was born.\n\nShe has returned with an old map, an unsent letter, and a question she cannot quite bring herself to ask. Whoever is tending that light knows a song only her brother used to sing."
        b.appearance = "A salt-worn blue coat, copper-framed spectacles, and a lantern repaired so often that no two panes match. Her dark curls are tied back with a faded ribbon."
        b.personality = "Patient with strangers. Restless in familiar places. Keeps promises long after everyone else has forgotten them."
        let record = CharacterRecord(pack: pack, build: b)
        return save(record) ? record : nil
    }
}
