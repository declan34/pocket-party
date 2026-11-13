import Foundation
import FolioCore

private func expectThrows<T>(_ body:() throws -> T) throws { do { _ = try body() } catch { return }; throw FolioError.invalid("Expected rejection") }

func equipmentStealthPresentationChecks() throws {
    var(p,b)=try equipmentFixture()
    p.classes[0].capabilities = .init(edition:"2024",grants:[.init(id:"armor-training",kind:.proficiency,target:"armor.medium",rank:.proficient)])
    b.equipment?.inventory=[.init(itemID:"coat",equipped:true)]
    var s=RulesEngine.evaluate(b,in:p)
    try check(s.isValid && s.equipment?.stealthDisadvantage == true,"Trained armor retains its Stealth restriction")
    try check(s.equipment?.notes.contains { $0.contains("Stealth") && $0.contains("disadvantage") } == true,"Shared native presentation notes must expose armor Stealth disadvantage")
    let sheet=PrintableSheet(record:.init(pack:p,build:b))
    try check(sheet.supplements.contains { $0.title == "Equipment and loadout" && $0.text.contains("Stealth") && $0.text.contains("disadvantage") },"Printable projection retains readable Stealth restriction")
    b.equipment?.inventory[0].equipped=false;s=RulesEngine.evaluate(b,in:p)
    try check(s.equipment?.stealthDisadvantage == false && s.equipment?.notes.contains { $0.contains("Stealth") } == false,"Unequipping removes the restriction and note")
}

func equipmentUnarmedTableSafetyChecks() throws {
    var(p,b)=try equipmentFixture()
    var strike=CapabilityGrant(id:"strike",kind:.equipment,value:.init(table:[]));strike.equipment = .init(.unarmed,ability:.cha,damageType:"radiant")
    p.classes[0].capabilities = .init(edition:"2024",grants:[strike])
    for rows in [[],[6]] as [[Int]] {
        p.classes[0].capabilities?.grants?[0].value = .init(table:rows)
        try expectThrows { try PackValidator.validate(p) }
        let result=RulesEngine.evaluate(b,in:p)
        try check(!result.isValid && result.equipment?.attacks.contains { $0.damage.contains("1d0") } != true,"Missing unarmed table coverage cannot yield a validated 1d0 attack")
    }
    p.classes[0].capabilities?.grants?[0].value=nil
    try expectThrows { try PackValidator.validate(p) }
    p.classes[0].capabilities?.grants?[0].value = .init(table:[6,6,8,8,8])
    try PackValidator.validate(p)
    var summary=RulesEngine.evaluate(b,in:p);summary.equipmentRules[0].value=0
    let projected=EquipmentEngine.evaluate(b.equipment!,in:p,summary:summary,edition:"2024")
    try check(!projected.issues.isEmpty && projected.attacks.isEmpty,"Pure projection must also fail closed on an invalid resolved unarmed die")
    p.classes[0].capabilities?.grants?[0].level=3
    p.classes[0].capabilities?.grants?[0].value = .init(table:[0,0,6,6,6])
    try PackValidator.validate(p) // Pre-unlock placeholders are not applicable levels.
}

func equipmentAdditiveCanonicalChecks() throws {
    let(p,base)=try equipmentFixture();var b=base
    b.equipment?.inventory=[.init(id:"original-band",itemID:"ring",equipped:true,attuned:true)]
    let original=CharacterRecord(pack:p,build:b)
    try check(RulesEngine.evaluate(b,in:p).isValid,"Direct-pack character begins valid")
    var revised=p;revised.version="2.0.0"
    var updated=try ContentCatalog(packs:[revised]).addingChoices(to:original)
    let newItem=updated.pack.items!.first { $0.name == "Ward band" && $0.id != "ring" }!
    updated.build.equipment?.inventory.append(.init(id:"new-band",itemID:newItem.id,equipped:true,attuned:true))
    let result=RulesEngine.evaluate(updated.build,in:updated.pack)
    try check(result.issues.contains { $0.code == "equipment-attunement-duplicate" } && result.armorClass == 13,"Direct-pack and additive source revision must share canonical item identity")
    try check(updated.pack.items?.first { $0.id == "ring" }?.canonicalID == newItem.canonicalID,"Existing source-local item gets the same stable default canonical identity")
    try check(original.pack.items?.first { $0.id == "ring" }?.canonicalID == nil && updated.build.levels == original.build.levels && updated.build.equipment?.inventory[0] == original.build.equipment?.inventory[0],"Normalization preserves original input, source-local IDs and choices")
    var explicit=p;explicit.items?[4].canonicalID="authored.ward"
    let retained=try ContentCatalog(packs:[]).addingChoices(to:.init(pack:explicit,build:b))
    try check(retained.pack.items?[4].canonicalID == "authored.ward","Explicit canonical identities remain untouched")
}

