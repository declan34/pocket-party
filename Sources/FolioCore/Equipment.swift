import Foundation

public struct ItemDefinition: Codable, Sendable, Hashable, Identifiable {
    public enum Kind: String, Codable, Sendable { case armor, shield, weapon, ammunition, gear }
    public enum Property: String, Codable, Sendable { case finesse, versatile, twoHanded, heavy, ranged, ammunition, light, thrown }
    public enum Support: String, Codable, Sendable { case supported, manual, unsupported }
    public var id: String
    public var name: String
    public var edition: String
    public var kind: Kind
    public var weight: Double
    /// Cost in copper pieces. No shopping, sale or automatic expenditure.
    public var cost: Int
    public var canonicalID: String? = nil
    public var training: String? = nil
    public var properties: [Property]? = nil
    public var armorBase: Int? = nil
    public var dexterityCap: Int? = nil
    public var strengthMinimum: Int? = nil
    public var stealthDisadvantage: Bool? = nil
    public var damageDice: Int? = nil
    public var damageSides: Int? = nil
    public var versatileSides: Int? = nil
    public var damageType: String? = nil
    public var mastery: String? = nil
    public var attunement: Bool? = nil
    public var attunementTraining: String? = nil
    public var modifiers: [ItemModifier]? = nil
    public var support: Support? = nil
    public var text: String? = nil
    public init(id: String, name: String, edition: String = "2024", kind: Kind, weight: Double = 0, cost: Int = 0) {
        self.id=id; self.name=name; self.edition=edition; self.kind=kind; self.weight=weight; self.cost=cost
    }
}

public struct ItemModifier: Codable, Sendable, Hashable, Identifiable {
    public enum Kind: String, Codable, Sendable { case armor, attack, damage, speed }
    public var id: String
    public var kind: Kind
    public var amount: Int
    public init(id: String, kind: Kind, amount: Int) { self.id=id; self.kind=kind; self.amount=amount }
}

public struct InventoryEntry: Codable, Sendable, Hashable, Identifiable {
    public enum Mode: String, Codable, Sendable, CaseIterable {
        case oneHanded, twoHanded
        public var label:String { self == .oneHanded ? "one-handed" : "two-handed" }
    }
    public var id: String
    public var itemID: String
    public var quantity: Int
    public var carried: Bool
    public var equipped: Bool
    public var attuned: Bool
    public var mode: Mode? = nil
    public var ability: Ability? = nil
    public init(id: String = UUID().uuidString, itemID: String, quantity: Int = 1, carried: Bool = true, equipped: Bool = false, attuned: Bool = false, mode: Mode? = nil, ability: Ability? = nil) {
        self.id=id; self.itemID=itemID; self.quantity=quantity; self.carried=carried; self.equipped=equipped; self.attuned=attuned; self.mode=mode; self.ability=ability
    }
}

public struct EquipmentChoice: Codable, Sendable, Hashable, Identifiable {
    public struct Option: Codable, Sendable, Hashable, Identifiable {
        public var id: String
        public var name: String
        public var items: [String:Int]
        public var gold: Int
        public init(id:String,name:String,items:[String:Int] = [:],gold:Int = 0) { self.id=id; self.name=name; self.items=items; self.gold=gold }
    }
    public var id: String
    public var name: String
    public var options: [Option]
    public init(id:String,name:String,options:[Option]) { self.id=id; self.name=name; self.options=options }
}

public struct EquipmentLoadout: Codable, Sendable, Hashable {
    public struct Application: Codable, Sendable, Hashable, Identifiable {
        public var recipeID: String
        public var inventoryID: String
        public var id: String { recipeID + ":" + inventoryID }
        public init(recipeID:String,inventoryID:String) { self.recipeID=recipeID; self.inventoryID=inventoryID }
    }
    public var inventory: [InventoryEntry]
    public var currency: [String:Int]
    public var startingChoices: [String:String]? = nil
    public var masteryItemIDs: [String]? = nil
    public var applications: [Application]? = nil
    public var defenseID: String? = nil
    public var weaponBindings: [String:String]? = nil
    public init(inventory:[InventoryEntry] = [], currency:[String:Int] = [:]) { self.inventory=inventory; self.currency=currency }
}

