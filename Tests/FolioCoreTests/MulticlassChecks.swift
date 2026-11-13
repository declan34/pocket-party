import Foundation
import FolioCore

func multiclassReplayChecks() throws {
    var (p,b) = try highLevelFixture()
    p.classes[0].subclassLevel = 20
    p.classes[0].hitDie = 12
    p.capabilities?.required = ["multiclass"]
    p.classes[0].multiclass = .init(canonicalID:"lantern-keeper",casting:.init(kind:.none))
    var second = p.classes[0]; second.id = "ink-guard"; second.name = "Ink Guard"; second.hitDie = 6
    second.multiclass?.canonicalID = "ink-guard"
    p.classes.append(second)
    b.levels.append(.init(level: 2))
    var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(b)) as! [String:Any]
    var rows = json["levels"] as! [[String:Any]]
    rows[0]["classID"] = b.classID; rows[1]["classID"] = second.id; json["levels"] = rows
    b = try JSONDecoder().decode(CharacterBuild.self, from: JSONSerialization.data(withJSONObject: json))
    let result = RulesEngine.evaluate(b, in:p)
    // First level maximizes only the starting die; later class entry uses average.
    try check(result.hitPoints == 22, "Expected 12+2 + 4+2 plus two species HP, got \(result.hitPoints)")
    try check(result.isValid,"Mixed martial replay: \(result.issues)")
    try check(result.classLevels.map(\.level) == [1,1] && result.hitDice == [12:1,6:1],"Ordered class levels and separate hit dice")
}

func multiclassCastingChecks() throws {
    var (p,b)=try castingFixture()
    p.capabilities?.required.append("multiclass")
    p.classes[0].subclassLevel=20
    p.classes[0].multiclass = .init(canonicalID:"notebook",casting:.init(kind:.ordinary,poolIDs:["ordinary"]))
    p.classes[0].capabilities?.spellPools?[0].capacities=Array(repeating:[1:2],count:20)
    var second=p.classes[0]; second.id="song-keeper"; second.name="Song Keeper"; second.multiclass?.canonicalID="song"
    second.capabilities?.spellPools?[0].id="song-pool"
    second.capabilities?.casting?[0].id="song-study"; second.capabilities?.casting?[0].poolIDs=["song-pool"]; second.capabilities?.casting?[0].ability = .cha
    second.multiclass?.casting?.poolIDs=["song-pool"]
    p.classes.append(second)
    b.levels[0].classID=b.classID
    var row=LevelChoice(level:2); row.classID=second.id
    row.capabilities = .init(spells:["song-study":["sheltering-glow","borrowed-dawn"]],prepared:["song-study":["borrowed-dawn"]]); b.levels.append(row)
    let s=RulesEngine.evaluate(b,in:p)
    try check(s.isValid,"Two ordinary casters: \(s.issues)")
    try check(s.spellPools.count == 1 && s.spellPools[0].capacities == [1:3],"Ordinary classes share caster-level-two capacity")
    try check(s.castingSources.count == 2 && s.castingSources.allSatisfy { $0.maximumSpellLevel == 1 },"Capacity does not raise class access")
    p.classes[1].multiclass?.casting = .init(kind:.independent,poolIDs:["song-pool"],reciprocalSlotUse:true)
    p.classes[1].capabilities?.spellPools?[0].kind = .pact
    let pact=RulesEngine.evaluate(b,in:p)
    try check(pact.isValid && pact.spellPools.count == 2 && pact.spellPools.contains { $0.kind == .pact },"Pact remains independent")
    p.classes[1].multiclass?.casting=nil
    try check(RulesEngine.evaluate(b,in:p).issues.contains { $0.code == "multiclass-casting-song-keeper" },"Unknown custom contribution must block")
}