// Ignoring a saved, equipped armor row must change AC: this catches a reader
// accepting equipment but silently continuing its unarmored projection.
func equipmentArmorContractChecks() throws {
    var p = try ContentPack.sample(); p.schemaVersion = 2; p.capabilities = .init()
    p.capabilities?.required.append("equipment")
    var b = try FolioCoreTests().valid(); b.rulesProfile = .init(edition: "2024")
    var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(p)) as! [String:Any]
    json["items"] = [["id":"travel-plate", "name":"Travel plate", "edition":"2024", "kind":"armor", "weight":40, "cost":500, "training":"armor.heavy", "armorBase":18, "dexterityCap":0]]
    p = try JSONDecoder().decode(ContentPack.self, from: JSONSerialization.data(withJSONObject:json))
    var saved = try JSONSerialization.jsonObject(with: JSONEncoder().encode(b)) as! [String:Any]
    saved["equipment"] = ["inventory":[["id":"plate-row", "itemID":"travel-plate", "quantity":1, "carried":true, "equipped":true, "attuned":false]], "currency":[:]]
    b = try JSONDecoder().decode(CharacterBuild.self, from: JSONSerialization.data(withJSONObject:saved))
    let result = RulesEngine.evaluate(b,in:p)
    try check(result.armorClass == 18, "Equipped armor must replace the unarmored formula; got \(result.armorClass), \(result.issues)")
}

func equipmentFixture() throws -> (ContentPack, CharacterBuild) {
    var p = try ContentPack.sample(); p.schemaVersion=2; p.capabilities = .init(required:["equipment"])
    var b = try FolioCoreTests().valid(); b.rulesProfile = .init(edition:"2024")
    var armor=ItemDefinition(id:"coat",name:"Ridge coat",kind:.armor,weight:20,cost:1000)
    armor.training="armor.medium"; armor.armorBase=14; armor.dexterityCap=2; armor.stealthDisadvantage=true
    var shield=ItemDefinition(id:"guard",name:"Trail guard",kind:.shield,weight:6); shield.armorBase=2; shield.training="armor.shield"
    var blade=ItemDefinition(id:"blade",name:"Trail blade",kind:.weapon,weight:3)
    blade.training="weapon.simple"; blade.properties=[.finesse,.versatile]; blade.damageDice=1; blade.damageSides=6; blade.versatileSides=8; blade.damageType="slashing"; blade.mastery="Trail push"
    var heavy=blade; heavy.id="heavy"; heavy.name="Heavy trail blade"; heavy.properties=[.heavy,.twoHanded]; heavy.versatileSides=nil
    var ring=ItemDefinition(id:"ring",name:"Ward band",kind:.gear,weight:1); ring.attunement=true; ring.attunementTraining="Arcana"; ring.modifiers=[.init(id:"ward",kind:.armor,amount:1)]
    var ammo=ItemDefinition(id:"ammo",name:"Trail shafts",kind:.ammunition,weight:0.05); ammo.cost=5
    p.items=[armor,shield,blade,heavy,ring,ammo]; b.equipment = .init()
    return(p,b)
}

