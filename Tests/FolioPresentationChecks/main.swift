import Foundation

// Catches empty/unsafe monograms and search normalization errors, not styling constants.
var failed = 0
func check(_ name: String, _ condition: @autoclosure () -> Bool) {
    if condition() { print("PASS \(name)") } else { print("FAIL \(name)"); failed += 1 }
}
check("blank names have a visible fallback", CharacterPresentation.initials(for: "  \n ") == "?")
check("multiword names use first and last initials", CharacterPresentation.initials(for: "  Mara  Elin Vale ") == "MV")
check("Unicode names retain grapheme initials", CharacterPresentation.initials(for: "Élodie 李") == "É李")
check("one-word names stay compact", CharacterPresentation.initials(for: "Oren") == "O")
check("search ignores outer whitespace and accents", CharacterPresentation.matches(name: "Élodie", className: "Vessel", query: " ELODIE "))
check("search finds class names", CharacterPresentation.matches(name: "Mara", className: "Lantern Keeper", query: "keeper"))
check("blank query includes characters", CharacterPresentation.matches(name: "Mara", className: "Vessel", query: " \n "))
check("unmatched query excludes characters", !CharacterPresentation.matches(name: "Mara", className: "Vessel", query: "warlord"))
if failed > 0 { exit(1) }
check("2014 hides background origin feat", !CharacterPresentation.showsFeat("origin", originID: "origin", selectedIDs: [], edition: "2014"))
check("2024 retains background origin feat", CharacterPresentation.showsFeat("origin", originID: "origin", selectedIDs: [], edition: "2024"))
check("2014 retains explicitly selected feat", CharacterPresentation.showsFeat("selected", originID: "origin", selectedIDs: ["selected"], edition: "2014"))
if failed > 0 { exit(1) }
print("11/11 presentation checks passed")
