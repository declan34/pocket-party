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
        var mixedPack=pack; mixedPack.schemaVersion=2; mixedPack.capabilities = .init(required:["spell-pools"])
        mixedPack.classes[0].capabilities = .init(edition:"2024")
        mixedPack.species[0].capabilities = .init(edition:"2024")
        mixedPack.species[0].capabilities?.spellPools=[.init(id:"native-charge",name:"Native charge",kind:.limited,recovery:"long rest",capacities:Array(repeating:[1:1],count:5))]
        var mixedBuild=caster; mixedBuild.rulesProfile = .init(edition:"2024")
        let mixedSheet=PrintableSheet(record:.init(pack:mixedPack,build:mixedBuild))
        try check(!mixedSheet.isDraft,"mixed legacy and typed pool fixture valid")
        let mixedData=try SheetPDF.render(mixedSheet,template:template)
        let mixedText=(PDFDocument(data:mixedData)?.string ?? "").filter { !$0.isWhitespace }
        try check(mixedText.contains("legacyslots") && mixedText.contains("Tier2:2") && mixedText.contains("Unspecified(legacysource)") && mixedText.contains("Nativecharge") && mixedText.contains("Tier1:1") && mixedText.contains("longrest"),"legacy and typed pool capacities retain distinct source and recovery in PDF")
        try mixedData.write(to:output.appendingPathComponent("mixed-legacy-pools-2024.pdf"))
        // A subclass's independent policy must not erase the legacy class roster.
        mixedPack.classes[0].subclasses[0].capabilities=mixedPack.species[0].capabilities
        mixedPack.species[0].capabilities=nil
        var independent=CastingPolicy(id:"sub-innate",name:"Subclass innate",mode:.limited,ability:.wis,spellIDs:["paper-bird"],counts:[0,0,1,1,1],maximumSpellLevels:[0,0,0,0,0])
        independent.poolIDs=["native-charge"]; independent.legacyClassCasting = .preserve
        mixedPack.classes[0].subclasses[0].capabilities?.casting=[independent]
        for index in 2..<mixedBuild.levels.count { mixedBuild.levels[index].capabilities = .init(spells:["sub-innate":["paper-bird"]]) }
        let subclassSheet=PrintableSheet(record:.init(pack:mixedPack,build:mixedBuild))
        try check(!subclassSheet.isDraft && subclassSheet.fields["spell.dc"]==nil,"additive subclass source keeps valid distinct abilities")
        let subclassData=try SheetPDF.render(subclassSheet,template:template)
        let subclassText=(PDFDocument(data:subclassData)?.string ?? "").filter { !$0.isWhitespace }
        try check(subclassText.contains("legacycasting") && subclassText.contains("BorrowedDawn") && subclassText.contains("Subclassinnate") && subclassText.contains("Charisma") && subclassText.contains("Wisdom"),"legacy acquired roster and both source abilities survive additive subclass PDF export")
        try subclassData.write(to:output.appendingPathComponent("additive-subclass-casting-2024.pdf"))
        // Original dual-source fixture: nine ordinary tiers, independent custom
        // capacity, different abilities, and more than the form's 30 spell rows.
        var tierPack=try ContentPack.capabilitySample()
        let notebookIndex=tierPack.classes.firstIndex { $0.id == "notebook-keeper" }!
        var notes:[String]=[]
        for i in 1...35 {
            var spell=tierPack.spells[0]; spell.id="pdf-note-\(i)"; spell.name="Notebook note \(i)"; spell.level=1
            spell.text="BodyForNote\(i): Original public PDF overflow fixture."; tierPack.spells.append(spell); notes.append(spell.id)
        }
        tierPack.classes[notebookIndex].capabilities?.casting?[0].spellIDs=notes
        tierPack.classes[notebookIndex].capabilities?.casting?[0].counts=Array(repeating:35,count:20)
        var tierBuild=b; tierBuild.classID="notebook-keeper"; tierBuild.rulesProfile = .init(edition:"2024")
        tierBuild.name="Notebook tier and source check"; tierBuild.levels=[]
        for at in 1...20 {
            var choice=LevelChoice(level:at)
            if at>=3 { choice.subclassID=tierPack.classes[notebookIndex].subclasses[0].id }
            choice.capabilities = .init(spells:["notebook-study":notes],prepared:["notebook-study":[notes[0]]])
            if at>=3 { choice.capabilities?.spells?["echo-voice"]=["little-beacon"] }
            tierBuild.levels.append(choice)
        }
        tierBuild.castingLoadouts=["notebook-study":[notes[1]]]
        let tierSheet=PrintableSheet(record:.init(pack:tierPack,build:tierBuild))
        try check(!tierSheet.isDraft,"tiered dual-source fixture valid")
        let tierData=try SheetPDF.render(tierSheet,template:template), tierDoc=PDFDocument(data:tierData)!
        let tierWidgets=(0..<tierDoc.pageCount).flatMap { tierDoc.page(at:$0)!.annotations }
        for tier in 1...9 {
            let key="slots.\(tier)", physical=SheetPDF.fieldMap["slots.\(tier)"]!
            try check(tierWidgets.first { $0.fieldName == physical }?.widgetStringValue == tierSheet.fields[key],"tier \(tier) editable capacity preserved")
        }
        try check(tierSheet.fields["spell.dc"] == nil && tierSheet.fields["spell.ability"] == nil,"mixed abilities do not occupy misleading scalar fields")
        let tierText=(tierDoc.string ?? "").filter { !$0.isWhitespace }
        for i in 1...35 { try check(tierText.contains("pdf-note-\(i)"),"overflow source member \(i) survives native rendering") }
        try check(tierText.contains("Echocharge") && tierText.contains("shortrest") && tierText.contains("Notebookstudy") && tierText.contains("Spellbook") && tierText.contains("Intelligence") && tierText.contains("Charisma"),"independent pools, source abilities and spell classifications survive rendering")
        try tierData.write(to:output.appendingPathComponent("tiered-casting-2024.pdf"))
        for i in 1...35 {
            let heading="Notebooknote\(i)(level1)"
            let page=(2..<tierDoc.pageCount).first { (tierDoc.page(at:$0)?.string ?? "").filter { !$0.isWhitespace }.contains(heading) }
            try check(page != nil && (tierDoc.page(at:page!)?.string ?? "").contains("BodyForNote\(i):"),"spell heading \(i) stays with its first body line")
        }
        do {
        var mixedPack=try ContentPack.capabilitySample()
        let martialIndex=mixedPack.classes.firstIndex { $0.id=="summit-warden" }!, casterIndex=mixedPack.classes.firstIndex { $0.id=="notebook-keeper" }!
        mixedPack.classes[martialIndex].hitDie=12; mixedPack.classes[casterIndex].hitDie=6
        var mixed=CharacterBuild(classID:"summit-warden")
        mixed.name="Mira Two Paths"; mixed.rulesProfile = .init(edition:"2024"); mixed.speciesID="roadfolk"; mixed.backgroundID="night-guide"
        mixed.baseScores=["str":10,"dex":14,"con":13,"int":15,"wis":12,"cha":8]
        mixed.backgroundBoosts=["cha":2,"con":1]; mixed.classSkills=["Arcana","Religion"]; mixed.languages=["Elvish","Dwarvish"]
        mixed.levels[0].classID=mixed.classID
        mixed=try RulesEngine.advance(mixed,in:mixedPack,classID:"notebook-keeper")
        mixed.levels[1].capabilities = .init(spells:["notebook-study":["sheltering-glow","borrowed-dawn"]],prepared:["notebook-study":["sheltering-glow"]])
        mixed=try RulesEngine.advance(mixed,in:mixedPack,classID:"notebook-keeper")
        mixed=try RulesEngine.advance(mixed,in:mixedPack,classID:"summit-warden")
        let mixedSheet=PrintableSheet(record:.init(pack:mixedPack,build:mixed))
        try check(!mixedSheet.isDraft,"mixed-class PDF fixture valid")
        let mixedData=try SheetPDF.render(mixedSheet,template:template), mixedDoc=PDFDocument(data:mixedData)!
        let mixedWidgets=(0..<mixedDoc.pageCount).flatMap { mixedDoc.page(at:$0)!.annotations }
        for key in ["hitDice","slots.1"] {
            try check(mixedWidgets.first { $0.fieldName==SheetPDF.fieldMap[key] }?.widgetStringValue==mixedSheet.fields[key],"mixed-class \(key) editable widget survives reopen")
        }
        try check(mixedWidgets.first { $0.fieldName==SheetPDF.fieldMap["class"] }?.widgetStringValue?.hasPrefix("Summit") == true,"mixed-class class widget populated; full long label uses overflow")
        let mixedText=(mixedDoc.string ?? "").filter { !$0.isWhitespace }
        try check(mixedText.contains("SummitWarden2") && mixedText.contains("NotebookKeeper2") && mixedText.contains("2d6+2d12") && mixedText.contains("Notebookslots") && mixedText.contains("Notebookstudy"),"mixed class labels, separate hit dice, pool and casting source survive native rendering")
        try mixedData.write(to:output.appendingPathComponent("multiclass-2024.pdf"))
        }
        do {
            let equipmentPack=try ContentPack.capabilitySample()
            var equipped=CharacterBuild(classID:"summit-warden");equipped.rulesProfile = .init(edition:"2024");equipped.name="Equipment acceptance"
            equipped.speciesID="roadfolk";equipped.backgroundID="night-guide";equipped.backgroundBoosts=["cha":2,"con":1];equipped.classSkills=["Arcana","Religion"];equipped.languages=["Elvish","Dwarvish"]
            equipped.equipment = .init(inventory:[.init(itemID:"ridge-coat",equipped:true),.init(itemID:"trail-guard",equipped:true),.init(itemID:"trail-blade",equipped:true,mode:.oneHanded,ability:.dex)],currency:["gp":25])
            for i in 0..<100 { equipped.equipment?.inventory.append(.init(id:"overflow-\(i)",itemID:"trail-shafts",quantity:1,carried:false)) }
            let sheet=PrintableSheet(record:.init(pack:equipmentPack,build:equipped))
            try check(!sheet.isDraft && sheet.fields["ac"] == "18","tracked armor/shield AC projects to native form")
            let data=try SheetPDF.render(sheet,template:template),doc=PDFDocument(data:data)!
            let widgets=(0..<doc.pageCount).flatMap { doc.page(at:$0)!.annotations }
            try check(widgets.first { $0.fieldName == "Text13" }?.widgetStringValue == "18","tracked AC remains editable widget value")
            try check(widgets.first { $0.fieldName == "Text14" }?.widgetStringValue?.isEmpty != false,"equipment never writes current HP")
            let text=(doc.string ?? "").filter { !$0.isWhitespace }
            try check(text.contains("Equipmentandloadout") && text.contains("25gp") && text.contains("1d6+2") && text.contains("Trailblade"),"inventory coins and attack formula survive native PDF rendering")
            try check(text.contains("Stealth") && text.contains("disadvantage"),"armor Stealth disadvantage survives native PDF presentation")
            try check(doc.pageCount > 3 && text.components(separatedBy:"Trailshafts").count >= 100,"all inventory overflow rows survive native PDF pagination")
            try data.write(to:output.appendingPathComponent("equipment-2024.pdf"))
        }
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
