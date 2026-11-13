import Foundation
import FolioCore

// JSON authoring checks exercise decoding before the new contract exists.
func castingFixture() throws -> (ContentPack, CharacterBuild) {
    var (p,b) = try highLevelFixture()
    p.capabilities?.required = ["spell-pools"]
    let policy: [String:Any] = ["id":"study", "name":"Notebook", "mode":"book", "ability":"int", "spellIDs":["sheltering-glow","borrowed-dawn"], "counts":Array(repeating:2,count:20), "maximumSpellLevels":Array(repeating:1,count:20), "preparedCounts":Array(repeating:1,count:20), "loadout":"editable", "poolIDs":["ordinary"]]
    let pool: [String:Any] = ["id":"ordinary", "name":"Study slots", "kind":"ordinary", "recovery":"long rest", "capacities":Array(repeating:["1":2,"9":1],count:20)]
    var obj = try JSONSerialization.jsonObject(with: JSONEncoder().encode(p)) as! [String:Any]
    var classes = obj["classes"] as! [[String:Any]]
    classes[0]["capabilities"] = ["edition":"2024", "casting":[policy], "spellPools":[pool]]
    obj["classes"] = classes
    p = try JSONDecoder().decode(ContentPack.self,from:JSONSerialization.data(withJSONObject:obj))
    b.levels[0].capabilities = .init(spells:["study":["sheltering-glow","borrowed-dawn"]],prepared:["study":["sheltering-glow"]])
    return (p,b)
}

func withLoadout(_ build: CharacterBuild, _ ids: [String]) throws -> CharacterBuild {
    var obj = try JSONSerialization.jsonObject(with:JSONEncoder().encode(build)) as! [String:Any]
    obj["castingLoadouts"] = ["study":ids]
    return try JSONDecoder().decode(CharacterBuild.self,from:JSONSerialization.data(withJSONObject:obj))
}

func spellLoadoutChecks() throws {
    let (p,b) = try castingFixture()
    let edited = try withLoadout(b,["borrowed-dawn"])
    let result = RulesEngine.evaluate(edited,in:p)
    try check(result.isValid,"Valid loadout: \(result.issues)")
    try check(result.spellLabels["borrowed-dawn"]?.contains("Prepared") == true,"Editable preparation must override historical preparation")
    try check(result.spells.count == 2 && edited.levels == b.levels,"Book membership and history must survive edits")
    let invalid = RulesEngine.evaluate(try withLoadout(b,["trail-whisper"]),in:p)
    try check(invalid.issues.contains { $0.code == "cap-loadout-study" },"Only book members can be prepared")
}

func spellPoolProjectionChecks() throws {
    let (p,b) = try castingFixture()
    let sheet = PrintableSheet(record:.init(pack:p,build:b))
    try check(sheet.fields["slots.9"] == "1" && sheet.fields["slots.1"] == "2","Ordinary tier capacities must project independently")
    try check(sheet.supplements.contains { $0.title.contains("Spell pools") && $0.text.contains("long rest") },"Pools need labeled recovery")
}

func spellMultipleAbilityChecks() throws {
    var (p,b) = try castingFixture()
    p.species[0].capabilities = .init(edition:"2024",casting:[.init(id:"innate",name:"Innate",mode:.atWill,ability:.cha,spellIDs:["little-beacon"],counts:[1],maximumSpellLevels:[0])])
    b.levels[0].capabilities?.spells?["innate"] = ["little-beacon"]
    let s = RulesEngine.evaluate(b,in:p)
    try check(s.isValid,"Different source abilities must be representable: \(s.issues)")
    try check(s.spellDC == nil && s.spellAttack == nil,"Never collapse two casting abilities into a misleading legacy scalar")
}

