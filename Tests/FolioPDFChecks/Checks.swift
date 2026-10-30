import Foundation
import PDFKit
import FolioCore
import FolioPDF
#if os(macOS)
import AppKit
#endif

@main struct PDFChecks {
    @MainActor static func main() throws {
        guard CommandLine.arguments.count == 3 else { print("SKIPPED: pass official template path and output directory"); exit(2) }
        let template=try Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[1]))
        let output=URL(fileURLWithPath:CommandLine.arguments[2],isDirectory:true)
        try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
        func check(_ value:Bool,_ name:String) throws { guard value else { throw FolioError.invalid(name) }; print("PASS \(name)") }
        try SheetPDF.validateTemplate(template)
        do { try SheetPDF.validateTemplate(Data("not a PDF".utf8)); throw FolioError.invalid("Wrong template accepted") }
        catch { try check(error.localizedDescription != "Wrong template accepted", "wrong template rejected") }
        let pack=try ContentPack.sample()
        var b=CharacterBuild(classID:"lantern-keeper")
        b.name="Élodie 李"; b.speciesID="roadfolk"; b.backgroundID="night-guide"
        b.backgroundBoosts=["cha":2,"con":1]; b.classSkills=["Arcana","Religion"]; b.languages=["Elvish","Dwarvish"]
        b.levels[0].talentIDs=["listener"]
        b.backstory="A traveler learning to trust the road again."
        let record=CharacterRecord(pack:pack,build:b)
        let data=try SheetPDF.render(PrintableSheet(record:record),template:template)
        let doc=PDFDocument(data:data)!
        let annotations=(0..<doc.pageCount).flatMap { doc.page(at:$0)!.annotations }
        func field(_ name:String)->String? { annotations.first { $0.fieldName == name }?.widgetStringValue }
        try check(field("Text1") == "Élodie 李", "unicode name survives field serialization")
        try check(field("Text16") == "11", "max HP maps to max not current")
        try check(field("Text14") == "" || field("Text14") == nil, "current HP blank")
        try check(field("Text68") == "17", "charisma score maps to score not modifier")
        try check(field("Text81") == "+5", "charisma save populated")
        try check(field("Text28") == "Medium", "ordinary size label fits without truncation")
        let saveWidget = annotations.first(where: { $0.fieldName == "Check Box26" })
        try check(saveWidget?.buttonWidgetState.rawValue == 1, "saving throw proficiency persisted")
        try check(doc.pageCount >= 3, "reference supplements included")
        try check(doc.pageCount == 3, "no whitespace-only trailing page")
        try check(template == (try Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[1]))), "blank master untouched")
        try data.write(to:output.appendingPathComponent("sample-2024.pdf"))
        var caster=b
        caster=try RulesEngine.advance(caster,in:pack)
        caster.levels[1].talentIDs=["listener","letter-keeper"]
        caster.levels[1].cantripIDs=["little-beacon","paper-bird"]
        caster.levels[1].spellIDs=["sheltering-glow","borrowed-dawn"]
        caster=try RulesEngine.advance(caster,in:pack); caster.levels[2].subclassID="waylight"
        caster=try RulesEngine.advance(caster,in:pack)
        caster.levels[3].talentIDs.append("gentle-hand")
        caster.levels[3].cantripIDs.append("ember-script")
        caster.levels[3].spellIDs.append("trail-whisper")
        caster.levels[3].featID="ability-improvement"; caster.levels[3].boosts=["cha":2]
        caster=try RulesEngine.advance(caster,in:pack)
        let casterSheet=PrintableSheet(record:CharacterRecord(pack:pack,build:caster))
        try check(!casterSheet.isDraft,"level-five caster fixture valid")
        let casterData=try SheetPDF.render(casterSheet,template:template)
        let casterDoc=PDFDocument(data:casterData)!
        let casterWidgets=(0..<casterDoc.pageCount).flatMap { casterDoc.page(at:$0)!.annotations }
        for (logical,physical) in SheetPDF.fieldMap where casterSheet.fields[logical] != nil {
            try check(casterWidgets.first(where:{$0.fieldName == physical})?.widgetStringValue == casterSheet.fields[logical],"caster field \(logical) preserved")
        }
        try check(casterWidgets.first(where:{$0.fieldName == "Text112"})?.widgetStringValue?.isEmpty != false,"obsolete level-one slot tier blank")
        try casterData.write(to:output.appendingPathComponent("caster-2024.pdf"))
        #if os(macOS)
        for i in 0..<doc.pageCount {
            let p=doc.page(at:i)!, bounds=doc.page(at:i)!.bounds(for:.mediaBox)
            let img=p.thumbnail(of:NSSize(width:bounds.width*1.5,height:bounds.height*1.5),for:.mediaBox)
            let png=NSBitmapImageRep(data:img.tiffRepresentation!)!.representation(using:.png,properties:[:])!
            try png.write(to:output.appendingPathComponent("sample-page-\(i+1).png"))
        }
        #endif
        b.backstory=String(repeating:"A winding road and a remembered promise. ",count:600)+"ENDOFSTORYMARKER"
        let long=try SheetPDF.render(PrintableSheet(record:CharacterRecord(pack:pack,build:b)),template:template)
        let longDoc=PDFDocument(data:long)!
        try long.write(to:output.appendingPathComponent("stress-2024.pdf"))
        try check(longDoc.pageCount > doc.pageCount && (longDoc.string ?? "").filter { !$0.isWhitespace }.contains("ENDOFSTORYMARKER"), "long story paginates without truncation")
        b.speciesID=""
        let draft=try SheetPDF.render(PrintableSheet(record:CharacterRecord(pack:pack,build:b)),template:template)
        try check((PDFDocument(data:draft)?.string ?? "").contains("DRAFT"), "draft marked in exported pages")
        try draft.write(to:output.appendingPathComponent("draft-2024.pdf"))
        let templateStore=SheetTemplateStore(directory:output.appendingPathComponent("ui-library"))
        try templateStore.install(template)
        do { try templateStore.install(Data()); throw FolioError.invalid("Invalid replacement accepted") }
        catch { try check(error.localizedDescription != "Invalid replacement accepted", "invalid replacement rejected") }
        try check(try templateStore.load() == template, "failed install preserves prior template")
        var library=LibraryDocument(); var second=pack
        second.id="harbor-test"; second.name="Harbor test content"; second.classes[0].name="Harbor Keeper"; second.species[0].name="Harborfolk"
        library.packs=[pack,second]; library.characters=[record]
        try LibraryStorage(directory:templateStore.directory).save(library)
        print("PDF checks passed")
    }
}