func multiclassMartialFixture() throws -> (ContentPack,CharacterBuild) {
    var (p,b)=try highLevelFixture()
    p.capabilities?.required=["multiclass"]
    p.classes[0].features=[]; p.classes[0].hitDie=12
    p.classes[0].capabilities?.grants=[.init(id:"a-focus",kind:.resource,target:"A focus",value:.init(levelMultiplier:1),recovery:"long rest")]
    p.classes[0].multiclass = .init(canonicalID:"original.a",prerequisites:.init(.ability,key:"con",minimum:13),laterProficiencies:[.init(id:"a-training",kind:.proficiency,target:"simple weapons",rank:.proficient)],casting:.init(kind:.none))
    p.classes[0].multiclass?.startingProficiencies=[.init(id:"a-starting",kind:.proficiency,target:"heavy armor",rank:.proficient)]
    var second=p.classes[0]; second.id="ink-guard"; second.name="Ink Guard"; second.hitDie=6; second.saves=[.int,.wis]
    second.multiclass = .init(canonicalID:"original.b",prerequisites:.init(.ability,key:"cha",minimum:13),laterProficiencies:[.init(id:"b-training",kind:.proficiency,target:"light armor",rank:.proficient)],casting:.init(kind:.none))
    second.multiclass?.startingProficiencies=[.init(id:"b-starting",kind:.proficiency,target:"ink tools",rank:.proficient)]
    second.capabilities?.grants=[.init(id:"b-focus",kind:.resource,target:"B focus",value:.init(levelMultiplier:1),recovery:"long rest")]
    p.classes.append(second); b.levels[0].classID=b.classID
    return (p,b)
}

func multiclassHistoryChecks() throws {
    var (p,b)=try multiclassMartialFixture()
    let a=b.classID, other=p.classes[1].id
    p.classes[0].progression[3].improvement=true
    p.classes[1].progression[1].improvement=true
    p.feats[p.feats.firstIndex { $0.id == "ability-improvement" }!].repeatable=true
    for (index,id) in [a,other,a,other,a,a].enumerated() {
        if index == 0 { continue }
        var row=LevelChoice(level:index+1,previous:b.levels.last { $0.classID == id }); row.classID=id
        let local=b.levels.filter { $0.classID == id }.count+1
        if local>=3 { row.subclassID=p.classes.first { $0.id == id }!.subclasses[0].id }
        if (id == other && local == 2) || (id == a && local == 4) { row.featID="ability-improvement"; row.boosts=["con":1,"str":1] }
        b.levels.append(row)
    }
    let s=RulesEngine.evaluate(b,in:p)
    try check(s.isValid,"Per-class improvement/subclass progression: \(s.issues)")
    try check(s.classLevels.map(\.level)==[4,2] && s.proficiency==3,"PB is total; advancement is class-local")
    try check(s.resources.first { $0.id == "a-focus" }?.maximum==4 && s.resources.first { $0.id == "b-focus" }?.maximum==2,"Class-local values do not scale with other class levels")
    try check(s.classLevels[0].subclassID=="waylight" && s.classLevels[1].subclassID.isEmpty,"Independent subclass unlocks")
    try check(s.proficiencyRanks["heavy armor"] == .proficient && s.proficiencyRanks["light armor"] == .proficient && s.proficiencyRanks["ink tools"] == nil,"Starting vs later training")
    try check(s.proficiencyRanks["save.int"] == nil,"Later class does not grant starting saves")
    let saved=b.levels
    b.levels[1].classID=a
    let invalid=RulesEngine.evaluate(b,in:p)
    try check(!invalid.isValid && b.levels[3].featID==saved[3].featID,"Earlier class edits retain invalidated feats/history")
    b.levels=saved
    try check(RulesEngine.evaluate(b,in:p).hitPoints==s.hitPoints,"Replay deterministic")
    b.levels[3].boosts=["dex":1,"str":1]
    try check(RulesEngine.evaluate(b,in:p).hitPoints==s.hitPoints-6,"Constitution effects apply retroactively across all hit-die sizes")
}