func spellRetainedAndGrantChecks() throws {
    var (p,b) = try castingFixture()
    p.classes[0].capabilities?.casting?[0].mode = .prepared
    p.classes[0].capabilities?.casting?[0].loadout = .retained
    p.classes[0].capabilities?.casting?[0].counts = Array(repeating:1,count:20)
    b.levels[0].capabilities?.spells?["study"] = ["sheltering-glow"]
    b.levels.append(.init(level:2,previous:b.levels[0]))
    b.levels[1].capabilities?.spells?["study"] = ["borrowed-dawn"]
    try check(RulesEngine.evaluate(b,in:p).issues.contains { $0.code == "cap-casting-replacement-study" },"Retained Prepared label does not permit free replacement")
    var (innate,character) = try highLevelFixture()
    innate.species[0].capabilities = .init(edition:"2024",grants:[.init(id:"innate-ray",kind:.spell,target:"little-beacon",ability:.wis)])
    character.baseScores["wis"] = 12
    let s = RulesEngine.evaluate(character,in:innate)
    try check(s.castingSources.contains { $0.id == "innate-ray" && $0.ability == .wis && $0.dc == 11 },"Innate grants project their own source ability, not the class ability")
}

func spellMixedLegacySourceChecks() throws {
    var p=try ContentPack.sample(); p.schemaVersion=2; p.capabilities = .init()
    p.classes[0].capabilities = .init(edition:"2024")
    p.species[0].capabilities = .init(edition:"2024",grants:[.init(id:"native-light",kind:.spell,target:"little-beacon",ability:.wis)])
    var b=try FolioCoreTests().valid(2); b.rulesProfile = .init(edition:"2024")
    let s=RulesEngine.evaluate(b,in:p)
    try check(s.isValid && Set(s.castingSources.map(\.ability)) == [.cha,.wis] && s.spellDC == nil,"Legacy class casting alongside innate capability must not silently inherit the innate DC")
    try check(s.slots==2 && s.slotLevel==1,"Legacy uniform fields remain intact")
}