func equipmentDefenseChecks() throws {
    var (p,b)=try equipmentFixture()
    p.classes[0].capabilities = .init(edition:"2024",grants:[.init(id:"train",kind:.proficiency,target:"armor.shield",rank:.proficient)])
    b.equipment?.inventory=[.init(itemID:"coat",equipped:true),.init(itemID:"guard",equipped:true)]
    var s=RulesEngine.evaluate(b,in:p)
    try check(s.armorClass == 18,"14 + 2 capped DEX + 2 shield: \(s.armorClass) \(s.issues)")
    try check(s.equipment?.stealthDisadvantage == true && s.equipment?.castingRestricted == true,"Untrained armor restrictions are not an AC removal")
    b.equipment?.inventory[0].equipped=false
    s=RulesEngine.evaluate(b,in:p); try check(s.armorClass == 14,"Unarmored 12 + trained shield 2")
    p.classes[0].capabilities?.grants=[]
    s=RulesEngine.evaluate(b,in:p); try check(s.armorClass == 12,"Revised untrained shield has no AC")
    b.rulesProfile?.edition="2014"; p.classes[0].capabilities?.edition="2014"; p.items=p.items?.map { var i=$0;i.edition="2014";return i }
    s=RulesEngine.evaluate(b,in:p); try check(s.armorClass == 14 && s.equipment?.castingRestricted == true,"Legacy shield keeps AC and imposes restrictions")
    b.equipment?.inventory[1].quantity=0
    s=RulesEngine.evaluate(b,in:p); try check(s.armorClass == 12,"Zero quantity cannot grant defense")
}

func equipmentAttackAndLoadChecks() throws {
    var(p,b)=try equipmentFixture()
    p.classes[0].capabilities = .init(edition:"2024",grants:[.init(id:"weapon-training",kind:.proficiency,target:"weapon.simple",rank:.proficient)])
    b.equipment?.inventory=[.init(itemID:"blade",equipped:true,mode:.twoHanded,ability:.dex),.init(itemID:"ammo",quantity:20)]
    b.equipment?.currency=["gp":50]
    var s=RulesEngine.evaluate(b,in:p)
    try check(s.equipment?.attacks.first?.bonus == 4 && s.equipment?.attacks.first?.damage == "1d8 +2 slashing","Finesse/versatile use chosen DEX consistently")
    try check(s.equipment?.weight == 5 && s.equipment?.capacity == 150,"Carried weapon 3 + ammunition 1 + coins 1; STR10 capacity150")
    b.equipment?.inventory.append(.init(itemID:"guard",equipped:true))
    s=RulesEngine.evaluate(b,in:p); try check(s.issues.contains { $0.code == "equipment-hands" },"Two handed + shield rejected")
    b.equipment?.inventory=[.init(itemID:"heavy",equipped:true,mode:.twoHanded)]
    s=RulesEngine.evaluate(b,in:p); try check(s.equipment?.attacks.first?.notes.contains("Disadvantage: Heavy weapon requirement") == true,"Revised STR13 requirement")
    b.baseScores["str"]=15; b.baseScores["cha"]=10
    s=RulesEngine.evaluate(b,in:p); try check(s.equipment?.attacks.first?.notes.contains("Disadvantage: Heavy weapon requirement") == false,"STR15 clears revised heavy requirement")
    p.species[0].size="Small"; b.rulesProfile?.edition="2014"; p.classes[0].capabilities?.edition="2014"; p.items=p.items?.map { var i=$0;i.edition="2014";return i }
    s=RulesEngine.evaluate(b,in:p); try check(s.equipment?.attacks.first?.notes.contains("Disadvantage: Heavy weapon requirement") == true,"Legacy Small restriction ignores STR15")
}

func equipmentAttunementChecks() throws {
    var(p,b)=try equipmentFixture()
    b.equipment?.inventory=[.init(itemID:"ring",equipped:true,attuned:false)]
    var s=RulesEngine.evaluate(b,in:p); try check(s.armorClass == 12,"Unattuned magic has no modifier")
    b.equipment?.inventory[0].attuned=true
    s=RulesEngine.evaluate(b,in:p); try check(s.armorClass == 13,"Trained Arcana satisfies attunement")
    b.equipment?.inventory.append(.init(itemID:"ring",equipped:true,attuned:true))
    s=RulesEngine.evaluate(b,in:p); try check(s.armorClass == 13 && s.issues.contains { $0.code == "equipment-attunement-duplicate" },"Canonical duplicate cannot stack")
    for index in 1...3 { var copy=p.items![4];copy.id="ring-\(index)";p.items?.append(copy); b.equipment?.inventory.append(.init(itemID:copy.id,equipped:true,attuned:true)) }
    s=RulesEngine.evaluate(b,in:p); try check(s.issues.contains { $0.code == "equipment-attunement-limit" },"Default maximum three")
    b.equipment?.inventory=[.init(itemID:"ring",equipped:true,attuned:true)]; b.classSkills=["Insight","Religion"]
    s=RulesEngine.evaluate(b,in:p); try check(s.armorClass == 12 && s.issues.contains { $0.code == "equipment-attunement-prerequisite" },"Unattuned item cannot supply its own prerequisite")
}