/// Capability replay decides ownership/conditions and resolves level scaling.
/// Equipment receives only the accepted rules; it never grants prerequisites.
public struct EquipmentRule: Codable, Sendable, Hashable {
    public enum Kind: String, Codable, Sendable { case unarmed, weaponAbility, attackBonus, damageBonus, attunementLimit, attunementEligibility, masteryLimit, applicationLimit, recipe }
    public var kind: Kind
    public var ability: Ability? = nil
    public var damageType: String? = nil
    public var training: String? = nil
    public var itemKind: ItemDefinition.Kind? = nil
    public var modifiers: [ItemModifier]? = nil
    public var requiresBinding: Bool? = nil
    public init(_ kind:Kind, ability:Ability? = nil, damageType:String? = nil, training:String? = nil, itemKind:ItemDefinition.Kind? = nil, modifiers:[ItemModifier]? = nil) {
        self.kind=kind; self.ability=ability; self.damageType=damageType; self.training=training; self.itemKind=itemKind; self.modifiers=modifiers
    }
}

public struct ActiveEquipmentRule: Sendable {
    public var id: String
    public var name: String
    public var rule: EquipmentRule
    public var value: Int
}

public struct EquipmentSummary: Sendable {
    public struct Defense: Sendable, Identifiable {
        public var id:String
        public var name:String
        public var value:Int
        public init(id:String,name:String,value:Int) { self.id=id;self.name=name;self.value=value }
    }
    public struct Attack: Sendable, Identifiable {
        public var id: String
        public var name: String
        public var bonus: Int
        public var damage: String
        public var notes: [String]
        public var description: String { "\(name): \(bonus >= 0 ? "+" : "")\(bonus) to hit; \(damage)\(notes.isEmpty ? "" : "; " + notes.joined(separator: "; "))" }
    }
    public var armorClass: Int
    public var speed: Int
    public var weight: Double = 0
    public var capacity: Double = 0
    public var stealthDisadvantage = false
    public var castingRestricted = false
    public var attuned = 0
    public var attunementLimit = 3
    public var masteryLimit = 0
    public var applicationLimit = 0
    public var attacks: [Attack] = []
    public var defenses: [Defense] = []
    public var inventory: [String] = []
    public var notes: [String] = []
    public var issues: [BuildIssue] = []
}