func spellMixedLegacyPoolChecks() throws {
    var p=try ContentPack.sample(); p.schemaVersion=2; p.capabilities = .init(required:["spell-pools"])
    p.classes[0].capabilities = .init(edition:"2024")
    p.species[0].capabilities = .init(edition:"2024")
    p.species[0].capabilities?.spellPools=[.init(id:"native-charge",name:"Native charge",kind:.limited,recovery:"long rest",capacities:[[1:1],[1:1],[1:1]])]
    var b=try FolioCoreTests().valid(2); b.rulesProfile = .init(edition:"2024")
    let s=RulesEngine.evaluate(b,in:p)
    try check(s.isValid && s.spellPools.count==2,"Independent typed capacity must not hide legacy class slots")
    let legacy=s.spellPools.first { $0.sourceID == b.classID }
    try check(legacy?.capacities == [1:2] && legacy?.kind == .custom && legacy?.recovery == "Unspecified (legacy source)","Fallback preserves capacity without inventing recovery or ordinary/pact kind")
    try check(s.spellPools.first { $0.id == "native-charge" }?.sourceID == b.speciesID && s.spellPools.first { $0.id == "native-charge" }?.recovery == "long rest","Independent source/recovery stays distinct")
    let sheet=PrintableSheet(record:.init(pack:p,build:b))
    try check(sheet.supplements.contains { $0.title == "Spell pools" && $0.text.contains("Tier 1: 2") && $0.text.contains("Native charge") && $0.text.contains("Unspecified (legacy source)") },"PDF supplements preserve both capacities")
    p.classes[0].capabilities?.casting=[.init(id:"old-known-policy",name:"Legacy policy",mode:.known,ability:.cha,spellIDs:[],counts:[0,0,0],maximumSpellLevels:[0,0,0])]
    try check(RulesEngine.evaluate(b,in:p).spellPools.count==2,"Existing capability acquisition without a typed class pool retains its uniform capacity")
    p.classes[0].capabilities?.casting=[]
    // Same-source typed class capacity replaces the compatibility scalar, never adds it.
    p.classes[0].capabilities?.spellPools=[.init(id:"class-pool",name:"Class pool",kind:.pact,recovery:"short rest",capacities:[[1:2],[1:2],[1:2]])]
    let typed=RulesEngine.evaluate(b,in:p)
    try check(typed.isValid && typed.spellPools.count==2 && !typed.spellPools.contains { $0.recovery == "Unspecified (legacy source)" },"Typed class replacement is not double-counted")
    p.classes[0].capabilities?.spellPools=[]
    p.classes[0].subclasses[0].capabilities=p.species[0].capabilities; p.species[0].capabilities=nil
    b=try FolioCoreTests().valid(3); b.rulesProfile = .init(edition:"2024")
    try check(RulesEngine.evaluate(b,in:p).spellPools.count==2,"Subclass-owned independent capacity also preserves legacy slots")
    p.classes[0].subclasses[0].capabilities?.casting=[.init(id:"sub-innate",name:"Subclass innate",mode:.limited,ability:.wis,spellIDs:["paper-bird"],counts:[0,0,1],maximumSpellLevels:[0,0,0])]
    p.classes[0].subclasses[0].capabilities?.casting?[0].poolIDs=["native-charge"]
    p.classes[0].subclasses[0].capabilities?.casting?[0].legacyClassCasting = .preserve
    b.levels[2].capabilities = .init(spells:["sub-innate":["paper-bird"]])
    let additive=RulesEngine.evaluate(b,in:p)
    try check(additive.isValid && additive.spellPools.count==2,"Independent subclass casting policy must not consume the unrepresented class pool")
    let legacyIDs=Set(b.levels[2].spellIDs+b.levels[2].cantripIDs)
    try check(legacyIDs.isSubset(of:Set(additive.spells.map(\.id))),"Independent subclass policy must preserve the legacy learned and cantrip roster")
    try check(additive.castingSources.contains { $0.sourceID==b.classID && $0.ability == .cha && $0.dc==13 } && additive.castingSources.contains { $0.id=="sub-innate" && $0.ability == .wis && $0.dc==11 } && additive.spellDC==nil,"Both actual casting abilities remain source-owned")
    let additiveSheet=PrintableSheet(record:.init(pack:p,build:b))
    try check(additiveSheet.supplements.contains { $0.title.contains("legacy casting") && $0.text.contains("Borrowed Dawn") } && additiveSheet.supplements.contains { $0.title.contains("Subclass innate") && $0.text.contains("Wisdom") },"PDF retains legacy roster/source alongside additive subclass ability")
    var invalid=b; invalid.levels[1].spellIDs=["lantern-bridge","borrowed-dawn"]
    try check(RulesEngine.evaluate(invalid,in:p).issues.contains { $0.code=="spell-level-lantern-bridge" && $0.level==2 },"Additive subclass policies cannot erase earlier legacy acquisition validation")
    // Older snapshots retain their old implicit subclass replacement contract.
    var old=p; old.capabilities?.required=[]; old.classes[0].subclasses[0].capabilities?.spellPools=nil
    old.classes[0].subclasses[0].capabilities?.casting?[0].poolIDs=nil
    old.classes[0].subclasses[0].capabilities?.casting?[0].legacyClassCasting=nil
    try check(!RulesEngine.evaluate(b,in:old).spells.contains { $0.id=="borrowed-dawn" },"Pre-pool snapshots do not silently change subclass replacement semantics")
    let extra=try ContentCatalog(packs:[ContentPack.capabilitySample()])
    let expanded=try extra.addingChoices(to:.init(pack:old,build:b))
    try check(expanded.pack.capabilities?.required.contains("spell-pools")==true && !RulesEngine.evaluate(expanded.build,in:expanded.pack).spells.contains { $0.id=="borrowed-dawn" },"Adding unrelated capability content cannot change pinned implicit subclass replacement")
    let additiveExpanded=try extra.addingChoices(to:.init(pack:p,build:b))
    try check(legacyIDs.isSubset(of:Set(RulesEngine.evaluate(additiveExpanded.build,in:additiveExpanded.pack).spells.map(\.id))),"Explicit preserve policy survives additive catalog expansion")
    let sourceCatalog=try ContentCatalog(packs:[p])
    let qualified=try sourceCatalog.snapshot(for:sourceCatalog.classes[0].id)
    try check(qualified.classes[0].subclasses[0].capabilities?.casting?[0].legacyClassCasting == .preserve,"Catalog qualification retains the per-policy interaction declaration")
    let restored=try LibraryStorage.decodeCharacter(LibraryStorage.encoder.encode(CharacterRecord(pack:p,build:b)))
    try check(legacyIDs.isSubset(of:Set(RulesEngine.evaluate(restored.build,in:restored.pack).spells.map(\.id))),"Pinned roundtrip preserves additive legacy acquisition")
    old.classes[0].subclasses[0].capabilities?.casting?[0].legacyClassCasting = .preserve
    var rejected=false
    do { try PackValidator.validate(old) } catch { rejected=true }
    try check(rejected,"Explicit legacy interaction requires spell-pools capability gating even without other new fields")
}