func equipmentCatalogChecks() throws {
    let(p,b)=try equipmentFixture()
    var other=p; other.id="other-equipment";other.name="Second trail source"
    let catalog=try ContentCatalog(packs:[p,other]), snapshot=try catalog.snapshot(for:catalog.classes[0].id)
    try check(snapshot.items?.count == 12 && Set(snapshot.items!.map(\.id)).count == 12,"Same-name items retain both source-qualified identities")
    var saved=b;saved.equipment?.inventory=[.init(itemID:"blade",equipped:true,mode:.oneHanded,ability:.dex)]
    let record=CharacterRecord(pack:p,build:saved)
    let roundtrip=try JSONDecoder().decode(CharacterRecord.self,from:JSONEncoder().encode(record))
    try check(roundtrip == record,"Loadout modes/currency and pinned definitions survive Codable")
    var bad=p;bad.items?[0].weight = -1;try expectThrows { try PackValidator.validate(bad) }
    bad=p;bad.capabilities?.required=[];try expectThrows { try PackValidator.validate(bad) }
    bad=p;bad.items?[0].support = .unsupported;saved.equipment?.inventory=[.init(itemID:"coat",equipped:true)]
    try check(!RulesEngine.evaluate(saved,in:bad).isValid,"Unsupported required item sheet effects block validation")
    var itemOnly=p;itemOnly.classes=[];itemOnly.species=[];itemOnly.backgrounds=[];itemOnly.feats=[];itemOnly.spells=[];itemOnly.languages=[]
    try PackValidator.validate(itemOnly)
    let itemCatalog=try ContentCatalog(packs:[p,itemOnlyWithID(itemOnly)])
    try check(try itemCatalog.snapshot(for:itemCatalog.classes[0].id).items?.count == 12,"An item-only source joins the shared catalog")
}

private func itemOnlyWithID(_ p:ContentPack) -> ContentPack { var copy=p;copy.id="items-only";return copy }