public enum EquipmentEngine {
    public static let trainingKeys: Set<String> = ["armor.light","armor.medium","armor.heavy","armor.shield","weapon.simple","weapon.martial","weapon.scimitar","weapon.shortsword","weapon.unarmed"]
    public static func matches(_ condition:String, loadout:EquipmentLoadout?, pack:ContentPack) -> Bool {
        let equipped=(loadout?.inventory ?? []).filter { $0.quantity > 0 && $0.carried && $0.equipped }.compactMap { row in pack.items?.first { $0.id == row.itemID } }
        switch condition {
        case "unarmored": return !equipped.contains { $0.kind == .armor }
        case "noShield": return !equipped.contains { $0.kind == .shield }
        case "unarmed": return !equipped.contains { $0.kind == .weapon }
        default: return false
        }
    }
    public static func startingChoices(build:CharacterBuild,pack:ContentPack) -> [EquipmentChoice] {
        (pack.classes.first { $0.id == build.classID }?.startingEquipment ?? []) + (pack.backgrounds.first { $0.id == build.backgroundID }?.startingEquipment ?? [])
    }
    /// One explicit transaction on editable inventory; replay never repeatedly grants gear.
    public static func applyStartingChoices(_ picks:[String:String],build:CharacterBuild,pack:ContentPack) throws -> EquipmentLoadout {
        let groups=startingChoices(build:build,pack:pack)
        guard Set(picks.keys) == Set(groups.map(\.id)), groups.allSatisfy({ group in group.options.contains { $0.id == picks[group.id] } }) else { throw FolioError.invalid("Choose exactly one option in each starting-equipment group.") }
        var result=EquipmentLoadout(); result.startingChoices=picks
        var quantities:[String:Int]=[:]
        for group in groups {
            let option=group.options.first { $0.id == picks[group.id] }!
            for (id,count) in option.items { quantities[id,default:0] += count }
            result.currency["gp",default:0] += option.gold
        }
        result.inventory=quantities.keys.sorted().map { .init(itemID:$0,quantity:quantities[$0]!) }
        return result
    }
    static func require(_ condition:Bool,_ message:String) throws { if !condition { throw FolioError.invalid(message) } }
    static func identity(_ s:String) -> Bool { !s.isEmpty && s.count <= 120 }
    static func validateModifiers(_ modifiers:[ItemModifier]) throws {
        try require(modifiers.count <= 16 && Set(modifiers.map(\.id)).count == modifiers.count,"Invalid item modifier identities.")
        for m in modifiers { try require(identity(m.id) && (-20...20).contains(m.amount),"Unsafe item modifier.") }
    }
    static func validateRule(_ rule:EquipmentRule) throws {
        if rule.requiresBinding == true { try require([EquipmentRule.Kind.weaponAbility,.attackBonus,.damageBonus].contains(rule.kind),"Only weapon modifications accept a bound weapon.") }
        if let training=rule.training { try require(trainingKeys.contains(training) || RulesEngine.skillAbilities[training] != nil,"Unknown equipment-rule training.") }
        if let text=rule.damageType { try require(identity(text),"Invalid damage type.") }
        try validateModifiers(rule.modifiers ?? [])
        if rule.kind == .unarmed { try require(rule.ability != nil && rule.damageType != nil,"Unarmed rule needs ability and damage type.") }
        if rule.kind == .weaponAbility { try require(rule.ability != nil,"Weapon substitution needs an ability.") }
        if rule.kind == .recipe { try require(rule.itemKind != nil && !(rule.modifiers ?? []).isEmpty,"Recipes need target kind and modifiers.") }
    }
    static func validate(_ pack:ContentPack) throws {
        let items=pack.items ?? [], groups=pack.classes.flatMap { $0.startingEquipment ?? [] } + pack.backgrounds.flatMap { $0.startingEquipment ?? [] }
        if pack.items != nil || !groups.isEmpty { try require(pack.schemaVersion == 2 && pack.capabilities?.required.contains("equipment") == true,"Item catalogs require schema 2 equipment capability.") }
        try require(items.count <= 2000 && Set(items.map(\.id)).count == items.count,"Too many or duplicate item definitions.")
        var modifiers:[String:ItemModifier]=[:]
        for item in items {
            try require(identity(item.id) && identity(item.name) && ["2014","2024"].contains(item.edition),"Invalid item identity/edition.")
            try require(item.weight.isFinite && (0...10000).contains(item.weight) && (0...100_000_000).contains(item.cost),"Invalid item weight/cost.")
            if let id=item.canonicalID { try require(identity(id),"Invalid canonical item identity.") }
            if let key=item.training { try require(trainingKeys.contains(key),"Unknown item training category.") }
            if let key=item.attunementTraining { try require(trainingKeys.contains(key) || RulesEngine.skillAbilities[key] != nil,"Unknown attunement prerequisite.") }
            try require((item.text?.count ?? 0) <= 20000 && (item.mastery?.count ?? 0) <= 120 && (item.damageType?.count ?? 0) <= 120,"Item text too large.")
            try require(Set(item.properties ?? []).count == (item.properties?.count ?? 0),"Duplicate item property.")
            if [.armor,.shield].contains(item.kind) { try require((0...30).contains(item.armorBase ?? -1) && item.training != nil,"Armor needs base AC and training.") }
            if let cap=item.dexterityCap { try require((0...10).contains(cap),"Unsafe Dexterity cap.") }
            if let base=item.armorBase { try require((0...30).contains(base),"Unsafe armor base.") }
            if let dice=item.damageDice { try require((1...10).contains(dice),"Unsafe damage dice count.") }
            if let sides=item.damageSides { try require([4,6,8,10,12].contains(sides),"Unsafe damage die.") }
            if let sides=item.versatileSides { try require([4,6,8,10,12].contains(sides),"Unsafe alternate damage die.") }
            if let str=item.strengthMinimum { try require((1...30).contains(str),"Unsafe armor Strength minimum.") }
            if item.kind == .weapon { try require((1...10).contains(item.damageDice ?? 0) && [4,6,8,10,12].contains(item.damageSides ?? 0) && item.training != nil && !(item.damageType ?? "").isEmpty,"Weapon needs bounded dice, damage type and training.") }
            if (item.properties ?? []).contains(.versatile) { try require([4,6,8,10,12].contains(item.versatileSides ?? 0),"Versatile weapon needs alternate dice.") }
            try validateModifiers(item.modifiers ?? [])
            for m in item.modifiers ?? [] { if let prior=modifiers[m.id] { try require(prior == m,"Conflicting canonical item modifier.") }; modifiers[m.id]=m }
        }
        try require(groups.count <= 200 && Set(groups.map(\.id)).count == groups.count,"Duplicate starting-equipment group.")
        for group in groups {
            try require(identity(group.id) && identity(group.name) && (1...100).contains(group.options.count) && Set(group.options.map(\.id)).count == group.options.count,"Invalid starting-equipment alternatives.")
            for option in group.options {
                try require(identity(option.id) && identity(option.name) && option.items.count <= 100 && (0...100000).contains(option.gold),"Invalid starting-equipment option.")
                try require(option.gold == 0 || option.items.isEmpty,"An option cannot grant both money and gear.")
                try require(option.items.allSatisfy { id,n in items.contains { $0.id == id } && (1...1000).contains(n) },"Missing starting item or unsafe quantity.")
            }
        }
    }
    static func validate(_ loadout:EquipmentLoadout) throws {
        try require((loadout.weaponBindings?.count ?? 0) <= 100 && (loadout.weaponBindings ?? [:]).allSatisfy { identity($0.key) && identity($0.value) },"Unsafe weapon bindings.")
        if let id=loadout.defenseID { try require(identity(id),"Invalid selected defense identity.") }
        try require(loadout.inventory.count <= 500 && Set(loadout.inventory.map(\.id)).count == loadout.inventory.count,"Duplicate or excessive inventory rows.")
        for row in loadout.inventory { try require(identity(row.id) && identity(row.itemID) && (0...100000).contains(row.quantity),"Unsafe inventory quantity or identity.") }
        try require(loadout.currency.allSatisfy { ["cp","sp","ep","gp","pp"].contains($0.key) && (0...100_000_000).contains($0.value) },"Unsafe currency amount or denomination.")
        try require((loadout.startingChoices?.count ?? 0) <= 200 && (loadout.startingChoices ?? [:]).allSatisfy { identity($0.key) && identity($0.value) },"Unsafe starting choices.")
        try require((loadout.masteryItemIDs?.count ?? 0) <= 100 && (loadout.masteryItemIDs ?? []).allSatisfy(identity),"Unsafe mastery choices.")
        try require((loadout.applications?.count ?? 0) <= 100 && (loadout.applications ?? []).allSatisfy { identity($0.recipeID) && identity($0.inventoryID) },"Unsafe active applications.")
    }
    public static func evaluate(_ loadout: EquipmentLoadout, in pack: ContentPack, summary: CharacterSummary, edition: String) -> EquipmentSummary {
        var out=EquipmentSummary(armorClass:summary.armorClass,speed:summary.speed)
        func issue(_ code:String,_ message:String) { out.issues.append(.init(code:"equipment-"+code,message:message)) }
        do { try validate(loadout) } catch { issue("invalid",error.localizedDescription); return out }
        let rules=summary.equipmentRules
        for (id,rowID) in loadout.weaponBindings ?? [:] {
            guard let rule=rules.first(where:{$0.id == id && $0.rule.requiresBinding == true}),let row=loadout.inventory.first(where:{$0.id == rowID && $0.quantity > 0}),let item=pack.items?.first(where:{$0.id == row.itemID && $0.kind == .weapon}),rule.rule.training == nil || rule.rule.training == item.training else {
                issue("weapon-binding","A bound-weapon choice requires an active rule and an eligible owned weapon.");continue
            }
        }
        for rule in rules where rule.rule.requiresBinding == true && loadout.weaponBindings?[rule.id] == nil { issue("weapon-binding","Choose a weapon for \(rule.name).") }
        out.attunementLimit=max(3,rules.filter { $0.rule.kind == .attunementLimit }.map(\.value).max() ?? 3)
        out.masteryLimit=max(0,rules.filter { $0.rule.kind == .masteryLimit }.map(\.value).max() ?? 0)
        out.applicationLimit=max(0,rules.filter { $0.rule.kind == .applicationLimit }.map(\.value).max() ?? 0)
        let dex=Ability.modifier(summary.scores["dex",default:10])
        let size=summary.size ?? "Medium"
        let multiplier:[String:Double]=["Tiny":0.5,"Small":1,"Medium":1,"Large":2,"Huge":4,"Gargantuan":8]
        out.capacity=Double(summary.scores["str",default:10])*15*(multiplier[size] ?? 1)
        out.weight=Double(loadout.currency.values.reduce(0,+))/50
        let mastery=loadout.masteryItemIDs ?? []
        if mastery.count > out.masteryLimit || Set(mastery).count != mastery.count { issue("mastery-limit","Select at most \(out.masteryLimit) distinct weapon masteries.") }
        func trained(_ key:String?) -> Bool {
            guard let key else { return false }
            let categories:[String:String]=["weapon.scimitar":"weapon.martial","weapon.shortsword":"weapon.martial"]
            let keys=[key]+(categories[key].map { [$0] } ?? [])
            return keys.contains { (summary.proficiencyRanks[$0] ?? .none).bonus(summary.proficiency) >= summary.proficiency }
        }
        for id in mastery {
            if let item=pack.items?.first(where:{$0.id == id}),item.kind == .weapon,item.mastery != nil,trained(item.training) {} else { issue("mastery-eligibility","Mastery requires a trained weapon with an authored mastery label.") }
        }
        let applications=loadout.applications ?? []
        var appliedRows=Set<String>(),appliedRecipes=Set<String>(),applicationModifiers:[String:[ItemModifier]]=[:]
        if applications.count > out.applicationLimit { issue("application-limit","At most \(out.applicationLimit) active item applications are allowed.") }
        for application in applications {
            guard let recipe=rules.first(where:{$0.id == application.recipeID && $0.rule.kind == .recipe}),let row=loadout.inventory.first(where:{$0.id == application.inventoryID}),row.quantity > 0,let item=pack.items?.first(where:{$0.id == row.itemID}),item.kind == recipe.rule.itemKind else { issue("application-eligibility","Active application requires a known recipe and an eligible owned item."); continue }
            guard applications.count <= out.applicationLimit,appliedRows.insert(row.id).inserted,appliedRecipes.insert(recipe.id).inserted else { issue("application-duplicate","Use each recipe once and at most one application per inventory row."); continue }
            applicationModifiers[row.id]=recipe.rule.modifiers ?? []
        }
        var canonicalAttuned=Set<String>(),globalModifiers=Set<String>(),armorCount=0,shieldCount=0,hands=0
        var armor:Int?,shieldBonus=0,acBonus=0,speedBonus=0
        for row in loadout.inventory {
            guard let item=pack.items?.first(where:{$0.id == row.itemID}) else { issue("missing-item","An inventory item is absent from this pinned catalog."); continue }
            let active=row.quantity > 0 && row.carried && row.equipped
            out.inventory.append("\(item.name) ×\(row.quantity) [\(row.carried ? "carried" : "stored")\(row.equipped ? ", equipped" : "")\(row.attuned ? ", attuned" : "")]\(row.mode.map { "; " + $0.label } ?? "")")
            if row.carried { out.weight += item.weight*Double(row.quantity) }
            if row.equipped && (!row.carried || row.quantity == 0) { issue("inactive-equipped","Equipped items must be carried with positive quantity.") }
            if item.edition != edition { issue("edition","\(item.name) is from \(item.edition), not the pinned \(edition) profile.") }
            var magical=item.attunement != true
            if row.attuned {
                out.attuned += 1
                let eligible=item.attunementTraining == nil || trained(item.attunementTraining) || rules.contains { $0.rule.kind == .attunementEligibility && ($0.rule.training == nil || $0.rule.training == item.attunementTraining) }
                let unique=canonicalAttuned.insert(item.canonicalID ?? item.id).inserted
                if !unique { issue("attunement-duplicate","You cannot attune to duplicate copies of the same canonical item.") }
                if !eligible { issue("attunement-prerequisite","\(item.name) requires \(item.attunementTraining ?? "training") before attunement.") }
                if item.attunement != true || row.quantity == 0 || !row.carried { issue("attunement-state","Only an owned carried item requiring attunement can be attuned.") }
                magical=eligible && unique && row.quantity > 0 && row.carried && out.attuned <= out.attunementLimit
            }
            guard active else { continue }
            if item.support == .unsupported { issue("unsupported","\(item.name): \(item.text ?? "Required sheet effects are unsupported.")") }
            if item.support == .manual { out.notes.append("Manual — \(item.name): \(item.text ?? "Combat effect not automated.")") }
            let hasTraining=trained(item.training)
            if item.kind == .armor {
                armorCount += 1
                let dexBonus=item.dexterityCap == 0 ? 0 : min(dex,item.dexterityCap ?? dex)
                armor=(item.armorBase ?? 10)+dexBonus+summary.equipmentArmorBonus
                if let minimum=item.strengthMinimum,summary.scores["str",default:10] < minimum { out.speed=max(0,out.speed-10); out.notes.append("Heavy armor Strength requirement: speed −10 ft") }
                out.stealthDisadvantage = out.stealthDisadvantage || item.stealthDisadvantage == true
            }
            if item.kind == .shield { shieldCount += 1; hands += 1; if edition == "2014" || hasTraining { shieldBonus=item.armorBase ?? 0 } }
            if [.armor,.shield].contains(item.kind) && !hasTraining {
                if item.kind == .armor || edition == "2014" { out.castingRestricted=true; out.notes.append("Untrained \(item.name): cannot cast spells; Strength/Dexterity checks, saves and attacks have disadvantage") }
                else { out.notes.append("Untrained shield: no shield AC bonus") }
            }
            let modifiers=(magical ? item.modifiers ?? [] : [])+(applicationModifiers[row.id] ?? [])
            var attackBonus=0,damageBonus=0,localModifiers=Set<String>()
            for modifier in modifiers {
                guard localModifiers.insert(modifier.id).inserted else { continue }
                switch modifier.kind {
                case .armor: if globalModifiers.insert(modifier.id).inserted { acBonus += modifier.amount }
                case .speed: if globalModifiers.insert(modifier.id).inserted { speedBonus += modifier.amount }
                case .attack: attackBonus += modifier.amount
                case .damage: damageBonus += modifier.amount
                }
            }
            guard item.kind == .weapon else { continue }
            let properties=item.properties ?? []
            let needsTwo=properties.contains(.twoHanded),versatile=properties.contains(.versatile)
            let mode=row.mode ?? .oneHanded
            if (needsTwo || versatile) && row.mode == nil { issue("mode","Choose the wielding mode for \(item.name).") }
            if needsTwo && mode != .twoHanded || mode == .twoHanded && !needsTwo && !versatile { issue("mode","\(item.name) cannot use that wielding mode.") }
            hands += mode == .twoHanded ? 2 : 1
            var ability:Ability=properties.contains(.ranged) ? .dex : .str
            if properties.contains(.finesse) {
                if let selected=row.ability,[Ability.str,.dex].contains(selected) { ability=selected }
                else { issue("ability","Choose Strength or Dexterity for \(item.name)'s finesse attack and damage.") }
            } else if let selected=row.ability,selected != ability { issue("ability","Unsupported ability choice for \(item.name).") }
            for rule in rules where (rule.rule.training == nil || rule.rule.training == item.training) && (rule.rule.requiresBinding != true || loadout.weaponBindings?[rule.id] == row.id) {
                if rule.rule.kind == .weaponAbility,let replacement=rule.rule.ability { ability=replacement }
                if rule.rule.kind == .attackBonus { attackBonus += rule.value }
                if rule.rule.kind == .damageBonus { damageBonus += rule.value }
            }
            let mod=Ability.modifier(summary.scores[ability.rawValue,default:10])
            var notes:[String]=[]
            if !hasTraining { notes.append("Untrained: no proficiency bonus") }
            if properties.contains(.heavy) && (edition == "2014" ? size == "Small" || size == "Tiny" : summary.scores[properties.contains(.ranged) ? "dex":"str",default:10] < 13) { notes.append("Disadvantage: Heavy weapon requirement") }
            if properties.contains(.ammunition) { notes.append("Ammunition required; quantity and expenditure are manual") }
            if mastery.contains(item.id),let label=item.mastery { notes.append("Mastery: \(label) (combat resolution manual)") }
            let sides=mode == .twoHanded && versatile ? item.versatileSides ?? 0 : item.damageSides ?? 0
            let damage=mod+damageBonus
            out.attacks.append(.init(id:row.id,name:item.name,bonus:mod+(hasTraining ? summary.proficiency:0)+attackBonus,damage:"\(item.damageDice ?? 1)d\(sides) \(damage >= 0 ? "+" : "")\(damage) \(item.damageType ?? "")",notes:notes))
        }
        if armorCount > 1 || shieldCount > 1 { issue("defenses","Only one armor and one shield can be equipped.") }
        if hands > 2 { issue("hands","The equipped loadout requires more than two hands.") }
        if out.attuned > out.attunementLimit { issue("attunement-limit","Attunement limit is \(out.attunementLimit).") }
        out.defenses=summary.equipmentDefenses.map { .init(id:$0.id,name:$0.name,value:$0.value+summary.equipmentArmorBonus) }
        if let armor { out.defenses.append(.init(id:"armor",name:"Equipped armor",value:armor)) }
        else { out.defenses.append(.init(id:"unarmored",name:"Ordinary unarmored",value:10+dex+summary.equipmentArmorBonus)) }
        let selected=loadout.defenseID.flatMap { id in out.defenses.first { $0.id == id } }
        if loadout.defenseID != nil && selected == nil { issue("defense-choice","The selected defense formula is unavailable in this loadout or configuration.") }
        out.armorClass=(selected?.value ?? out.defenses.map(\.value).max() ?? summary.armorClass)+shieldBonus+acBonus
        out.speed=max(0,out.speed+speedBonus)
        if out.stealthDisadvantage { out.notes.append("Stealth checks have disadvantage while this armor is equipped.") }
        if out.weight > out.capacity { issue("capacity","Carried weight exceeds carrying capacity; reduce the load.") }
        if out.castingRestricted { out.notes.append("Spell values are reference formulas only while casting is restricted.") }
        for rule in rules where rule.rule.kind == .unarmed {
            guard [4,6,8,10,12].contains(rule.value) else {
                issue("unarmed-die","\(rule.name) has no supported damage die at this level.")
                continue
            }
            let mod=Ability.modifier(summary.scores[rule.rule.ability?.rawValue ?? "str",default:10])
            out.attacks.append(.init(id:rule.id,name:rule.name,bonus:mod+summary.proficiency,damage:"1d\(rule.value) \(mod >= 0 ? "+" : "")\(mod) \(rule.rule.damageType ?? "")",notes:["Unarmed; combat actions manual"]))
        }
        return out
    }
}