func spellFallbackIdentityChecks() throws {
    var p=try ContentPack.sample(); p.schemaVersion=2; p.capabilities = .init(required:["spell-pools"])
    p.classes[0].capabilities = .init(edition:"2024")
    var b=try FolioCoreTests().valid(2); b.rulesProfile = .init(edition:"2024")
    let base=b.classID+":legacy-slots"
    var policy=CastingPolicy(id:"native-casting",name:"Native casting",mode:.limited,ability:.wis,spellIDs:["little-beacon"],counts:[1,1],maximumSpellLevels:[0,0])
    policy.poolIDs=[base]
    p.species[0].capabilities = .init(edition:"2024",casting:[policy])
    p.species[0].capabilities?.spellPools=[
        .init(id:base,name:"Authored base",kind:.limited,recovery:"long rest",capacities:[[1:1],[1:1]]),
        .init(id:base+"#1",name:"Authored suffix",kind:.custom,recovery:"short rest",capacities:[[2:1],[2:1]]),
        .init(id:base+"#2",name:"Reserved inactive",kind:.custom,recovery:"long rest",capacities:[[3:1],[3:1]],condition:.init(.level,minimum:3))
    ]
    for index in b.levels.indices { b.levels[index].capabilities = .init(spells:["native-casting":["little-beacon"]]) }
    let s=RulesEngine.evaluate(b,in:p)
    try check(s.isValid && s.spellPools.count==3 && Set(s.spellPools.map(\.id)).count==3,"Synthetic legacy pool must not collide with authored base or suffix IDs")
    let fallback=s.spellPools.first { $0.sourceID==b.classID }!
    try check(![base,base+"#1",base+"#2"].contains(fallback.id) && fallback.capacities == [1:2],"Fallback avoids inactive authored identities without losing capacity")
    try check(s.castingSources.first { $0.id=="native-casting" }?.poolIDs == [base] && s.castingSources.first { $0.id==b.classID+":legacy" }?.poolIDs == [fallback.id],"Authored and generated references resolve to distinct intended pools")
    let record=try LibraryStorage.decodeCharacter(LibraryStorage.encoder.encode(CharacterRecord(pack:p,build:b)))
    let replay=RulesEngine.evaluate(record.build,in:record.pack)
    try check(replay.spellPools==s.spellPools && replay.castingSources==s.castingSources && RulesEngine.evaluate(b,in:p).spellPools==s.spellPools,"Generated identities and references are deterministic across replay and roundtrip")
}

func spellPoolSafetyChecks() throws {
    let (p,b) = try castingFixture()
    func rejected(_ pack:ContentPack) -> Bool { do { try PackValidator.validate(pack); return false } catch { return true } }
    var invalid=p; invalid.capabilities?.required=[]
    try check(rejected(invalid),"New casting mechanics require evaluator capability gating")
    invalid=p; invalid.classes[0].capabilities?.spellPools?[0].recovery=""
    try check(rejected(invalid),"Missing recovery is not an implicit merged pool")
    invalid=p; invalid.classes[0].capabilities?.spellPools?[0].capacities=[[10:1]]
    try check(rejected(invalid),"Tier range is bounded")
    invalid=p; invalid.classes[0].capabilities?.casting?[0].preparedCounts=nil; invalid.classes[0].capabilities?.casting?[0].preparation = .init(base:Int.max)
    try check(rejected(invalid),"Preparation expression must be bounded before arithmetic")
    var malformed=b; malformed.castingLoadouts=[String(repeating:"x",count:121):[]]
    var didReject=false
    do { try PackValidator.validateRecord(.init(pack:p,build:malformed)) } catch { didReject=true }
    try check(didReject,"Saved loadouts must have bounded keys")
    var legacy=try FolioCoreTests().valid(); legacy.castingLoadouts=["study":[]]
    try check(!RulesEngine.evaluate(legacy,in:try ContentPack.sample()).isValid,"Legacy evaluation cannot silently ignore a new loadout")
}

