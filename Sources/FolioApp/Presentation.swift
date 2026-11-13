import Foundation

enum CharacterPresentation {
    static func terminalLevelLimit(evaluator: Int?, startingClassMaximum: Int?) -> Int {
        evaluator == 2 ? 20 : startingClassMaximum ?? 1
    }
    static func showsFeat(_ id: String, originID: String?, selectedIDs: [String], edition: String?) -> Bool {
        (edition != "2014" && id == originID) || selectedIDs.contains(id)
    }
    static func initials(for name: String) -> String {
        let words = name.split(whereSeparator: \.isWhitespace)
        guard let first = words.first?.first else { return "?" }
        let letters = words.count > 1 ? String(first) + String(words.last!.first!) : String(first)
        return String(letters.uppercased().prefix(2))
    }
    static func matches(name: String, className: String, query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty || [name, className].contains {
            $0.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }
}