func multiclassEntryAndIdentityChecks() throws {
    var (p,b)=try multiclassMartialFixture()
    let other=p.classes[1].id
    let next=try RulesEngine.advance(b,in:p,classID:other)
    try check(next.levels[1].classID==other && next.levels[1].subclassID.isEmpty,"New class starts fresh choices")
    var invalid=b; invalid.baseScores["cha"]=8; invalid.baseScores["int"]=15
    var threw=false; do { _=try RulesEngine.advance(invalid,in:p,classID:other) } catch { threw=true }
    try check(threw,"Entry prerequisite rejects before appending")
    invalid=next; invalid.baseScores["cha"]=8; invalid.baseScores["int"]=15
    p.classes[1].capabilities?.grants?.append(.init(id:"entry-score",kind:.abilityScore,target:"cha",value:.init(base:4)))
    try check(RulesEngine.evaluate(invalid,in:p).issues.contains { $0.code.hasPrefix("multiclass-prerequisite") && $0.level==2 },"Entering class cannot fund its own entry; earlier edits invalidate")
    p.classes[1].capabilities?.grants?.removeLast()
    let canonical=p.classes[0].multiclass!.canonicalID
    p.classes[1].multiclass?.canonicalID=canonical
    try check(RulesEngine.evaluate(next,in:p).issues.contains { $0.code.hasPrefix("multiclass-canonical") },"Same canonical class rejected regardless of selected identity")
    p.classes[1].capabilities?.edition="2014"
    p.classes[1].capabilities?.adapters=[.init(edition:"2024",canonicalID:"adapted-ink",label:"Explicit test adapter")]
    try check(RulesEngine.evaluate(next,in:p).issues.contains { $0.code.hasPrefix("multiclass-canonical") },"Edition adapter cannot bypass class canonical identity")
    p.classes[1].multiclass?.canonicalID="other"
    p.classes[1].capabilities?.adapters=[]
    try check(RulesEngine.evaluate(next,in:p).issues.contains { $0.code=="cap-edition-ink-guard" },"Cross-edition class needs explicit adapter")
    p.classes[1].capabilities?.edition="2024"
    b.classID=other; b.levels[0].classID=other
    let reverse=try RulesEngine.advance(b,in:p,classID:p.classes[0].id)
    let s=RulesEngine.evaluate(reverse,in:p)
    try check(s.hitPoints == 19 && s.proficiencyRanks["heavy armor"] == nil && s.proficiencyRanks["ink tools"] == .proficient,"Starting order changes HP and training: \(s.hitPoints)")
}

func multiclassRoundingChecks() throws {
    for (divisor,rounding,expected) in [(2,CasterContribution.Rounding.up,2),(2,.down,1),(3,.down,1),(4,.up,1)] {
        let policy=CasterContribution(kind:.ordinary,divisor:divisor,rounding:rounding)
        try check(policy.contribution(at:3)==expected,"Declared contribution divisor/rounding")
    }
    var (p,b)=try castingFixture()
    p.capabilities?.required.append("multiclass")
    p.classes[0].subclassLevel=20
    p.classes[0].multiclass = .init(canonicalID:"half",casting:.init(kind:.ordinary,divisor:2,rounding:.up,poolIDs:["ordinary"]))
    var martial=p.classes[0]; martial.id="plain-guard"; martial.name="Plain Guard"; martial.capabilities = .init(edition:"2024"); martial.multiclass = .init(canonicalID:"martial",casting:.init(kind:.none))
    p.classes.append(martial)
    var row=LevelChoice(level:2); row.classID=martial.id; b.levels.append(row)
    let solo=RulesEngine.evaluate(b,in:p)
    try check(solo.isValid && solo.spellPools.first?.capacities == [1:2,9:1],"Martial plus one caster retains authored table, never combined ordinary progression")
    let caster=p.classes[0].id
    for level in 3...4 { var row=LevelChoice(level:level,previous:b.levels.first); row.classID=caster; b.levels.append(row) }
    p.classes[1].capabilities?.spellPools=[.init(id:"other-pool",name:"Other pool",kind:.ordinary,recovery:"long rest",capacities:Array(repeating:[1:2],count:20))]
    p.classes[1].multiclass?.casting = .init(kind:.ordinary,poolIDs:["other-pool"])
    let up=RulesEngine.evaluate(b,in:p)
    try check(up.isValid && up.spellPools.first?.capacities == [1:4,2:2],"Revised half 3 + full 1 gives caster 3")
    p.classes[0].multiclass?.casting?.rounding = .down
    let down=RulesEngine.evaluate(b,in:p)
    try check(down.isValid && down.spellPools.first?.capacities == [1:3],"Legacy half 3 + full 1 gives caster 2")
    p.ruleset="2014"; b.rulesProfile = .init(edition:"2014"); b.backgroundBoosts=[:]; b.languages=[]
    for i in p.classes.indices { p.classes[i].capabilities?.edition="2014" }
    try check(RulesEngine.evaluate(b,in:p).isValid && RulesEngine.evaluate(b,in:p).spellPools.first?.capacities == [1:3],"Pinned 2014 profile uses declared legacy contribution")
    p.classes[0].multiclass?.casting?.divisor=3
    try check(RulesEngine.evaluate(b,in:p).spellPools.first?.capacities == [1:3],"Generic fractional contribution uses declared denominator")
}