// Arithmetic references: SRD 5.2.1 pp77/53/71 and SRD 5.1 pp52/30/46.
// Original spell content only; these tables do not certify commercial subclasses.
let fullCastingRows = [[2],[3],[4,2],[4,3],[4,3,2],[4,3,3],[4,3,3,1],[4,3,3,2],[4,3,3,3,1],[4,3,3,3,2],[4,3,3,3,2,1],[4,3,3,3,2,1],[4,3,3,3,2,1,1],[4,3,3,3,2,1,1],[4,3,3,3,2,1,1,1],[4,3,3,3,2,1,1,1],[4,3,3,3,2,1,1,1,1],[4,3,3,3,3,1,1,1,1],[4,3,3,3,3,2,1,1,1],[4,3,3,3,3,2,2,1,1]]
func tiers(_ rows:[[Int]]) -> [[Int:Int]] { rows.map { Dictionary(uniqueKeysWithValues:$0.enumerated().map { ($0.offset+1,$0.element) }) } }
func twentyLevels(_ original: CharacterBuild) -> CharacterBuild {
    var b=original
    for at in 2...20 { b.levels.append(.init(level:at,previous:b.levels.last)); if at>=3 { b.levels[at-1].subclassID="waylight" } }
    return b
}

func spellProgressionTableChecks() throws {
    var (p,b)=try castingFixture(); b=twentyLevels(b)
    let full=tiers(fullCastingRows)
    let revisedHalf=tiers([[2],[2],[3],[3],[4,2],[4,2],[4,3],[4,3],[4,3,2],[4,3,2],[4,3,3],[4,3,3],[4,3,3,1],[4,3,3,1],[4,3,3,2],[4,3,3,2],[4,3,3,3,1],[4,3,3,3,1],[4,3,3,3,2],[4,3,3,3,2]])
    var legacyHalf=revisedHalf; legacyHalf[0]=[:]
    let pact=(1...20).map { at in [min(5,(at+1)/2):(at==1 ? 1 : at<11 ? 2 : at<17 ? 3 : 4)] }
    // Authored original fractional/custom progression, not an inferred official subclass.
    let fractional=(1...20).map { at in at<3 ? [:] : [min(4,(at+3)/6):2] }
    for (name,rows,kind) in [("full",full,SpellPool.Kind.ordinary),("half revised",revisedHalf,.ordinary),("half legacy",legacyHalf,.ordinary),("pact",pact,.pact),("fractional original",fractional,.custom)] {
        p.classes[0].capabilities?.spellPools?[0].capacities=rows
        p.classes[0].capabilities?.spellPools?[0].kind=kind
        for at in 1...20 {
            let s=RulesEngine.evaluate(b,in:p,through:at)
            try check(s.isValid && s.spellPools.first?.capacities == rows[at-1],"\(name) exact level \(at): \(s.issues)")
        }
    }
    p.classes[0].capabilities?.spellPools?[0].capacities=full
    var high=p.spells[0]; high.id="distant-spark"; high.name="Distant Spark"; high.level=9; p.spells.append(high)
    p.classes[0].capabilities?.casting?[0].spellIDs.append(high.id)
    b.levels[19].capabilities?.spells?["study"]=["sheltering-glow",high.id]
    try check(RulesEngine.evaluate(b,in:p).issues.contains { $0.code == "cap-casting-option-distant-spark" },"Tier-nine capacity never unlocks tier-nine book knowledge")
    p.classes[0].capabilities?.spellPools?[0].capacities=Array(full.prefix(19))
    try check(RulesEngine.evaluate(b,in:p).issues.contains { $0.code == "cap-pool-row-ordinary" },"Missing table rows must not extrapolate")
}

