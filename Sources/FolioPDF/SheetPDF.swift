import Foundation
import PDFKit
import CoreText
import CryptoKit
import FolioCore
#if os(macOS)
import AppKit
private typealias SheetFont = NSFont
private typealias SheetColor = NSColor
#else
import UIKit
private typealias SheetFont = UIFont
private typealias SheetColor = UIColor
#endif

@MainActor public enum SheetPDF {
    public static let templateURL = URL(string:"https://media.dndbeyond.com/compendium-images/free-rules/ph/character-sheet.pdf")!
    public static let templateSHA256 = "1d10652adb00415be9004bd6b170bafe82d84456a1f3edbbafcdae27ad5efd3e"
    public static func validateTemplate(_ data:Data) throws {
        guard data.count <= 5_000_000, SHA256.hash(data:data).map({String(format:"%02x",$0)}).joined() == templateSHA256,
              let pdf=PDFDocument(data:data), !pdf.isEncrypted, pdf.pageCount == 2 else {
            throw FolioError.invalid("Choose the unmodified blank 2024 PDF from the official download link. This template version is not supported.")
        }
    }
    public static func render(_ sheet: PrintableSheet, template: Data) throws -> Data {
        try validateTemplate(template)
        guard let doc=PDFDocument(data:template) else { throw FolioError.invalid("Could not open the sheet template.") }
        let widgets=(0..<doc.pageCount).flatMap { doc.page(at:$0)!.annotations }.filter { $0.type == "Widget" }
        var overflow:[SheetSection]=[]
        for (logical,physical) in fieldMap.sorted(by:{$0.key < $1.key}) {
            guard var value=sheet.fields[logical], !value.isEmpty else { continue }
            if logical == "name", sheet.isDraft { value="DRAFT: "+value }
            guard let widget=widgets.first(where:{$0.fieldName == physical}) else { throw FolioError.invalid("Required PDF field is missing: \(physical)") }
            fill(widget,value:value,title:logical,overflow:&overflow)
        }
        for (logical,physical) in checkMap where sheet.checks.contains(logical) {
            guard let widget=widgets.first(where:{$0.fieldName == physical}) else { throw FolioError.invalid("Required proficiency field is missing.") }
            widget.buttonWidgetState = PDFWidgetCellState(rawValue:1)!
        }
        if let note=widgets.first(where:{$0.fieldName == "Text55"}) {
            let spellNotice=sheet.fields["spell.30.name"] == nil ? "" : "\n\nSpell list continues in the Complete spell roster supplement."
            let equipmentNote=sheet.supplements.contains { $0.title == "Equipment and loadout" } ? "AC reflects tracked equipment. Inventory, coins and attack formulas appear in the Equipment and loadout supplement. No combat expenditure is automated." : "AC assumes no armor or shield. Blank combat and inventory fields are for manual completion."
            fill(note,value:(sheet.isDraft ? "DRAFT - NOT A VALIDATED BUILD\n\n" : "")+equipmentNote+"\n\nSee the following pages for full feature text, conditional rules and build limitations."+spellNotice,title:"Sheet notes",overflow:&overflow)
        }
        let uniqueOverflow=overflow.filter { part in !sheet.supplements.contains(where: { $0.text == part.text }) }
        let supplement=try supplementPDF(sheet.supplements+uniqueOverflow,name:sheet.fields["name"] ?? "Character",draft:sheet.isDraft)
        for i in 0..<supplement.pageCount { if let p=supplement.page(at:i) { doc.insert(p,at:doc.pageCount) } }
        guard let output=doc.dataRepresentation(), PDFDocument(data:output)?.pageCount == doc.pageCount else { throw FolioError.invalid("Could not serialize the populated PDF.") }
        return output
    }
    private static func fill(_ widget:PDFAnnotation,value:String,title:String,overflow:inout [SheetSection]) {
        let box=widget.bounds.insetBy(dx:widget.bounds.width < 25 ? 1 : 5,dy:3), multiline=widget.bounds.height > 35
        var fontSize:CGFloat = multiline ? 10 : min(13,max(8,box.height*0.65))
        if !multiline {
            while fontSize > 8 && (value as NSString).size(withAttributes:[.font:SheetFont(name:"Helvetica",size:fontSize)!]).width > box.width { fontSize -= 0.5 }
        }
        // PDFKit's appearance generator clips variable system fonts differently than NSString measurement.
        // Fixed Helvetica stabilizes measurements, but widget appearance glyph
        // fallback is not portable: Poppler can omit non-Latin characters even
        // when canonical field values and Core Text supplement headers retain them.
        let font=SheetFont(name:"Helvetica",size:fontSize)!
        widget.font=font; widget.fontColor=SheetColor.black; widget.isMultiline=multiline
        widget.alignment = multiline || box.width > 65 ? .left : .center
        func fits(_ text:String)->Bool {
            if !multiline { return (text as NSString).size(withAttributes:[.font:font]).width <= box.width }
            let attr=NSAttributedString(string:text,attributes:[.font:font])
            let framesetter=CTFramesetterCreateWithAttributedString(attr)
            let frame=CTFramesetterCreateFrame(framesetter,CFRange(location:0,length:0),CGPath(rect:box,transform:nil),nil)
            return CTFrameGetVisibleStringRange(frame).length == attr.length
        }
        var visible=value
        if !fits(value) {
            overflow.append(SheetSection(title:"Full \(title)",text:value))
            let suffix=multiline ? "\n[Continued in supplement]" : "..."
            let chars=Array(value); var low=0,high=chars.count
            while low < high {
                let mid=(low+high+1)/2
                if fits(String(chars.prefix(mid))+suffix) { low=mid } else { high=mid-1 }
            }
            visible=String(chars.prefix(low))+suffix
        }
        widget.widgetStringValue=visible
    }
    private static func supplementPDF(_ sections:[SheetSection],name:String,draft:Bool) throws -> PDFDocument {
        let text=NSMutableAttributedString(string:"")
        var headings:[(start:Int,body:Int)]=[]
        let paragraph=NSMutableParagraphStyle(); paragraph.paragraphSpacing=8
        for section in sections where !section.text.isEmpty {
            let headingStart=text.length
            text.append(NSAttributedString(string:section.title+"\n",attributes:[.font:SheetFont.boldSystemFont(ofSize:13),.paragraphStyle:paragraph]))
            let firstBodyCharacter=(section.text as NSString).rangeOfCharacter(from:.whitespacesAndNewlines.inverted).location
            if firstBodyCharacter != NSNotFound { headings.append((headingStart,text.length+firstBodyCharacter)) }
            text.append(NSAttributedString(string:section.text+"\n\n",attributes:[.font:SheetFont.systemFont(ofSize:10.5),.paragraphStyle:paragraph]))
        }
        // A trailing paragraph break can spill onto an otherwise empty extra page.
        let trimmedLength=(text.string.trimmingCharacters(in:.whitespacesAndNewlines) as NSString).length
        if trimmedLength < text.length { text.deleteCharacters(in:NSRange(location:trimmedLength,length:text.length-trimmedLength)) }
        guard text.length < 2_000_000 else { throw FolioError.invalid("This sheet contains too much reference text to export safely.") }
        let data=NSMutableData()
        guard let consumer=CGDataConsumer(data:data as CFMutableData) else { throw FolioError.invalid("Could not create PDF output.") }
        var bounds=CGRect(x:0,y:0,width:612,height:792)
        guard let context=CGContext(consumer:consumer,mediaBox:&bounds,nil) else { throw FolioError.invalid("Could not create PDF pages.") }
        let framesetter=CTFramesetterCreateWithAttributedString(text)
        var offset=0,page=3
        while offset < text.length {
            guard page <= 200 else { throw FolioError.invalid("This export exceeds 200 pages. Shorten the character notes or reference content.") }
            context.beginPDFPage(nil)
            let header=(draft ? "DRAFT | " : "")+String(name.prefix(70))+" | Character Folio"
            drawLine(header,at:CGPoint(x:36,y:760),size:11,context:context)
            drawLine("Character reference - page \(page)",at:CGPoint(x:36,y:22),size:9,context:context)
            let path=CGPath(rect:CGRect(x:36,y:42,width:540,height:694),transform:nil)
            var frame=CTFramesetterCreateFrame(framesetter,CFRange(location:offset,length:0),path,nil)
            var visible=CTFrameGetVisibleStringRange(frame)
            // Core Text fits whole lines but has no keep-with-next paragraph
            // contract. If a heading fits without its first body line, move that
            // heading to the next page. Never retry a too-tall heading at page top.
            if let heading=headings.last(where: { $0.start > offset && $0.start < offset+visible.length }),
               offset+visible.length <= heading.body {
                frame=CTFramesetterCreateFrame(framesetter,CFRange(location:offset,length:heading.start-offset),path,nil)
                visible=CTFrameGetVisibleStringRange(frame)
            }
            guard visible.length > 0 else { throw FolioError.invalid("Unable to lay out reference text.") }
            context.textMatrix = .identity; CTFrameDraw(frame,context)
            context.endPDFPage(); offset += visible.length; page += 1
        }
        context.closePDF()
        guard let result=PDFDocument(data:data as Data) else { throw FolioError.invalid("Could not generate reference pages.") }
        return result
    }
    private static func drawLine(_ text:String,at point:CGPoint,size:CGFloat,context:CGContext) {
        let line=CTLineCreateWithAttributedString(NSAttributedString(string:text,attributes:[.font:SheetFont.systemFont(ofSize:size)]))
        context.textPosition=point; CTLineDraw(line,context)
    }
    public static var fieldMap:[String:String] {
        var map=["name":"Text1","background":"Text6","class":"Text7","species":"Text8","subclass":"Text9","level":"Text11","ac":"Text13","hp.max":"Text16","hitDice":"Text17","proficiency":"Text19","initiative":"Text26","speed":"Text27","size":"Text28","passivePerception":"Text29","features":"Text54","species.traits":"Text57","feats":"Text58","tools":"Text60","appearance":"Text96","story":"Text97","languages":"Text98","spell.ability":"Text111","spell.mod":"Text93","spell.dc":"Text94","spell.attack":"Text95"]
        let ability:[(String,Int,Int,Int)]=[("str",64,21,91),("dex",66,22,87),("con",67,24,86),("int",63,20,69),("wis",65,23,75),("cha",68,25,81)]
        for (key,score,mod,save) in ability { map[key+".score"]="Text\(score)"; map[key+".mod"]="Text\(mod)"; map[key+".save"]="Text\(save)" }
        let skills=["Arcana":70,"History":71,"Investigation":72,"Nature":73,"Religion":74,"Animal Handling":76,"Insight":77,"Medicine":78,"Perception":79,"Survival":80,"Deception":82,"Intimidation":83,"Performance":84,"Persuasion":85,"Acrobatics":88,"Sleight of Hand":89,"Stealth":90,"Athletics":92]
        for (skill,index) in skills { map["skill."+skill]="Text\(index)" }
        for (i,index) in [112,113,114,117,116,115,118,119,120].enumerated() { map["slots.\(i+1)"]="Text\(index)" }
        let notes=[108]+Array(208...225)+[227,228,229,230,244,231,232,233,234,235,236]
        for i in 0..<30 { map["spell.\(i).name"]="Text106.\(i)"; map["spell.\(i).level"]="Text105.\(i)"; map["spell.\(i).note"]="Text\(notes[i])" }
        return map
    }
    private static let checkMap:[String:String] = {
        let indices=["str.save":37,"dex.save":33,"con.save":32,"int.save":4,"wis.save":21,"cha.save":26,"skill.Arcana":16,"skill.History":17,"skill.Investigation":19,"skill.Nature":20,"skill.Religion":18,"skill.Animal Handling":22,"skill.Insight":23,"skill.Medicine":25,"skill.Perception":31,"skill.Survival":24,"skill.Deception":27,"skill.Intimidation":28,"skill.Performance":30,"skill.Persuasion":29,"skill.Acrobatics":34,"skill.Sleight of Hand":35,"skill.Stealth":36,"skill.Athletics":38]
        return indices.mapValues { "Check Box\($0)" }
    }()
}

public struct SheetTemplateStore {
    public let directory:URL
    public init(directory:URL) { self.directory=directory }
    public func load() throws -> Data { try Data(contentsOf:directory.appendingPathComponent("blank-2024-sheet.pdf")) }
    @MainActor public func install(_ data:Data) throws {
        try SheetPDF.validateTemplate(data)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        try data.write(to:directory.appendingPathComponent("blank-2024-sheet.pdf"),options:.atomic)
    }
}