func equipmentRuleAndHistoryChecks() throws {
    var(p,b)=try equipmentFixture()
    func rule(_ id:String,_ rule:EquipmentRule,_ value:Int,level:Int = 1,condition:RulePredicate? = nil) -> CapabilityGrant {
        var grant=CapabilityGrant(id:id,kind:.equipment,value:.init(base:value),condition:condition,level:level,text:id);grant.equipment=rule;return grant
    }
    p.classes[0].capabilities = .init(edition:"2024",grants:[
        .init(id:"defense",kind:.armorFormula,value:.init(base:10,abilities:[.con,.cha]),condition:.init(.all,children:[.init(.equipment,key:"unarmored"),.init(.equipment,key:"noShield")])),
        .init(id:"training",kind:.proficiency,target:"weapon.simple",rank:.proficient,level:2),
        rule("strike",.init(.unarmed,ability:.cha,damageType:"radiant"),6,condition:.init(.equipment,key:"unarmed")),
        rule("many-bonds",.init(.attunementLimit),4),rule("bypass",.init(.attunementEligibility,training:"Arcana"),0),
        rule("mastery-count",.init(.masteryLimit),1),rule("active-count",.init(.applicationLimit),1),
        rule("ward-recipe",.init(.recipe,itemKind:.weapon,modifiers:[.init(id:"recipe-hit",kind:.attack,amount:1)]),0),
        rule("pact-ability",.init(.weaponAbility,ability:.cha,training:"weapon.simple"),0)])
    b.equipment?.inventory=[.init(id:"blade-row",itemID:"blade",equipped:true,mode:.oneHanded,ability:.dex)]
    b.equipment?.applications=[.init(recipeID:"ward-recipe",inventoryID:"blade-row")]
    var s=RulesEngine.evaluate(b,in:p)
    try check(s.armorClass == 15 && s.equipment?.attacks.first?.bonus == 4,"Unarmored CON2+CHA3, pact CHA3+recipe1 untrained")
    try check(s.equipment?.attacks.count == 1,"Unarmed-only formula removed with weapon equipped")
    b.levels.append(LevelChoice(level:2,previous:b.levels[0]));b.levels[1].talentIDs=["listener","letter-keeper"];b.levels[1].cantripIDs=["little-beacon","paper-bird"];b.levels[1].spellIDs=["sheltering-glow","borrowed-dawn"]
    s=RulesEngine.evaluate(b,in:p)
    try check(s.equipment?.attacks.first?.bonus == 6,"Level2 training adds PB exactly once")
    try check(RulesEngine.evaluate(b,in:p,through:1).equipment?.attacks.first?.bonus == 4,"Earlier projection cannot borrow later training")
    b.equipment?.masteryItemIDs=["blade"]
    s=RulesEngine.evaluate(b,in:p);try check(s.equipment?.attacks.first?.notes.contains { $0.contains("Mastery:") } == true,"Selected mastery label")
    b.equipment?.inventory.append(.init(itemID:"guard",equipped:true));s=RulesEngine.evaluate(b,in:p)
    try check(s.armorClass == 12,"Even untrained revised shield disables no-shield alternate defense")
    b.equipment?.inventory=[];b.equipment?.applications=[];b.equipment?.masteryItemIDs=[]
    s=RulesEngine.evaluate(b,in:p);try check(s.armorClass == 15 && s.equipment?.attacks.first?.damage == "1d6 +3 radiant","Unarmed formula restores without mutating scores")
    try check(RulesEngine.evaluate(b,in:p).armorClass == 15,"Repeated equip/unequip never stacks")
    b.equipment?.applications=[.init(recipeID:"unknown",inventoryID:"none")]
    try check(RulesEngine.evaluate(b,in:p).issues.contains { $0.code == "equipment-application-eligibility" },"Unknown recipe cannot create active modifiers")
}

func equipmentStartingAndSheetChecks() throws {
    var(p,b)=try equipmentFixture()
    p.classes[0].startingEquipment=[.init(id:"start",name:"Starting kit",options:[.init(id:"gear",name:"Gear",items:["blade":1,"ammo":20]),.init(id:"money",name:"Money",gold:25)])]
    b.equipment=try EquipmentEngine.applyStartingChoices(["start":"gear"],build:b,pack:p)
    try check(b.equipment?.inventory.count == 2 && b.equipment?.currency["gp"] == 0,"Gear alternative grants no money")
    b.equipment=try EquipmentEngine.applyStartingChoices(["start":"money"],build:b,pack:p)
    try check(b.equipment?.inventory.isEmpty == true && b.equipment?.currency["gp"] == 25,"Money alternative grants no gear")
    let sheet=PrintableSheet(record:.init(pack:p,build:b))
    try check(sheet.supplements.contains { $0.title == "Equipment and loadout" && $0.text.contains("25 gp") },"Tracked currency must reach printable supplement")
    try check(sheet.fields["hp.current"] == nil,"Equipment must not fill untracked HP")
}