func multiclassPersistenceChecks() throws {
    let (p,b)=try multiclassMartialFixture()
    var next=try RulesEngine.advance(b,in:p,classID:p.classes[1].id)
    next.updatedAt=Date(timeIntervalSince1970:1_700_000_000)
    let record=CharacterRecord(pack:p,build:next)
    let data=try LibraryStorage.encoder.encode(record)
    let restored=try LibraryStorage.decodeCharacter(data)
    try check(restored==record,"Export roundtrip pins class choices and policies")
    let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:dir) }
    var library=LibraryDocument(); library.characters=[record]; library.packs=[p]
    let storage=LibraryStorage(directory:dir); try storage.save(library)
    try check(try storage.load().characters[0]==record,"Atomic library save/reload preserves history")
    let catalog=try ContentCatalog(packs:[p]); let snapshot=try catalog.snapshot(for:catalog.classes.first { $0.name==p.classes[0].name }!.id)
    var qualified=next
    let a=snapshot.classes.first { $0.name==p.classes[0].name }!, other=snapshot.classes.first { $0.name==p.classes[1].name }!
    qualified.classID=a.id; qualified.levels[0].classID=a.id; qualified.levels[1].classID=other.id
    qualified.speciesID=snapshot.species.first { $0.name==p.species.first { $0.id==b.speciesID }?.name }!.id
    qualified.backgroundID=snapshot.backgrounds.first { $0.name==p.backgrounds.first { $0.id==b.backgroundID }?.name }!.id
    try check(RulesEngine.evaluate(qualified,in:snapshot).isValid,"Source-qualified multiclass policy and training survive catalog")
    try check(a.multiclass?.canonicalID==p.classes[0].multiclass?.canonicalID,"Canonical class is not source-qualified")
    var noGate=p; noGate.capabilities?.required=[]
    var rejected=false; do { try PackValidator.validate(noGate) } catch { rejected=true }
    try check(rejected,"New policy cannot silently pass an older capability evaluator")
}

func multiclassPublicSmokeChecks() throws {
    let p=try ContentPack.capabilitySample()
    var b=CharacterBuild(classID:"summit-warden")
    b.name="Mira · two paths"; b.rulesProfile = .init(edition:"2024")
    b.speciesID="roadfolk"; b.backgroundID="night-guide"; b.backgroundBoosts=["cha":2,"con":1]
    b.baseScores=["str":10,"dex":14,"con":13,"int":15,"wis":12,"cha":8]
    b.classSkills=["Arcana","Religion"]; b.languages=["Elvish","Dwarvish"]; b.levels[0].classID=b.classID
    b=try RulesEngine.advance(b,in:p,classID:"notebook-keeper")
    b.levels[1].capabilities = .init(spells:["notebook-study":["sheltering-glow","borrowed-dawn"]],prepared:["notebook-study":["sheltering-glow"]])
    b=try RulesEngine.advance(b,in:p,classID:"notebook-keeper")
    b=try RulesEngine.advance(b,in:p,classID:"summit-warden")
    let summary=RulesEngine.evaluate(b,in:p)
    try check(summary.isValid && summary.classLevels.map(\.level)==[2,2],"Public original mixed-class fixture: \(summary.issues)")
    let record=CharacterRecord(pack:p,build:b), sheet=PrintableSheet(record:.init(pack:p,build:b))
    try check(sheet.fields["class"]=="Summit Warden 2 / Notebook Keeper 2" && sheet.supplements.contains { $0.title=="Class levels and hit dice" },"Mixed-class sheet projection")
    try check(StoryPrompt.make(record:record,kind:"backstory").contains("Notebook Keeper 2"),"Factual narrative context includes every class")
    if let path=ProcessInfo.processInfo.environment["FOLIO_I4_SMOKE_LIBRARY"] {
        let storage=LibraryStorage(directory:URL(fileURLWithPath:path,isDirectory:true))
        guard !FileManager.default.fileExists(atPath:storage.directory.appendingPathComponent("library.json").path) else { throw FolioError.invalid("Refusing to overwrite smoke library") }
        var library=LibraryDocument(); library.packs=[p]; library.characters=[record]; try storage.save(library)
        print("Created isolated I4 smoke library at \(path)")
    }
}

