import SwiftUI
import FolioCore

struct EquipmentEditor: View {
    @Binding var build: CharacterBuild
    let pack: ContentPack
    @State private var itemID=""
    @State private var picks:[String:String]=[:]
    @State private var message:String?
    private var summary:CharacterSummary { RulesEngine.evaluate(build,in:pack) }
    private var loadout:EquipmentLoadout { build.equipment ?? .init() }
    private func edit(_ change:(inout EquipmentLoadout)->Void) { var value=loadout;change(&value);build.equipment=value }
    private func rowBinding<T>(_ index:Int,_ path:WritableKeyPath<InventoryEntry,T>) -> Binding<T> {
        Binding(get:{ loadout.inventory[index][keyPath:path] },set:{ value in edit { $0.inventory[index][keyPath:path]=value } })
    }
    var body:some View {
        FolioPanel(title:"Equipment & loadout",subtitle:"Owned inventory is separate from equipped gear. No rolls, purchases or automatic expenditure.") {
            if build.equipment == nil {
                Text("Equipment is not tracked in this saved build yet. Its current sheet remains unchanged.").font(.subheadline)
                Button("Track equipment") { build.equipment = .init() }
            } else {
                starting
                Picker("Catalog item",selection:$itemID) {
                    Text("Choose an item").tag("")
                    ForEach((pack.items ?? []).filter { $0.edition == build.rulesProfile?.edition }) { item in
                        Text(item.name + (pack.sourceLabels?[item.id].map { " · " + $0 } ?? "")).tag(item.id)
                    }
                }
                Button("Add owned item") { edit { $0.inventory.append(.init(itemID:itemID)) } }.disabled(itemID.isEmpty)
                ForEach(Array(loadout.inventory.enumerated()),id:\.element.id) { index,row in
                    inventoryRow(index,row)
                }
                Text("Currency (carried)").font(.headline)
                ForEach(["cp","sp","ep","gp","pp"],id:\.self) { denomination in
                    HStack { Text(denomination.uppercased());TextField(denomination.uppercased(),value:Binding(get:{loadout.currency[denomination,default:0]},set:{ n in edit { $0.currency[denomination]=max(0,min(100_000_000,n)) } }),format:.number).folioInput() }
                }
                if let equipment=summary.equipment {
                    Picker("Defense formula",selection:Binding(get:{loadout.defenseID ?? ""},set:{ id in edit { $0.defenseID=id.isEmpty ? nil:id } })) {
                        Text("Best applicable formula").tag("")
                        ForEach(equipment.defenses) { Text("\($0.name): \($0.value) before shield/items").tag($0.id) }
                        if let id=loadout.defenseID,!equipment.defenses.contains(where:{$0.id == id}) { Text("Unavailable saved defense").tag(id) }
                    }
                    Text("Carried \(equipment.weight.formatted()) / \(equipment.capacity.formatted()) lb · attuned \(equipment.attuned)/\(equipment.attunementLimit)").font(.subheadline)
                    ForEach(Array(equipment.notes.enumerated()),id:\.offset) { _, text in Text(text).font(.caption).foregroundStyle(Palette.muted) }
                    ForEach(equipment.issues) { Text($0.message).font(.caption).foregroundStyle(Palette.brass) }
                }
                applications
                ForEach(summary.equipmentRules.filter { $0.rule.requiresBinding == true },id:\.id) { rule in
                    Picker(rule.name,selection:Binding(get:{loadout.weaponBindings?[rule.id] ?? ""},set:{ id in edit { value in var bindings=value.weaponBindings ?? [:];bindings[rule.id]=id.isEmpty ? nil:id;value.weaponBindings=bindings } })) {
                        Text("Choose bound weapon").tag("")
                        ForEach(loadout.inventory.filter { row in pack.items?.contains { $0.id == row.itemID && $0.kind == .weapon } == true }) { row in
                            Text(pack.items?.first { $0.id == row.itemID }?.name ?? row.itemID).tag(row.id)
                        }
                    }
                }
                ForEach((loadout.weaponBindings ?? [:]).keys.sorted(),id:\.self) { id in
                    if !summary.equipmentRules.contains(where:{$0.id == id && $0.rule.requiresBinding == true}) { Button("Clear unavailable bound-weapon rule") { edit { $0.weaponBindings?[id]=nil } } }
                }
                if let message { Text(message).font(.caption).foregroundStyle(Palette.brass) }
            }
        }
    }
    @ViewBuilder private var starting:some View {
        let groups=EquipmentEngine.startingChoices(build:build,pack:pack)
        if !groups.isEmpty {
            DisclosureGroup("Starting equipment or money") {
                Text("Apply once to an empty inventory and purse. Later quantities are yours to edit; selecting a choice never repeatedly grants gear.").font(.caption)
                ForEach(groups) { group in
                    Picker(group.name,selection:Binding(get:{picks[group.id] ?? ""},set:{picks[group.id]=$0})) {
                        Text("Choose").tag("")
                        ForEach(group.options) { Text($0.name).tag($0.id) }
                    }
                }
                Button("Apply starting choices") {
                    do { build.equipment=try EquipmentEngine.applyStartingChoices(picks,build:build,pack:pack);message=nil }
                    catch { message=error.localizedDescription }
                }.disabled(!loadout.inventory.isEmpty || loadout.currency.values.contains { $0 != 0 } || loadout.startingChoices != nil)
                if loadout.startingChoices != nil { Text("Starting choices applied. Edit owned inventory below.").font(.caption) }
            }
        }
    }
    private func inventoryRow(_ index:Int,_ row:InventoryEntry) -> some View {
        let item=pack.items?.first { $0.id == row.itemID }
        return VStack(alignment:.leading,spacing:10) {
            HStack { Text(item?.name ?? "Missing pinned item").font(.headline);Spacer();Button("Remove",role:.destructive) { edit { $0.inventory.removeAll { $0.id == row.id } } } }
            Text("\((item?.weight ?? 0).formatted()) lb each · \(item?.cost ?? 0) cp each").font(.caption).foregroundStyle(Palette.muted)
            Stepper("Quantity: \(row.quantity)",value:rowBinding(index,\.quantity),in:0...100000)
            Toggle("Carried",isOn:rowBinding(index,\.carried))
            Toggle("Equipped",isOn:rowBinding(index,\.equipped))
            if item?.attunement == true { Toggle("Attuned",isOn:rowBinding(index,\.attuned)) }
            if item?.kind == .weapon {
                Picker("Wielding mode",selection:rowBinding(index,\.mode)) {
                    Text("Choose mode").tag(Optional<InventoryEntry.Mode>.none)
                    if item?.properties?.contains(.twoHanded) != true { Text("One-handed").tag(Optional(InventoryEntry.Mode.oneHanded)) }
                    if item?.properties?.contains(.twoHanded) == true || item?.properties?.contains(.versatile) == true { Text("Two-handed").tag(Optional(InventoryEntry.Mode.twoHanded)) }
                }
                if item?.properties?.contains(.finesse) == true {
                    Picker("Finesse ability",selection:rowBinding(index,\.ability)) {
                        Text("Choose ability").tag(Optional<Ability>.none);Text("Strength").tag(Optional(Ability.str));Text("Dexterity").tag(Optional(Ability.dex))
                    }
                }
                if let mastery=item?.mastery {
                    Toggle("Mastery: \(mastery)",isOn:Binding(get:{loadout.masteryItemIDs?.contains(row.itemID) == true},set:{ enabled in edit { value in var ids=value.masteryItemIDs ?? [];ids.removeAll { $0 == row.itemID };if enabled { ids.append(row.itemID) };value.masteryItemIDs=ids } }))
                    Text("Combat effect manual. Selection limit: \(summary.equipment?.masteryLimit ?? 0).").font(.caption)
                }
            }
            if let text=item?.text,!text.isEmpty { Text(text).font(.caption).foregroundStyle(Palette.muted) }
        }.padding().background(Palette.surface,in:RoundedRectangle(cornerRadius:18))
    }
    @ViewBuilder private var applications:some View {
        let recipes=summary.equipmentRules.filter { $0.rule.kind == .recipe }
        if !recipes.isEmpty || !(loadout.applications ?? []).isEmpty {
            Text("Known recipes · active applications").font(.headline)
            Text("At most \(summary.equipment?.applicationLimit ?? 0) active items. Knowing a recipe does not apply it automatically.").font(.caption)
            ForEach(recipes,id:\.id) { recipe in
                Picker(recipe.name,selection:Binding(get:{loadout.applications?.first { $0.recipeID == recipe.id }?.inventoryID ?? ""},set:{ id in edit { value in var list=value.applications ?? [];list.removeAll { $0.recipeID == recipe.id };if !id.isEmpty { list.append(.init(recipeID:recipe.id,inventoryID:id)) };value.applications=list } })) {
                    Text("Not applied").tag("")
                    ForEach(loadout.inventory) { row in Text(pack.items?.first { $0.id == row.itemID }?.name ?? row.itemID).tag(row.id) }
                }
            }
            ForEach(loadout.applications ?? []) { application in
                if !recipes.contains(where:{$0.id == application.recipeID}) { Button("Clear unavailable recipe application") { edit { $0.applications?.removeAll { $0.id == application.id } } } }
            }
        }
    }
}