func equipmentPublicSmokeChecks() throws {
    let p=try ContentPack.capabilitySample()
    var b=CharacterBuild(classID:"trail-artisan");b.name="Mira · expedition loadout";b.rulesProfile = .init(edition:"2024")
    b.speciesID="roadfolk";b.backgroundID="night-guide";b.backgroundBoosts=["cha":2,"con":1];b.classSkills=["Arcana","Religion"];b.languages=["Elvish","Dwarvish"]
    b.levels[0].capabilities = .init(groups:["artisan-recipes":["artisan-sharpen"]])
    b.equipment = .init(inventory:[.init(id:"coat-row",itemID:"ridge-coat",equipped:true),.init(id:"blade-row",itemID:"trail-blade",equipped:true,mode:.oneHanded,ability:.dex),.init(id:"guard-row",itemID:"trail-guard",equipped:true),.init(id:"band-row",itemID:"ward-band",equipped:true,attuned:true),.init(id:"shafts-row",itemID:"trail-shafts",quantity:20)],currency:["gp":25,"sp":10])
    b.equipment?.masteryItemIDs=["trail-blade"];b.equipment?.applications=[.init(recipeID:"artisan-edge-recipe",inventoryID:"blade-row")]
    let summary=RulesEngine.evaluate(b,in:p)
    try check(summary.isValid && summary.armorClass == 19 && summary.equipment?.attacks.first?.bonus == 5,"Original smoke must be complete: \(summary.issues)")
    let record=CharacterRecord(pack:p,build:b)
    if let path=ProcessInfo.processInfo.environment["FOLIO_I5_SMOKE_LIBRARY"] {
        let storage=LibraryStorage(directory:URL(fileURLWithPath:path,isDirectory:true))
        guard !FileManager.default.fileExists(atPath:storage.directory.appendingPathComponent("library.json").path) else { throw FolioError.invalid("Refusing existing smoke library") }
        var library=LibraryDocument();library.packs=[p];library.characters=[record];try storage.save(library)
        let restored=try storage.load().characters.first
        try check(restored?.build.equipment == b.equipment && restored?.pack == p && restored?.build.levels == b.levels,"Smoke save/reload keeps exact pinned loadout and history")
        print("Created isolated I5 smoke library at \(path)")
    }
}

func vesselEquipmentChecks() throws {
    let url=URL(fileURLWithPath:"PrivatePacks/vessel-pack.json")
    guard FileManager.default.fileExists(atPath:url.path) else { print("SKIP vesselEquipmentChecks: private source absent");return }
    let p=try PackValidator.decode(Data(contentsOf:url))
    var b=CharacterBuild(classID:"vessel");b.rulesProfile = .init(edition:"2024");b.name="Private equipment acceptance";b.speciesID="dwarf";b.backgroundID="farmer";b.backgroundBoosts=["con":2,"wis":1];b.classSkills=["Acrobatics","Religion"];b.languages=["Elvish","Dwarvish"]
    b.levels[0].capabilities = .init(groups:["aspects":["uncanny-strength"]],configurations:["cloak","no-armor-shield"],spells:["vessel-cantrips":[],"vessel-known":[]])
    b.equipment = .init()
    var s=RulesEngine.evaluate(b,in:p)
    try check(s.isValid && s.armorClass == 14 && s.equipment?.attacks.first?.damage == "1d6 +2 radiant","Actual Vessel cloak defense and strike: \(s.issues)")
    let choices=EquipmentEngine.startingChoices(build:b,pack:p)
    try check(choices.count == 4 && choices.flatMap(\.options).allSatisfy { $0.gold == 0 },"Actual source starting choices plus fixed gear; no invented gold alternative")
    b.equipment?.inventory=[.init(itemID:"vessel-leather",equipped:true)]
    s=RulesEngine.evaluate(b,in:p);try check(s.armorClass == 13 && s.equipment?.castingRestricted == false,"Actual worn leather disables Ethereal Armor despite manual condition")
    b.equipment?.inventory=[.init(itemID:"vessel-shield",equipped:true)]
    s=RulesEngine.evaluate(b,in:p);try check(s.armorClass == 12,"Actual untrained revised shield disables Ethereal Armor without AC bonus")
    b.equipment?.inventory=[];b.levels[0].capabilities?.configurations=["cloak"]
    try check(RulesEngine.evaluate(b,in:p).armorClass == 14,"Actual inventory, not deprecated no-armor toggle, owns defense")
}