func multiclassSharedChoiceChecks() throws {
    var (p,b)=try multiclassMartialFixture()
    let group=CapabilityChoiceGroup(id:"global-road",name:"Road language",counts:Array(repeating:1,count:20),options:[.init(id:"road-choice",name:"Road choice",grants:[.init(id:"road-language",kind:.language,target:"Road Speech")])],locked:true)
    p.capabilities?.required.append("languages")
    p.species[0].capabilities = .init(edition:"2024",groups:[group])
    b.levels[0].capabilities = .init(groups:["global-road":["road-choice"]])
    p.classes[1].multiclass?.laterSkillCount=1
    var next=try RulesEngine.advance(b,in:p,classID:p.classes[1].id)
    try check(next.levels[1].capabilities?.groups?["global-road"]==["road-choice"],"New class inherits global choices, not only its own last row")
    next.levels[1].multiclassSkills=["Medicine"]
    var s=RulesEngine.evaluate(next,in:p)
    try check(s.isValid && s.skills.contains("Medicine"),"Later entry skill choice: \(s.issues)")
    next.levels[1].multiclassSkills=["Arcana"]
    try check(RulesEngine.evaluate(next,in:p).issues.contains { $0.code=="multiclass-skills" },"Entry skill cannot repeat prior proficiency")
    next.levels[1].multiclassSkills=["Medicine"]
    let feature=try JSONDecoder().decode(Feature.self,from:Data(#"{"id":"a-attack","canonicalID":"original.extra-attack","name":"Extra attack","level":1,"text":"Original nonstacking feature example."}"#.utf8))
    p.classes[0].features=[feature]; var other=feature; other.id="b-attack"; p.classes[1].features=[other]
    let grant=CapabilityGrant(id:"shared-trait",kind:.armorBonus,value:.init(base:1))
    p.classes[0].capabilities?.grants?.append(grant); p.classes[1].capabilities?.grants?.append(grant)
    s=RulesEngine.evaluate(next,in:p)
    try check(s.features.filter { $0.canonicalID=="original.extra-attack" }.count==1 && s.armorClass==13,"Nonstacking canonical feature and shared grant identity")
    p.classes[0].capabilities?.groups=[.init(id:"own-track",name:"Owned",counts:Array(repeating:0,count:20),options:[])]
    next.levels[1].capabilities?.groups?["own-track"]=[]
    try check(RulesEngine.evaluate(next,in:p).issues.contains { $0.code=="cap-foreign-choice" && $0.level==2 },"Changing class retains foreign choices as explicit issues")
    try check(next.levels[1].capabilities?.groups?["own-track"] != nil,"Evaluation does not delete stale history")
}

func multiclassBoundaryChecks() throws {
    var (p,b)=try multiclassMartialFixture()
    for i in p.classes.indices { p.classes[i].subclassLevel=20 }
    for at in 2...20 { b=try RulesEngine.advance(b,in:p,classID:p.classes[(at-1)%2].id) }
    try check(RulesEngine.evaluate(b,in:p).isValid && RulesEngine.evaluate(b,in:p).classLevels.map(\.level)==[10,10],"Twenty total levels across classes")
    var rejected=false; do { _=try RulesEngine.advance(b,in:p,classID:p.classes[1].id) } catch { rejected=true }
    try check(rejected,"Total cap remains twenty even with unused class rows")
    let before=RulesEngine.evaluate(b,in:p,through:4)
    try check(before.proficiency==2 && before.classLevels.map(\.level)==[2,2],"Through query retains historical class totals")
    b.levels[1].classID="unknown"
    try check(!RulesEngine.evaluate(b,in:p).isValid,"Unknown saved class cannot evaluate silently")
}

func multiclassSubclassContextChecks() throws {
    var (p,b)=try multiclassMartialFixture()
    p.classes[0].subclassLevel=1
    p.classes[1].capabilities?.grants?.append(.init(id:"own-subclass-only",kind:.resource,target:"Own subclass only",value:.init(base:9),condition:.init(.subclass,key:"waylight")))
    b.levels[0].subclassID="waylight"
    b=try RulesEngine.advance(b,in:p,classID:p.classes[1].id)
    let s=RulesEngine.evaluate(b,in:p)
    try check(s.isValid && !s.resources.contains { $0.id=="own-subclass-only" },"Class-local subclass predicates must not match another class's same local ID")
}

func multiclassPriorCapabilitySkillChecks() throws {
    var (p,b)=try multiclassMartialFixture()
    p.classes[1].multiclass?.laterSkillCount=1
    p.species[0].capabilities = .init(edition:"2024",grants:[.init(id:"prior-medicine",kind:.proficiency,target:"Medicine",rank:.proficient)])
    b=try RulesEngine.advance(b,in:p,classID:p.classes[1].id)
    b.levels[1].multiclassSkills=["Medicine"]
    let duplicate=RulesEngine.evaluate(b,in:p)
    try check(duplicate.issues.contains { $0.code=="cap-multiclass-skill-Medicine" && $0.level==2 },"A prior capability proficiency cannot spend the later-class new-skill choice")
    b.levels[1].multiclassSkills=["Persuasion"]
    try check(RulesEngine.evaluate(b,in:p).isValid,"A genuinely new entry skill remains valid")
    b.levels[1].multiclassSkills=["Medicine"]
    p.species[0].capabilities?.grants?[0].rank = .expertise
    try check(!RulesEngine.evaluate(b,in:p).isValid,"Prior expertise is already proficient")
    p.species[0].capabilities?.grants?[0].rank = .half
    try check(RulesEngine.evaluate(b,in:p).isValid,"Half proficiency does not consume the new-skill opportunity")
    p.species[0].capabilities?.grants?[0].rank = .proficient
    p.species[0].capabilities?.grants?[0].level=3
    try check(RulesEngine.evaluate(b,in:p).isValid,"Future capability training cannot retroactively invalidate entry")
    p.species[0].capabilities?.grants?[0].level=1
    p.species[0].capabilities?.grants?[0].condition = .init(.ability,key:"str",minimum:12)
    p.classes[0].progression[1].improvement=true
    p.feats[p.feats.firstIndex { $0.id=="ability-improvement" }!].minimumLevel=1
    var improved=b; improved.levels=[b.levels[0],LevelChoice(level:2,previous:b.levels[0])]
    improved.levels[1].featID="ability-improvement"; improved.levels[1].boosts=["str":2]
    var entry=b.levels[1]; entry.level=3; improved.levels.append(entry)
    try check(RulesEngine.evaluate(improved,in:p).issues.contains { $0.code=="cap-multiclass-skill-Medicine" && $0.level==3 },"Prior proficiency uses final post-ASI ability context")
    improved.levels[1].boosts=["dex":2]
    try check(RulesEngine.evaluate(improved,in:p).isValid,"Earlier edit deactivating conditional training restores a genuinely new entry skill")
}

func multiclassTrackOwnershipChecks() throws {
    var (p,b)=try multiclassMartialFixture()
    let shared=CapabilityChoiceGroup(id:"training",name:"Training",counts:Array(repeating:0,count:20),options:[])
    p.classes[0].capabilities?.groups=[shared]; p.classes[1].capabilities?.groups=[shared]
    func rejected(_ pack: ContentPack,_ text: String) throws {
        var message=""
        do { try PackValidator.validate(pack) } catch { message=error.localizedDescription }
        try check(message.contains(text) && message.contains("ownership"),"Explicit multiclass track ownership rejection: \(text); got \(message)")
    }
    try rejected(p,"training")
    p.classes[0].capabilities?.groups=[]; p.classes[1].capabilities?.groups=[]
    p.classes[0].capabilities?.configurations=[.init(id:"stance",name:"First stance")]
    p.classes[1].capabilities?.configurations=[.init(id:"stance",name:"Second stance")]
    try rejected(p,"stance")
    // Older packs may reuse class-local IDs. No renaming or new global import ban.
    for i in p.classes.indices { p.classes[i].multiclass=nil }
    try PackValidator.validate(p)
    b.levels[0].classID=nil; b.levels[0].capabilities = .init(configurations:["stance"])
    try check(RulesEngine.evaluate(b,in:p).isValid,"Existing single-class snapshot with reused local IDs still evaluates")
    let data=try JSONEncoder().encode(CharacterRecord(pack:p,build:b))
    let copy=try JSONDecoder().decode(CharacterRecord.self,from:data)
    try check(copy.build==b && copy.pack==p,"Legacy IDs/history are unchanged by roundtrip")
}

func multiclassCombinedOwnershipChecks() throws {
    var (p,b)=try multiclassMartialFixture()
    func group(_ id: String) -> CapabilityChoiceGroup { .init(id:id,name:id,counts:Array(repeating:0,count:20),options:[]) }
    p.classes[0].capabilities?.groups=[group("training")]
    p.classes[1].capabilities?.groups=[group("other-training")]
    var unrelated=p.classes[1]; unrelated.id="unrelated"; unrelated.name="Unrelated Class"; unrelated.multiclass?.canonicalID="original.unrelated"
    unrelated.capabilities?.groups=[group("training")]
    p.classes.insert(unrelated,at:0) // catches accidental keep-first ownership.
    p.sources=[ContentSource(pack:p)]
    b.levels[0].capabilities = .init(groups:["training":[]])
    try PackValidator.validateRecord(.init(pack:p,build:b))
    try check(RulesEngine.evaluate(b,in:p).isValid,"Unrelated colliding combined-library class cannot change a pinned single-class build")
    let original=b
    b=try RulesEngine.advance(b,in:p,classID:"ink-guard")
    try check(RulesEngine.evaluate(b,in:p).isValid,"Unselected colliding owner is excluded from multiclass replay")
    var message=""; do { _=try RulesEngine.advance(b,in:p,classID:"unrelated") } catch { message=error.localizedDescription }
    try check(message.contains("ownership") && message.contains("training") && message.contains("Unrelated Class"),"Activation rejects the conflicting owner with an author-actionable error")
    var row=LevelChoice(level:3); row.classID="unrelated"; b.levels.append(row)
    try check(RulesEngine.evaluate(b,in:p).issues.contains { $0.code=="cap-invalid-content" && $0.message.contains("ownership") },"Conflicting loaded history fails before any track aliasing")
    b=original; p.classes.removeFirst()
    p.species[0].capabilities = .init(edition:"2024",groups:[group("training")])
    try check(RulesEngine.evaluate(b,in:p).isValid,"Existing combined single-class/common IDs are not silently rewritten")
    message=""; do { _=try RulesEngine.advance(b,in:p,classID:"ink-guard") } catch { message=error.localizedDescription }
    try check(message.contains("ownership") && message.contains("shared species/background/feat"),"Class/common ownership conflict becomes explicit at multiclass activation")
    p.classes[0].capabilities?.groups=[group("first-training")]; b.levels[0].capabilities = .init()
    p.backgrounds[0].capabilities = .init(edition:"2024",groups:[group("training")])
    b=try RulesEngine.advance(b,in:p,classID:"ink-guard")
    try check(RulesEngine.evaluate(b,in:p).isValid,"Intentional common canonical tracks share one owner and do not trigger class conflicts")
}

func multiclassCatalogOwnershipChecks() throws {
    var (first,b)=try multiclassMartialFixture()
    first.classes[0].capabilities?.groups=[.init(id:"training",name:"Training",counts:Array(repeating:0,count:20),options:[])]
    var second=first; second.id="second-owner-source"; second.name="Second owner source"
    second.classes=[first.classes[1]]; second.classes[0].capabilities?.groups=first.classes[0].capabilities?.groups
    first.classes=Array(first.classes.prefix(1))
    let catalog=try ContentCatalog(packs:[first,second])
    let snapshot=try catalog.snapshot(for:catalog.classes.first { $0.name==first.classes[0].name }!.id)
    let a=snapshot.classes.first { $0.name==first.classes[0].name }!, other=snapshot.classes.first { $0.name==second.classes[0].name }!
    try check(a.capabilities!.groups![0].id != other.capabilities!.groups![0].id,"Independent sources still qualify same local track IDs differently")
    b.classID=a.id; b.levels[0].classID=a.id
    b.speciesID=snapshot.species.first { $0.name==first.species.first { $0.id==b.speciesID }?.name }!.id
    b.backgroundID=snapshot.backgrounds.first { $0.name==first.backgrounds.first { $0.id==b.backgroundID }?.name }!.id
    b=try RulesEngine.advance(b,in:snapshot,classID:other.id)
    try check(RulesEngine.evaluate(b,in:snapshot).isValid,"Source-qualified catalog combination remains legitimate")
}

func vesselMulticlassChecks() throws {
    let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let url=root.appendingPathComponent("PrivatePacks/vessel-pack.json")
    guard FileManager.default.fileExists(atPath:url.path) else { print("SKIP vesselMulticlassChecks: private adapter absent"); return }
    var p=try PackValidator.decode(Data(contentsOf:url))
    let vessel=p.classes[0], policy=vessel.multiclass
    try check(policy?.casting?.kind == .independent && policy?.casting?.reciprocalSlotUse == true && policy?.casting?.poolIDs == ["vessel-pact"],"Actual Vessel explicitly does not contribute to ordinary slots")
    try check(policy?.laterProficiencies.map(\.target)==["armor.light","weapon.simple"] && policy?.startingProficiencies?.count==4,"Source-reviewed entry versus first training uses equipment keys")
    let (original,_)=try multiclassMartialFixture()
    var guardClass=original.classes[0]; guardClass.id="original-guard"; guardClass.name="Original Guard"; guardClass.subclassLevel=20
    p.classes.append(guardClass)
    var b=CharacterBuild(classID:guardClass.id); b.rulesProfile = .init(edition:"2024")
    b.speciesID="dwarf"; b.backgroundID="farmer"; b.backgroundBoosts=["con":2,"wis":1]; b.classSkills=["Arcana","Religion"]; b.languages=["Elvish","Dwarvish"]
    b=try RulesEngine.advance(b,in:p,classID:vessel.id)
    b.levels[1].capabilities = .init(groups:["aspects":["uncanny-strength"]],configurations:["no-armor-shield","cloak"],spells:["vessel-cantrips":[],"vessel-known":[]])
    let first=RulesEngine.evaluate(b,in:p)
    try check(first.isValid && first.proficiencyRanks["weapon.scimitar"]==nil && first.proficiencyRanks["armor.light"] == .proficient,"Later Vessel grants reduced training: \(first.issues)")
    b=try RulesEngine.advance(b,in:p,classID:vessel.id)
    let cantrips=vessel.capabilities!.casting!.first { $0.id=="vessel-cantrips" }!.spellIDs.filter { id in p.spells.contains { $0.id==id && $0.unavailableReason==nil } }
    let spells=vessel.capabilities!.casting!.first { $0.id=="vessel-known" }!.spellIDs.filter { id in p.spells.contains { $0.id==id && $0.level==1 && $0.unavailableReason==nil } }
    b.levels[2].capabilities?.groups?["aspects"]=["uncanny-strength","spirit-sense"]
    b.levels[2].capabilities?.spells=["vessel-cantrips":Array(cantrips.prefix(2)),"vessel-known":Array(spells.prefix(2))]
    let s=RulesEngine.evaluate(b,in:p)
    try check(s.isValid && s.spellPools.contains { $0.id=="vessel-pact" && $0.capacities==[1:2] },"Actual Vessel class-local pool retained independently: \(s.issues)")
    b.baseScores["con"]=8; b.baseScores["int"]=13
    try check(RulesEngine.evaluate(b,in:p).issues.contains { $0.code=="multiclass-prerequisite-vessel" },"Actual CON 13 entry requirement replays after earlier score edit")
}