func spellSourceAndSaveChecks() throws {
    var (p,b)=try castingFixture()
    b.updatedAt=Date(timeIntervalSince1970:1_000)
    var subPolicy=CastingPolicy(id:"sub-echo",name:"Second voice",mode:.limited,ability:.cha,spellIDs:["little-beacon"],counts:[0,0,1],maximumSpellLevels:[0,0,0])
    subPolicy.poolIDs=["echo-pool"]
    p.classes[0].subclasses[0].capabilities = .init(edition:"2024",casting:[subPolicy])
    p.classes[0].subclasses[0].capabilities?.spellPools=[.init(id:"echo-pool",name:"Echo charge",kind:.limited,recovery:"short rest",capacities:[[:],[:],[1:1]])]
    for at in 2...3 { b.levels.append(.init(level:at,previous:b.levels.last)) }
    b.levels[2].subclassID="waylight"; b.levels[2].capabilities?.spells?["sub-echo"]=["little-beacon"]
    b.castingLoadouts=["study":["borrowed-dawn"]]
    let s=RulesEngine.evaluate(b,in:p)
    try check(s.isValid && s.spellPools.count==2 && Set(s.castingSources.map(\.dc)) == [9,13],"Subclass uses independent capacity/CHA vs book INT: \(s.issues)")
    try check(RulesEngine.evaluate(b,in:p,through:2).spellPools.count==1,"Subclass pool does not leak before unlock")
    try check(RulesEngine.evaluate(b,in:p,through:2).castingSources.first?.selectedLoadout == ["sheltering-glow"],"Historical view ignores current loadout")
    let restored=try LibraryStorage.decodeCharacter(LibraryStorage.encoder.encode(CharacterRecord(pack:p,build:b)))
    try check(restored.build == b && restored.pack == p,"Pinned pool, acquired membership and editable loadout roundtrip")
    try check(RulesEngine.evaluate(restored.build,in:restored.pack).castingSources == s.castingSources,"Replay is deterministic")
    var edited=b; edited.levels[0].capabilities?.spells?["study"]=["borrowed-dawn"]
    try check(RulesEngine.evaluate(edited,in:p).issues.contains { $0.code == "cap-casting-count-study" && $0.level == 1 },"Current preparation cannot repair invalid earlier acquisition")
    var other=p; other.id="another-source"; other.version="2"
    let catalog=try ContentCatalog(packs:[p,other])
    let snapshot=try catalog.snapshot(for:catalog.classes[0].id)
    let policies=snapshot.classes.compactMap { $0.capabilities?.casting?.first }
    try check(Set(policies.map(\.id)).count==2 && Set(policies.flatMap { $0.poolIDs ?? [] }).count==2,"Pool and acquisition identities are source-qualified")
    try check(Set(policies.flatMap(\.spellIDs)).count==4,"Same-name spell definitions never merge")
    let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:folder) }
    let store=LibraryStorage(directory:folder); var library=LibraryDocument(); library.packs=[p]; library.characters=[restored]
    try store.save(library); library.characters[0].build.castingLoadouts=["study":[]]; try store.save(library)
    try check(try store.load().characters[0].build.castingLoadouts?["study"] == [],"Incomplete preparation persists as draft")
    try check(FileManager.default.fileExists(atPath:folder.appendingPathComponent("library.previous.json").path),"Loadout save preserves prior-file backup")
}

