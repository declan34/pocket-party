import Foundation
import FolioCore

func sheetChecks() throws {
    let p=try ContentPack.sample()
    let novice=PrintableSheet(record:CharacterRecord(pack:p,build:try FolioCoreTests().valid(1)))
    try check(novice.fields["spell.dc"] == nil && novice.fields["spell.attack"] == nil, "spell statistics absent before spellcasting starts")
    var record=CharacterRecord(pack:p,build:try FolioCoreTests().valid(3))
    record.build.name="Élodie 李"
    record.build.backstory=String(repeating:"A long remembered road. ",count:500)
    let sheet=PrintableSheet(record:record)
    try check(!sheet.isDraft && sheet.fields["name"] == "Élodie 李", "valid identity projected")
    try check(sheet.fields["hp.max"] == "27" && sheet.fields["ac"] == "12" && sheet.fields["proficiency"] == "+2", "stats use engine summary")
    try check(sheet.fields["str.save"] == "+0" && sheet.fields["cha.save"] == "+5", "all saves including untrained")
    try check(sheet.fields["skill.Stealth"] == "+2" && sheet.fields["skill.Arcana"] == "+1", "untrained and trained skills")
    try check(sheet.checks.contains("cha.save") && sheet.checks.contains("skill.Arcana") && !sheet.checks.contains("skill.Stealth"), "proficiency indicators")
    try check(sheet.fields["hp.current"] == nil && sheet.fields["slots.used"] == nil && sheet.fields["weapon.0"] == nil, "unknown combat state left blank")
    try check(sheet.fields["slots.1"] == "2" && sheet.fields["spell.dc"] == "13", "slot capacity and spell DC")
    try check(sheet.fields["spell.0.name"] != nil && sheet.supplements.contains { $0.text.contains("Known") }, "known/granted semantics not preparation")
    try check(sheet.supplements.contains { $0.text == record.build.backstory }, "long narrative fully preserved")
    var expansive=record
    let subclassIndex=expansive.pack.classes[0].subclasses.firstIndex { $0.id == "waylight" }!
    for n in 0..<31 {
        var spell=expansive.pack.spells.first { $0.level == 1 }!
        spell.id="extra-\(n)"; spell.name="Extra spell \(n)"
        expansive.pack.spells.append(spell)
        expansive.pack.classes[0].subclasses[subclassIndex].spells[0].spellIDs.append(spell.id)
    }
    try PackValidator.validate(expansive.pack)
    let many=PrintableSheet(record:expansive)
    try check(!many.isDraft && many.fields["spell.30.name"] != nil,"more than thirty spell fixture valid")
    try check(many.supplements.contains { $0.title == "Complete spell roster" && $0.text.contains("Extra spell 30 — Granted") && $0.text.contains("Known") },"overflow spell classifications retained")
    try check(!sheet.containsPrivateContent && sheet.supplements.contains { $0.text.contains(p.attribution) }, "source provenance")
    var draft=record; draft.build.speciesID=""; draft.build.backgroundID=""
    let incomplete=PrintableSheet(record:draft)
    try check(incomplete.isDraft && incomplete.fields["hp.max"] == nil && incomplete.fields["str.score"] == nil, "incomplete stats not presented as valid")
    try check(incomplete.supplements.contains { $0.title.contains("DRAFT") }, "draft issues included")
    record.pack.classes[0].armorFormula="vessel-mantle"
    let conditional=PrintableSheet(record:record)
    try check(conditional.fields["ac"] == "12" && conditional.supplements.contains { $0.text.contains("15") && $0.text.contains("Mantle") }, "conditional armor not permanent")
}