func equipmentEdgeAndMatrixChecks() throws {
    var(p,b)=try equipmentFixture()
    p.classes[0].capabilities = .init(edition:"2024",grants:[.init(id:"martial",kind:.proficiency,target:"weapon.martial",rank:.proficient)])
    p.items?[2].training="weapon.scimitar"
    b.equipment?.inventory=[.init(itemID:"blade",equipped:true,mode:.oneHanded,ability:.dex)]
    try check(RulesEngine.evaluate(b,in:p).equipment?.attacks.first?.bonus == 4,"Broad martial proficiency includes a specific scimitar training key")
    // Tiny load, negative DEX in medium armor, zero/noncarried quantities,
    // ranged Heavy and heavy-armor Strength are separate rules.
    p.items?[0].strengthMinimum=15;p.items?[0].training="armor.heavy";p.items?[0].dexterityCap=0
    b.equipment?.inventory=[.init(itemID:"coat",equipped:true),.init(itemID:"ammo",quantity:100,carried:false)]
    var s=RulesEngine.evaluate(b,in:p);try check(s.speed == 20 && s.equipment?.weight == 20,"Heavy armor speed penalty does not depend on Heavy weapon property; stored ammo weight excluded")
    p.species[0].size="Tiny";s=RulesEngine.evaluate(b,in:p);try check(s.equipment?.capacity == 75,"Tiny carrying capacity halves")
    p.items?[0].dexterityCap=2;b.baseScores["dex"]=8;b.baseScores["int"]=14
    s=RulesEngine.evaluate(b,in:p);try check(s.armorClass == 13,"Medium armor preserves negative DEX modifiers")
    p.items?[3].properties=[.heavy,.ranged,.twoHanded];b.equipment?.inventory=[.init(itemID:"heavy",equipped:true,mode:.twoHanded)]
    s=RulesEngine.evaluate(b,in:p);try check(s.equipment?.attacks.first?.notes.contains("Disadvantage: Heavy weapon requirement") == true,"Ranged Heavy checks DEX13, not Strength")
    let condition=RulePredicate(.all,children:[.init(.equipment,key:"unarmored"),.init(.equipment,key:"noShield")])
    p.classes[0].capabilities?.grants=[.init(id:"unarmored-motion",kind:.speed,value:.init(base:10),condition:condition)]
    b.equipment?.inventory=[];try check(RulesEngine.evaluate(b,in:p).speed == 40,"Monk-style unarmored movement")
    b.equipment?.inventory=[.init(itemID:"guard",equipped:true)];try check(RulesEngine.evaluate(b,in:p).speed == 30,"Shield restricts movement even when it gives no AC")
}

func equipmentDefenseSelectionChecks() throws {
    var(p,b)=try equipmentFixture()
    p.classes[0].capabilities = .init(edition:"2024",grants:[.init(id:"alternate-defense",kind:.armorFormula,value:.init(base:10,abilities:[.con,.cha]),condition:.init(.equipment,key:"unarmored"))])
    var json=try JSONSerialization.jsonObject(with:JSONEncoder().encode(b)) as! [String:Any]
    json["equipment"]=["inventory":[],"currency":[:],"defenseID":"unarmored"]
    b=try JSONDecoder().decode(CharacterBuild.self,from:JSONSerialization.data(withJSONObject:json))
    try check(RulesEngine.evaluate(b,in:p).armorClass == 12,"Explicit ordinary unarmored formula must be selectable instead of the best alternate")
}

func equipmentBoundWeaponChecks() throws {
    var(p,b)=try equipmentFixture()
    var grant=CapabilityGrant(id:"bound-weapon",kind:.equipment,text:"Bound weapon");grant.equipment = .init(.weaponAbility,ability:.cha,training:"weapon.simple");grant.equipment?.requiresBinding=true
    p.classes[0].capabilities = .init(edition:"2024",grants:[grant])
    b.equipment?.inventory=[.init(id:"first",itemID:"blade",equipped:true,mode:.oneHanded,ability:.dex),.init(id:"second",itemID:"blade",equipped:true,mode:.oneHanded,ability:.dex)]
    b.equipment?.weaponBindings=["bound-weapon":"second"]
    let s=RulesEngine.evaluate(b,in:p)
    try check(s.equipment?.attacks.map(\.bonus) == [2,3],"Pact-style substitution applies only to the explicitly bound weapon, not both")
}