func spellPublicSmokeChecks() throws {
    let p=try ContentPack.capabilitySample()
    guard let cls=p.classes.first(where: { $0.id=="notebook-keeper" }) else { throw FolioError.invalid("Missing public casting laboratory") }
    var b=CharacterBuild(classID:cls.id); b.name="Mira · Notebook & Echo"; b.rulesProfile = .init(edition:"2024")
    b.speciesID="roadfolk"; b.backgroundID="night-guide"; b.backgroundBoosts=["cha":2,"con":1]; b.classSkills=["Arcana","Religion"]; b.languages=["Elvish","Dwarvish"]
    b.levels[0].capabilities = .init(spells:["notebook-study":["sheltering-glow","borrowed-dawn"]],prepared:["notebook-study":["sheltering-glow"]])
    for at in 2...3 { b.levels.append(.init(level:at,previous:b.levels.last)) }
    b.levels[2].subclassID=cls.subclasses[0].id; b.levels[2].capabilities?.spells?["echo-voice"]=["little-beacon"]
    b.castingLoadouts=["notebook-study":["borrowed-dawn"]]
    let s=RulesEngine.evaluate(b,in:p)
    try check(s.isValid && s.spellPools.count==2 && s.castingSources.count==2,"Public dual-source smoke fixture: \(s.issues)")
    if let path=ProcessInfo.processInfo.environment["FOLIO_I3_SMOKE_LIBRARY"] {
        let storage=LibraryStorage(directory:URL(fileURLWithPath:path))
        guard !FileManager.default.fileExists(atPath:storage.file.path) else { throw FolioError.invalid("Smoke target must be an unused disposable directory") }
        var library=LibraryDocument(); library.packs=[p]; library.characters=[.init(pack:p,build:b)]
        try storage.save(library); print("Original casting smoke library: \(storage.file.path)")
    }
}

func vesselSpellPoolChecks() throws {
    let url=URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("PrivatePacks/vessel-pack.json")
    guard FileManager.default.fileExists(atPath:url.path) else { print("SKIP actual Vessel spell pools: private input absent"); return }
    let p=try JSONDecoder().decode(ContentPack.self,from:Data(contentsOf:url)), c=p.classes[0]
    let pool=c.capabilities!.spellPools!.first!
    try check(pool.kind == .pact && pool.recovery == "short or long rest","Vessel retains independent source pact capacity")
    for row in c.progression {
        try check(pool.capacities[row.level-1] == (row.slots==0 ? [:] : [row.slotLevel:row.slots]),"Actual half-speed source rows, not Warlock or ordinary rounding")
    }
    let ascended=c.subclasses.first { $0.id=="the-ascended" }!.capabilities!
    try check(ascended.casting!.first!.loadout == .editable && ascended.casting!.first!.poolIDs == [pool.id],"Ascended changes preparation, not slot pool")
    try check(ascended.spellPools!.count==2 && ascended.spellPools![0].capacities[14] == [5:1] && ascended.spellPools![1].capacities[19] == [6:1],"Arcanum 15/20 exact independent tiers and capacity")
    try check(ascended.spellPools!.allSatisfy { $0.kind == .limited && $0.recovery == "long rest" },"Arcanum is not extra ordinary/pact slots")
    let minor=c.capabilities!.groups!.first!.options.first { $0.id=="minor-magick" }!
    try check(minor.repeatable==true && minor.grants.contains { $0.kind == .resource && $0.target?.contains("distinct Sealed Magic") == true } && !(c.capabilities!.casting ?? []).contains { $0.id.contains("minor-magick") },"Minor Magick remains distinct cast-time Sealed Magic choices, not permanent learned spells")
    let definitions=[c.capabilities!] + c.subclasses.compactMap(\.capabilities)
    var allGrants:[CapabilityGrant]=[]
    for definition in definitions {
        allGrants += definition.grants ?? []
        for group in definition.groups ?? [] { allGrants += group.options.flatMap(\.grants) }
    }
    let spellGrants=allGrants.filter { $0.kind == .spell }
    try check(spellGrants.allSatisfy { $0.ability == .cha },"Every actual Vessel feature-casting source, including Aspects and Trickster, owns Charisma")
}

func spellNineTierOverflowChecks() throws {
    var (p,b)=try castingFixture(); b=twentyLevels(b)
    p.classes[0].capabilities?.spellPools?[0].capacities=tiers(fullCastingRows)
    var ids:[String]=[]
    for i in 1...35 { var spell=p.spells[0]; spell.id="original-note-\(i)"; spell.name="Original note \(i)"; spell.level=1; p.spells.append(spell); ids.append(spell.id) }
    p.classes[0].capabilities?.casting?[0].spellIDs=ids
    p.classes[0].capabilities?.casting?[0].counts=Array(repeating:35,count:20)
    for i in b.levels.indices { b.levels[i].capabilities?.spells?["study"]=ids; b.levels[i].capabilities?.prepared?["study"]=[ids[0]] }
    let sheet=PrintableSheet(record:.init(pack:p,build:b))
    try check(!sheet.isDraft,"Overflow fixture valid")
    for tier in 1...9 { try check(sheet.fields["slots.\(tier)"] == String(fullCastingRows[19][tier-1]),"Every ordinary PDF tier populated") }
    try check(sheet.fields["spell.34.name"] != nil && sheet.supplements.contains { $0.title == "Casting — Notebook" && $0.text.contains("original-note-35") && $0.text.contains("Spellbook") },"Overflow retains source identity, ability, membership and classification")
}

