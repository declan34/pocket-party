import Foundation
import CryptoKit

public struct CatalogClass: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let sourceLabel: String
}

/// Source packs stay untouched. Only resolved character snapshots use qualified IDs.
public struct ContentCatalog {
    private let packs: [ContentPack]
    public init(packs: [ContentPack]) throws {
        var revisions: [[String]: ContentPack] = [:]
        var latest: [String: ContentPack] = [:]
        for pack in packs {
            try PackValidator.validate(pack)
            guard pack.sources == nil else { throw FolioError.invalid("Import original content packs, not a combined character snapshot.") }
            let key = [pack.id, pack.version]
            if let prior = revisions[key], prior != pack { throw FolioError.invalid("Conflicting content has the same source and version.") }
            revisions[key] = pack; latest[pack.id] = pack
        }
        self.packs = latest.values.sorted { $0.id < $1.id }
    }
    public var classes: [CatalogClass] {
        packs.flatMap { pack in pack.classes.map {
            CatalogClass(id: Self.key(pack, "class", $0.id), name: $0.name, sourceLabel: "\(pack.name) \(pack.version)")
        }}.sorted { ($0.name, $0.sourceLabel, $0.id) < ($1.name, $1.sourceLabel, $1.id) }
    }
    public func snapshot(for classKey: String) throws -> ContentPack {
        guard classes.contains(where: { $0.id == classKey }), let first = packs.first else { throw FolioError.invalid("Choose an installed class.") }
        var result = first
        result.id = "folio-library"; result.version = "1"; result.name = "Character library"
        result.classes=[]; result.species=[]; result.backgrounds=[]; result.feats=[]; result.spells=[]; result.languages=[]
        result.sources=[]; result.sourceLabels=[:]; result.coverageNotes=[]; result.attribution=""; result.isPrivate=false
        for pack in packs { Self.append(pack, to:&result) }
        try Self.finish(&result)
        return result
    }
    public func addingChoices(to record: CharacterRecord) throws -> CharacterRecord {
        var copy = record
        if copy.pack.sources == nil {
            copy.pack.sources = [ContentSource(pack:record.pack)]
            copy.pack.sourceLabels = [:]
            let label = "\(record.pack.name) \(record.pack.version)"
            for id in Self.ids(copy.pack) { copy.pack.sourceLabels?[id] = label }
        }
        for pack in packs where !(copy.pack.sources ?? []).contains(where: { $0.id == pack.id && $0.version == pack.version }) {
            Self.append(pack, to:&copy.pack)
        }
        try Self.finish(&copy.pack)
        try PackValidator.validateRecord(copy)
        return copy
    }
    private static func key(_ pack: ContentPack, _ kind: String, _ id: String) -> String {
        // JSON framing avoids ambiguous delimiter-based keys. Full digest remains under the 120-char ID limit.
        let data = try! JSONEncoder().encode([pack.id,pack.version,kind,id])
        return "lib-" + SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined()
    }
    private static func ids(_ pack: ContentPack) -> [String] {
        pack.classes.map(\.id) + pack.species.map(\.id) + pack.backgrounds.map(\.id) + pack.feats.map(\.id) + pack.spells.map(\.id)
    }
    private static func append(_ original: ContentPack, to result: inout ContentPack) {
        var p = original
        p.spells = p.spells.map { var x=$0; x.id=key(original,"spell",x.id); return x }
        p.feats = p.feats.map { var x=$0; x.id=key(original,"feat",x.id); return x }
        p.species = p.species.map { var x=$0; x.id=key(original,"species",x.id); return x }
        p.backgrounds = p.backgrounds.map { var x=$0; x.id=key(original,"background",x.id); x.originFeatID=key(original,"feat",x.originFeatID); return x }
        p.classes = p.classes.map { cls in
            var c=cls; c.id=key(original,"class",c.id)
            c.spellIDs=c.spellIDs.map { key(original,"spell",$0) }
            c.subclasses=c.subclasses.map { sub in
                var s=sub; s.spells=s.spells.map { grant in
                    var g=grant; g.spellIDs=g.spellIDs.map { key(original,"spell",$0) }; return g
                }; return s
            }; return c
        }
        result.classes += p.classes; result.species += p.species; result.backgrounds += p.backgrounds
        result.feats += p.feats; result.spells += p.spells
        result.languages=Array(Set(result.languages+p.languages)).sorted()
        result.coverageNotes=Array(Set(result.coverageNotes+p.coverageNotes)).sorted()
        result.sources?.append(ContentSource(pack:original))
        for id in ids(p) { result.sourceLabels?[id] = "\(original.name) \(original.version)" }
        result.isPrivate = result.isPrivate || p.isPrivate
    }
    private static func finish(_ pack: inout ContentPack) throws {
        pack.sources?.sort { ($0.id,$0.version) < ($1.id,$1.version) }
        pack.attribution=(pack.sources ?? []).map { "\($0.name) \($0.version): \($0.attribution)" }.joined(separator:"\n")
        // Store all source labels, but show a subtitle only for same-name variants.
        try PackValidator.validate(pack)
        guard try JSONEncoder().encode(pack).count <= 12_000_000 else { throw FolioError.invalid("The combined content is too large (12 MB maximum). Use fewer installed packs.") }
    }
}