func equipmentExceptionsAndApplicationsChecks() throws {
    var(p,b)=try equipmentFixture()
    func effect(_ id:String,_ rule:EquipmentRule,_ n:Int) -> CapabilityGrant { var g=CapabilityGrant(id:id,kind:.equipment,value:.init(base:n));g.equipment=rule;return g }
    p.classes[0].capabilities = .init(edition:"2024",grants:[effect("four-bonds",.init(.attunementLimit),4),effect("eligibility",.init(.attunementEligibility,training:"Arcana"),0),effect("limit",.init(.applicationLimit),1),effect("recipe",.init(.recipe,itemKind:.weapon,modifiers:[.init(id:"edge",kind:.attack,amount:1)]),0)])
    b.classSkills=["Insight","Religion"]
    for i in 1...3 { var item=p.items![4];item.id="band-\(i)";p.items?.append(item) }
    b.equipment?.inventory=["ring","band-1","band-2","band-3"].map { .init(itemID:$0,equipped:true,attuned:true) }
    var s=RulesEngine.evaluate(b,in:p)
    try check(s.isValid && s.armorClass == 13 && s.equipment?.attuned == 4,"Explicit count/prerequisite exceptions permit four distinct bands; shared modifier does not stack: \(s.issues)")
    p.items?[2].modifiers=[.init(id:"edge",kind:.attack,amount:1)]
    b.equipment?.inventory=[.init(id:"blade",itemID:"blade",equipped:true,mode:.oneHanded,ability:.dex)]
    b.equipment?.applications=[.init(recipeID:"recipe",inventoryID:"blade")]
    s=RulesEngine.evaluate(b,in:p)
    try check(s.equipment?.attacks.first?.bonus == 3,"Canonical modifier shared by item and recipe applies exactly once")
    b.equipment?.applications?.append(.init(recipeID:"recipe",inventoryID:"blade"))
    try check(RulesEngine.evaluate(b,in:p).issues.contains { $0.code == "equipment-application-limit" },"Active applications obey declared limits")
    b.equipment?.applications=[.init(recipeID:"recipe",inventoryID:"blade")];p.classes[0].capabilities?.grants?.removeAll { $0.id == "recipe" }
    try check(RulesEngine.evaluate(b,in:p).issues.contains { $0.code == "equipment-application-eligibility" },"Earlier removal of known recipe invalidates retained application")
}

func equipmentQualifiedProjectionChecks() throws {
    let source=try ContentPack.capabilitySample(),catalog=try ContentCatalog(packs:[source])
    let cls=catalog.classes.first { $0.name == "Trail Artisan" }!
    let p=try catalog.snapshot(for:cls.id)
    var b=CharacterBuild(classID:cls.id);b.rulesProfile = .init(edition:"2024");b.name="Qualified equipment"
    b.speciesID=p.species.first { $0.name == source.species.first { $0.id == "roadfolk" }!.name }!.id
    b.backgroundID=p.backgrounds.first { $0.name == source.backgrounds.first { $0.id == "night-guide" }!.name }!.id
    b.backgroundBoosts=["cha":2,"con":1];b.classSkills=["Arcana","Religion"];b.languages=["Elvish","Dwarvish"]
    let group=p.classes.first { $0.id == cls.id }!.capabilities!.groups![0],option=group.options[0]
    b.levels[0].capabilities = .init(groups:[group.id:[option.id]])
    let blade=p.items!.first { $0.name == "Trail blade" }!
    b.equipment = .init(inventory:[.init(id:"row",itemID:blade.id,equipped:true,mode:.oneHanded,ability:.dex)])
    b.equipment?.applications=[.init(recipeID:option.grants[0].id,inventoryID:"row")]
    let s=RulesEngine.evaluate(b,in:p)
    try check(s.isValid && s.equipment?.attacks.first?.bonus == 5,"Qualified recipe, item and modifier identity must work together: \(s.issues)")
    let encoded=try LibraryStorage.encoder.encode(CharacterRecord(pack:p,build:b)),roundtrip=try LibraryStorage.decodeCharacter(encoded)
    try check(roundtrip.build.equipment == b.equipment && RulesEngine.evaluate(roundtrip.build,in:roundtrip.pack).equipment?.attacks.first?.bonus == 5,"Exported qualified loadout roundtrip preserves applied effect")
    var bad=source;bad.items?[0].damageSides = -1
    try expectThrows { try PackValidator.validate(bad) }
    bad=source;var malformed=CapabilityGrant(id:"bad-strike",kind:.equipment,value:.init(base:3));malformed.equipment = .init(.unarmed,ability:.cha,damageType:"radiant")
    bad.classes[0].capabilities?.grants?.append(malformed)
    try expectThrows { try PackValidator.validate(bad) }
}