func spellAlwaysGrantedChecks() throws {
    var (p,b) = try castingFixture()
    p.classes[0].capabilities?.casting?[0].alwaysGrantedSpellIDs = ["trail-whisper"]
    let s = RulesEngine.evaluate(b,in:p)
    try check(s.isValid && s.spells.count == 3 && s.grantedSpellIDs.contains("trail-whisper"),"Always granted addition does not spend preparation/book picks")
    b.castingLoadouts=["study":["trail-whisper"]]
    try check(RulesEngine.evaluate(b,in:p).issues.contains { $0.code == "cap-loadout-study" },"Always granted cannot spend a preparation slot")
    p.classes[0].capabilities?.casting?[0].mode = .prepared
    p.classes[0].capabilities?.casting?[0].counts = Array(repeating:1,count:20)
    b.castingLoadouts=["study":["borrowed-dawn"]]
    let prep = RulesEngine.evaluate(b,in:p)
    try check(prep.isValid && prep.castingSources.first?.memberSpellIDs.count == 2,"List preparation has available membership, not permanent acquisition")
    try check(!prep.spells.contains { $0.id == "sheltering-glow" },"Unprepared available list spell is not falsely learned")
}

func spellClassificationAndIdentityChecks() throws {
    var (p,b)=try castingFixture()
    var grant=CapabilityGrant(id:"mastered-note",kind:.spell,target:"sheltering-glow")
    grant.spellMode = .atWill
    p.classes[0].capabilities?.grants=[grant]
    let s=RulesEngine.evaluate(b,in:p)
    try check(s.spellLabels["sheltering-glow"]?.contains("At will") == true && s.spellLabels["sheltering-glow"]?.contains("Prepared") == true,"Book preparation cannot erase the independent at-will grant classification")
    p.species[0].capabilities = .init(edition:"2024",casting:[p.classes[0].capabilities!.casting![0]])
    p.species[0].capabilities?.casting?[0].poolIDs=[]
    var rejected=false
    do { try PackValidator.validate(p) } catch { rejected=true }
    try check(rejected,"A policy identity cannot silently select two unrelated source definitions")
    b.castingLoadouts=["unknown-source":[]]
    try check(RulesEngine.evaluate(b,in:try castingFixture().0).issues.contains { $0.code == "cap-loadout-unknown-source" },"Unknown loadout source remains visible and invalid")
}

func spellPreparationFormulaChecks() throws {
    var (p,b)=try castingFixture()
    p.classes[0].capabilities?.casting?[0].preparedCounts=nil
    p.classes[0].capabilities?.casting?[0].preparation = .init(abilities:[.int],levelMultiplier:1,minimum:1)
    for at in 2...3 { b.levels.append(.init(level:at,previous:b.levels.last)) }
    b.levels[2].subclassID="waylight"; b.castingLoadouts=["study":["sheltering-glow","borrowed-dawn"]]
    let s=RulesEngine.evaluate(b,in:p)
    try check(s.isValid && s.castingSources.first?.preparationCount==2,"Legacy-style level plus INT preparation uses source formula")
    p.classes[0].capabilities?.grants=[.init(id:"insight",kind:.abilityScore,target:"int",value:.init(base:2))]
    let boosted=RulesEngine.evaluate(b,in:p)
    try check(boosted.castingSources.first?.preparationCount==3 && boosted.castingSources.first?.dc==10 && boosted.issues.contains { $0.code == "cap-loadout-study" },"Final adjusted ability drives both source DC and preparation allowance")
}
