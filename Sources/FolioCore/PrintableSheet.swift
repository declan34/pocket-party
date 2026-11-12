import Foundation
public struct SheetSection: Sendable {
    public let title: String
    public let text: String
    public init(title:String,text:String) { self.title=title; self.text=text }
}
public struct PrintableSheet: Sendable {
    public var fields: [String:String] = [:]
    public var checks: Set<String> = []
    public var supplements: [SheetSection] = []
    public var isDraft = true
    public var containsPrivateContent = false
    public init(record:CharacterRecord) {
        let b=record.build, p=record.pack
        let s=RulesEngine.evaluate(b,in:p)
        let cls=p.classes.first { $0.id == b.classID }
        let species=p.species.first { $0.id == b.speciesID }
        let background=p.backgrounds.first { $0.id == b.backgroundID }
        isDraft = !s.isValid; containsPrivateContent=p.isPrivate
        fields["name"]=b.name; fields["class"]=cls?.name; fields["level"]=String(b.level)
        fields["species"]=species?.name; fields["background"]=background?.name
        fields["subclass"]=cls?.subclasses.first { $0.id == b.levels.last?.subclassID }?.name
        fields["appearance"]=b.appearance
        fields["story"]=[b.backstory,b.personality].filter { !$0.isEmpty }.joined(separator:"\n\n")
        fields["languages"] = s.languages.joined(separator:", ")
        fields["tools"]=background?.tool
        fields["species.traits"]=species?.text
        fields["features"]=(s.features.map(\.name)+s.talents.map(\.name)).joined(separator:"\n")
        let chosenFeats=Set(b.levels.map(\.featID))
        let feats=p.feats.filter { (b.rulesProfile?.edition != "2014" && $0.id == background?.originFeatID) || chosenFeats.contains($0.id) }
        fields["feats"]=feats.map(\.name).joined(separator:"\n")
        if !isDraft, let cls {
            fields["hp.max"]=String(s.hitPoints); fields["ac"]=String(s.armorClass)
            fields["hitDice"]=String(b.level); fields["proficiency"]=Self.signed(s.proficiency)
            fields["initiative"]=Self.signed(s.initiative); fields["speed"]="\(s.speed) ft"
            fields["size"]=s.size ?? species?.size
            for ability in Ability.allCases {
                let score=s.scores[ability.rawValue,default:10], trained=cls.saves.contains(ability)
                fields["\(ability.rawValue).score"]=String(score)
                fields["\(ability.rawValue).mod"]=Self.signed(Ability.modifier(score))
                fields["\(ability.rawValue).save"]=Self.signed(Ability.modifier(score)+(trained ? s.proficiency : 0))
                if trained { checks.insert("\(ability.rawValue).save") }
            }
            for (skill,ability) in RulesEngine.skillAbilities {
                let trained=s.skills.contains(skill)
                let modifier=s.skillModifiers[skill] ?? (Ability.modifier(s.scores[ability.rawValue,default:10])+(trained ? s.proficiency : 0))
                fields["skill.\(skill)"]=Self.signed(modifier)
                if trained { checks.insert("skill.\(skill)") }
                if skill == "Perception" { fields["passivePerception"]=String(10+modifier) }
            }
            if s.slots > 0 { fields["slots.\(s.slotLevel)"]=String(s.slots) }
            if let ability=s.castingAbility ?? cls.spellAbility, s.slots > 0 || !s.spells.isEmpty {
                if let dc=s.spellDC { fields["spell.dc"]=String(dc) }
                if let atk=s.spellAttack { fields["spell.attack"]=Self.signed(atk) }
                fields["spell.ability"]=ability.name
                fields["spell.mod"]=Self.signed(Ability.modifier(s.scores[ability.rawValue,default:10]))
            }
            for (i,spell) in s.spells.sorted(by:{ ($0.level,$0.name,$0.id) < ($1.level,$1.name,$1.id) }).enumerated() {
                fields["spell.\(i).name"]=spell.name
                fields["spell.\(i).level"]=String(spell.level)
                fields["spell.\(i).note"]=s.spellLabels[spell.id] ?? (s.grantedSpellIDs.contains(spell.id) ? "Granted" : "Known")
            }
        }
        if isDraft { supplements.append(SheetSection(title:"DRAFT - choices to review",text:s.issues.map(\.message).joined(separator:"\n"))) }
        var notes="Build capacities only. AC is unarmored (no shield). Current HP, spent resources, inspiration, attacks, equipment and coins are not tracked here and remain blank. Known and subclass-granted spells are listed under the template's prepared-spells heading; this does not introduce preparation rules. Casting metadata remains blank when not modeled. Hit dice: \(b.level)d\(cls?.hitDie ?? 0) capacity; spent dice are not tracked."
        if let armor=s.mantleArmorClass, !isDraft { notes += "\nMantle AC: \(armor), conditional on its feature; not always active." }
        if b.rulesProfile != nil {
            notes = "Build capacities only; values reflect selected configurations, not tracked combat state. Spell classifications follow the declared casting policy (including preparation or spellbook where modeled). Current HP, expenditure, attacks, equipment and coins remain untracked. Active configurations: \((b.levels.last?.capabilities?.configurations ?? []).joined(separator: ", "))."
        }
        notes += "\n" + p.coverageNotes(for: b).joined(separator:"\n")
        supplements.append(SheetSection(title:"Reading this sheet",text:notes))
        if !s.traits.isEmpty { supplements.append(SheetSection(title:"Supported traits",text:s.traits.joined(separator:"\n"))) }
        if !s.resources.isEmpty { supplements.append(SheetSection(title:"Resource capacities",text:s.resources.map { "\($0.name): \($0.maximum); recovery: \($0.recovery). Expenditure not tracked." }.joined(separator:"\n"))) }
        if !s.supportDiagnostics.isEmpty { supplements.append(SheetSection(title:"Manual mechanics",text:s.supportDiagnostics.joined(separator:"\n"))) }
        if !s.spells.isEmpty {
            let roster=s.spells.sorted { ($0.level,$0.name,$0.id) < ($1.level,$1.name,$1.id) }.map { spell in
                "\(spell.name) — \(s.spellLabels[spell.id] ?? (s.grantedSpellIDs.contains(spell.id) ? "Granted" : "Known")) (level \(spell.level))"
            }.joined(separator:"\n")
            supplements.append(SheetSection(title:"Complete spell roster",text:roster))
        }
        for (title,text) in [("Backstory",b.backstory),("Personality",b.personality),("Appearance",b.appearance),("Species traits",species?.text ?? ""),("Equipment guidance (not owned inventory)",cls?.equipment ?? ""),("Background equipment guidance",background?.equipment ?? "")] where !text.isEmpty {
            supplements.append(SheetSection(title:title,text:text))
        }
        for f in s.features { supplements.append(SheetSection(title:f.name,text:f.text)) }
        for t in s.talents { supplements.append(SheetSection(title:t.name,text:t.text)) }
        for f in feats { supplements.append(SheetSection(title:f.name,text:f.text)) }
        for spell in s.spells { supplements.append(SheetSection(title:"\(spell.name) (level \(spell.level))",text:spell.text+"\nSource: "+spell.source)) }
        supplements.append(SheetSection(title:containsPrivateContent ? "Sources - private content; keep this export private" : "Sources",text:p.attribution))
    }
    private static func signed(_ n:Int) -> String { n >= 0 ? "+\(n)" : String(n) }
}
