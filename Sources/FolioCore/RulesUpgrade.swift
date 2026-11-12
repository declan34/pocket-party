import Foundation

public enum RulesUpgrade {
    /// Produces a reviewable copy only. The caller decides whether to save it.
    public static func copy(_ record: CharacterRecord) throws -> CharacterRecord {
        try PackValidator.validateRecord(record)
        var copy = record
        copy.build.id = UUID()
        copy.build.updatedAt = Date()
        copy.build.rulesProfile = .init(edition: record.build.rulesProfile?.edition ?? record.pack.ruleset)
        copy.pack.schemaVersion = 2
        copy.pack.capabilities = copy.pack.capabilities ?? .init()
        copy.build.upgradeReview = ["Review the copied character's choices under evaluator 2; original rules and history are preserved in the source character."]
        try PackValidator.validateRecord(copy)
        return copy
    }
}
