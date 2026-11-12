import SwiftUI
import UniformTypeIdentifiers
import FolioCore

struct CharacterView: View {
    var store: AppStore
    @State var record: CharacterRecord
    @State private var section = "Build"
    @State private var selectedLevel = 1
    @State private var exportFile: CharacterExportFile?
    @State private var exportType: UTType = .json
    @State private var exportSuffix = "folio"
    @State private var exporting = false
    @State private var message: String?
    @State private var removingLevel = false
    @State private var addingLibrary = false
    @State private var sheetStyle = "Summary"

    init(store: AppStore, initial: CharacterRecord) {
        self.store = store
        _record = State(initialValue: initial)
        _selectedLevel = State(initialValue: initial.build.level)
    }
    var definition: ClassDefinition? { record.pack.classes.first { $0.id == record.build.classID } }
    var summary: CharacterSummary { RulesEngine.evaluate(record.build, in: record.pack) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                Picker("Character section", selection: $section) { ForEach(["Build", "Sheet", "Story"], id: \.self) { Text($0).tag($0) } }
                    .pickerStyle(.segmented).labelsHidden()
                if section == "Build" {
                    creation
                    if let definition {
                        FolioPanel(title: "The path so far", subtitle: "Every level keeps its own choices. Editing an earlier level rechecks the rest of your build.") {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(record.build.levels) { level in
                                        Button { selectedLevel = level.level } label: {
                                            VStack(spacing: 5) { Text("Level").font(.caption); Text("\(level.level)").font(.title2) }
                                                .frame(width: 64, height: 68)
                                                .foregroundStyle(selectedLevel == level.level ? .white : Palette.ink)
                                                .background(selectedLevel == level.level ? Palette.ink : Palette.surface, in: RoundedRectangle(cornerRadius: 32))
                                        }.buttonStyle(.plain).accessibilityLabel("Edit level \(level.level)")
                                    }
                                }
                            }
                            if selectedLevel <= record.build.levels.count {
                                LevelEditor(build: $record.build, pack: record.pack, definition: definition, level: selectedLevel)
                            }
                        }
                    }
                    validation
                } else if section == "Sheet" {
                    Picker("Sheet format",selection:$sheetStyle) {
                        Text("Summary").tag("Summary")
                        Text("2024 sheet").tag("2024 sheet")
                    }.pickerStyle(.segmented)
                    if sheetStyle == "Summary" { CharacterSheet(record: record, summary: summary) }
                    else {
                        SheetExportView(record:record,directory:store.storage.directory) { data in
                            exportFile=CharacterExportFile(data:data)
                            exportType = .pdf; exportSuffix="2024-sheet"; exporting=true
                        }
                    }
                } else {
                    StoryView(record: $record)
                }
                if let error = store.error {
                    Label(error, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.red)
                }
                Text("\(record.pack.name) \(record.pack.version)\nChanges save on this device.")
                    .font(.caption).foregroundStyle(Palette.muted)
            }.padding(20).frame(maxWidth: 680).frame(maxWidth: .infinity)
        }.background(Palette.paper)
            .navigationTitle(record.build.name)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Add library choices", systemImage: "books.vertical") { addingLibrary = true }
                        Button("Copy to capability rules for review", systemImage: "square.on.square") {
                            if let copy = store.upgradeCopy(record) { message = "Created a separate review copy: \(copy.build.name). Your original is unchanged." }
                        }
                        Button("Duplicate as an alternate build", systemImage: "square.on.square") {
                            if let copy = store.duplicate(record) { message = "Saved \(copy.build.name) in your library." }
                        }
                        Button("Export character and its content pack", systemImage: "square.and.arrow.up") {
                            do {
                                exportFile = CharacterExportFile(data: try LibraryStorage.encoder.encode(record))
                                exportType = .json; exportSuffix="folio"; exporting = true
                            }
                            catch { message = error.localizedDescription }
                        }
                        if record.build.level > 1 {
                            Button("Remove last level", systemImage: "arrow.uturn.backward", role: .destructive) { removingLevel = true }
                        }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
            .onChange(of: record) { store.save(record) }
            // One presenter avoids nested SwiftUI file exporters shadowing each other.
            .fileExporter(isPresented: $exporting, document: exportFile, contentType: exportType, defaultFilename: "\(record.build.name)-\(exportSuffix)") { result in
                if case .failure(let error) = result { message = error.localizedDescription }
            }
            .alert("Character Folio", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK") { message = nil } } message: { Text(message ?? "") }
            .confirmationDialog("Remove level \(record.build.level)? Earlier choices and your story will stay.", isPresented: $removingLevel, titleVisibility: .visible) {
                Button("Remove last level", role: .destructive) { record.build.levels.removeLast(); selectedLevel = record.build.level }
            }
            .confirmationDialog("Add choices from installed sources? Existing rules and selections stay pinned. Different source versions remain separate options.", isPresented: $addingLibrary, titleVisibility: .visible) {
                Button("Add library choices") {
                    do {
                        let updated = try ContentCatalog(packs:store.library.packs).addingChoices(to:record)
                        if store.save(updated) { record = updated }
                    } catch { message = error.localizedDescription }
                }
            }
    }
    private var header: some View {
        HStack(spacing: 20) {
            CharacterAvatar(name: record.build.name, portrait: record.build.portrait, size: 64)
            VStack(alignment: .leading, spacing: 5) {
                Text(record.build.name).font(.largeTitle.weight(.medium)).foregroundStyle(Palette.ink)
                Text("Level \(record.build.level) \(definition?.name ?? "character")").foregroundStyle(Palette.muted)
                Text(record.build.rulesProfile.map { "\($0.edition) · evaluator \($0.evaluator)" } ?? "Legacy 2024 rules · pinned").font(.caption).foregroundStyle(Palette.muted)
                Label(summary.isValid ? "Build checks passed" : "\(summary.issues.count) choices to review", systemImage: summary.isValid ? "checkmark.seal.fill" : "pencil.line")
                    .font(.caption.weight(.medium)).foregroundStyle(summary.isValid ? Palette.sea : Palette.brass)
            }
            Spacer(minLength: 0)
        }.padding(.vertical, 8)
    }
    private var creation: some View {
        Group {
            FolioPanel(title: "Identity & origin", subtitle: record.build.rulesProfile?.edition == "2014" ? "Start with who they are. This 2014 profile does not grant 2024 background bonuses or an origin feat." : "Start with who they are. Your background supplies ability bonuses, skills, a tool, and an origin feat.") {
                TextField("Name", text: $record.build.name).folioInput()
                TextField("Pronouns", text: $record.build.pronouns).folioInput()
                TextField("A character idea in one sentence", text: $record.build.concept, axis: .vertical).folioInput()
                FolioRow { Picker("Species", selection: $record.build.speciesID) {
                    Text("Choose species").tag("")
                    ForEach(record.pack.species.filter { record.build.rulesProfile == nil || CapabilityEngine.compatible($0.capabilities, edition: record.build.rulesProfile!.edition, fallback: record.pack.ruleset) }) { Text(record.pack.optionName($0.name,id:$0.id)).tag($0.id) }
                } }
                if let species = record.pack.species.first(where: { $0.id == record.build.speciesID }) {
                    Text(species.text).font(.subheadline).foregroundStyle(Palette.muted)
                }
                FolioRow { Picker("Background", selection: $record.build.backgroundID) {
                    Text("Choose background").tag("")
                    ForEach(record.pack.backgrounds.filter { record.build.rulesProfile == nil || CapabilityEngine.compatible($0.capabilities, edition: record.build.rulesProfile!.edition, fallback: record.pack.ruleset) }) { Text(record.pack.optionName($0.name,id:$0.id)).tag($0.id) }
                } }
                if let background = record.pack.backgrounds.first(where: { $0.id == record.build.backgroundID }) {
                    Text(background.text).font(.subheadline).foregroundStyle(Palette.muted)
                    Text("Skills: \(background.skills.joined(separator: ", "))\nTool: \(background.tool)" + (record.build.rulesProfile?.edition == "2014" ? "" : "\nOrigin feat: \(record.pack.feats.first { $0.id == background.originFeatID }?.name ?? "Missing")"))
                        .font(.subheadline).foregroundStyle(Palette.ink)
                }
            }
            FolioPanel(title: "Choose ability scores", subtitle: "Assign 15, 14, 13, 12, 10, and 8 once each." + (record.build.rulesProfile?.edition == "2014" ? "" : " Background bonuses come next.")) {
                ForEach(Ability.allCases) { ability in
                    FolioRow {
                        Text(ability.name).font(.body.weight(.medium)).frame(maxWidth: .infinity, alignment: .leading)
                        Picker("\(ability.name) base", selection: scoreBinding(ability, background: false)) {
                            ForEach(RulesEngine.standardArray, id: \.self) { Text("\($0)").tag($0) }
                        }.labelsHidden().frame(width: 76).padding(8).background(.white, in: Capsule())
                    }
                }
            }
            if record.build.rulesProfile?.edition != "2014" { FolioPanel(title: "Background bonuses", subtitle: "Add +2 and +1 to different eligible abilities, or +1 to all three.") {
                let allowed = record.pack.backgrounds.first { $0.id == record.build.backgroundID }?.abilities ?? []
                if allowed.isEmpty { Text("Choose a background above to see its eligible abilities.").foregroundStyle(Palette.muted) }
                ForEach(Ability.allCases.filter { allowed.contains($0) || record.build.backgroundBoosts[$0.rawValue, default: 0] != 0 }) { ability in
                    FolioRow {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(ability.name).font(.body.weight(.medium))
                            if !allowed.contains(ability) { Text("Clear this previous bonus").font(.caption).foregroundStyle(Palette.brass) }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        Picker("\(ability.name) background bonus", selection: scoreBinding(ability, background: true)) {
                            ForEach(0...2, id: \.self) { Text("+\($0)").tag($0) }
                        }.labelsHidden().frame(width: 76).padding(8).background(.white, in: Capsule())
                    }
                }
                Text("Final scores include any improvements selected at later levels.").font(.caption).foregroundStyle(Palette.muted)
            } }
            if let definition {
                FolioPanel(title: "Skills & languages", subtitle: record.build.rulesProfile?.edition == "2014" ? "Choose \(definition.skillCount) class skills. Languages come from your species, background, and authored choices below." : "Choose \(definition.skillCount) class skills and two standard languages. Common is included.") {
                    let granted = record.pack.backgrounds.first { $0.id == record.build.backgroundID }?.skills ?? []
                    ForEach(definition.skillPool, id: \.self) { skill in
                        FolioRow { Toggle(skill + (granted.contains(skill) ? " · from background" : ""), isOn: selection(skill, in: $record.build.classSkills)) }
                    }
                    Divider()
                    Text("Languages: " + (summary.languages.isEmpty ? "None granted yet" : summary.languages.joined(separator: ", "))).font(.subheadline)
                    if record.build.rulesProfile?.edition == "2014" && !record.build.languages.isEmpty {
                        Text("Clear retained 2024 language choices; choose languages in the authored level tracks below.").font(.caption).foregroundStyle(Palette.brass)
                    }
                    ForEach(record.build.rulesProfile?.edition == "2014" ? record.build.languages : Array(Set(record.pack.languages + record.build.languages)).sorted(), id: \.self) { language in
                        FolioRow { Toggle(language, isOn: selection(language, in: $record.build.languages)) }
                    }
                }
            }
        }
    }
    private var validation: some View {
        FolioPanel(title: summary.isValid ? "Ready for the next chapter" : "Finish these choices", subtitle: "These checks cover the supported build rules. Inventory and combat are not evaluated.") {
            if !(record.build.upgradeReview ?? []).isEmpty {
                Text("This is an explicit rules-copy review. Check all choices and calculated values before acknowledging.")
                Button("I reviewed this copy's rules and choices") { record.build.upgradeReview = nil }
            }
            ForEach(summary.issues) { issue in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "circle").font(.caption).padding(.top, 3).foregroundStyle(Palette.brass)
                    Text((issue.level.map { "Level \($0): " } ?? "") + issue.message).font(.subheadline)
                }
            }
            if record.build.level < (definition?.maxLevel ?? 1) {
                Button {
                    do { record.build = try RulesEngine.advance(record.build, in: record.pack); selectedLevel = record.build.level }
                    catch { message = error.localizedDescription }
                } label: { Text("Advance to level \(record.build.level + 1)").frame(maxWidth: .infinity) }
                    .buttonStyle(FolioButton()).disabled(!summary.isValid)
            } else {
                Text("You’ve reached the level-\(definition?.maxLevel ?? 1) boundary of this pack. Your character is saved and can be duplicated or exported.").font(.subheadline).foregroundStyle(Palette.muted)
            }
        }
    }
    private func scoreBinding(_ ability: Ability, background: Bool) -> Binding<Int> {
        Binding(get: { background ? record.build.backgroundBoosts[ability.rawValue, default: 0] : record.build.baseScores[ability.rawValue, default: 10] }, set: {
            if background { record.build.backgroundBoosts[ability.rawValue] = $0 }
            else { record.build.baseScores[ability.rawValue] = $0 }
        })
    }
}

func selection(_ id: String, in values: Binding<[String]>) -> Binding<Bool> {
    Binding(get: { values.wrappedValue.contains(id) }, set: { selected in
        if selected { if !values.wrappedValue.contains(id) { values.wrappedValue.append(id) } }
        else { values.wrappedValue.removeAll { $0 == id } }
    })
}

struct LevelEditor: View {
    @Binding var build: CharacterBuild
    let pack: ContentPack
    let definition: ClassDefinition
    let level: Int
    private var index: Int { level - 1 }
    private var current: LevelChoice { build.levels[index] }
    private var summary: CharacterSummary { RulesEngine.evaluate(build, in: pack, through: level) }
    var body: some View {
        if let progression = definition.at(level) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Level \(level) decisions").font(.headline).foregroundStyle(Palette.ink)
                ForEach(definition.features.filter { $0.level == level }) { feature in
                    DisclosureGroup(feature.name) { Text(feature.text).font(.subheadline).textSelection(.enabled).padding(.vertical, 8) }
                }
                if level >= RulesEngine.subclassUnlockLevel(for: definition, build: build, in: pack) || !current.subclassID.isEmpty {
                    Picker("Subclass", selection: $build.levels[index].subclassID) {
                        Text("Choose subclass").tag("")
                        ForEach(definition.subclasses) { Text($0.name).tag($0.id) }
                    }
                    if let subclass = definition.subclasses.first(where: { $0.id == current.subclassID }) {
                        Text(subclass.text).font(.subheadline).foregroundStyle(Palette.muted)
                    }
                }
                if progression.talents > 0 {
                    if definition.capabilities?.groups?.isEmpty != false {
                    Text("\(definition.talentLabel) · \(current.talentIDs.count)/\(progression.talents)").font(.headline)
                    Text("Keep your earlier choices, add new ones as granted, or replace at most one at this level.").font(.caption).foregroundStyle(Palette.muted)
                    ForEach(definition.talents.filter { $0.minimumLevel <= level }) { talent in
                        ChoiceRow(name: talent.name, text: talent.text, isSelected: selection(talent.id, in: $build.levels[index].talentIDs))
                    }
                    }
                }
                if progression.cantrips > 0 && definition.capabilities?.casting?.isEmpty != false {
                    SpellPicker(title: "Cantrips", count: progression.cantrips, spells: pack.spells.filter { current.cantripIDs.contains($0.id) || (definition.spellIDs.contains($0.id) && $0.level == 0 && !summary.grantedSpellIDs.contains($0.id)) }, selection: $build.levels[index].cantripIDs)
                }
                if progression.spells > 0 && definition.capabilities?.casting?.isEmpty != false {
                    SpellPicker(title: "Known spells", count: progression.spells, spells: pack.spells.filter { current.spellIDs.contains($0.id) || (definition.spellIDs.contains($0.id) && $0.level > 0 && $0.level <= progression.slotLevel && !summary.grantedSpellIDs.contains($0.id)) }, selection: $build.levels[index].spellIDs)
                }
                if build.rulesProfile != nil { CapabilityEditor(build: $build, pack: pack, definition: definition, level: level) }
                if !summary.grantedSpellIDs.isEmpty {
                    Text("Granted by your subclass").font(.headline)
                    ForEach(summary.spells.filter { summary.grantedSpellIDs.contains($0.id) }) { spell in
                        Label(spell.name, systemImage: "gift").font(.subheadline).foregroundStyle(Palette.sea)
                    }
                    Text("These do not use your known-spell choices.").font(.caption).foregroundStyle(Palette.muted)
                }
                if progression.improvement {
                    Picker("Feat or ability improvement", selection: Binding(get: { current.featID }, set: { build.levels[index].featID = $0; build.levels[index].boosts = [:] })) {
                        Text("Choose an improvement").tag("")
                        ForEach(pack.feats.filter { $0.category == "general" && $0.minimumLevel <= level }) { Text(pack.optionName($0.name,id:$0.id)).tag($0.id) }
                    }
                    if let feat = pack.feats.first(where: { $0.id == current.featID }) {
                        Text(feat.text).font(.subheadline).foregroundStyle(Palette.muted)
                        ForEach(feat.abilityOptions) { ability in
                            Stepper("\(ability.name): +\(current.boosts[ability.rawValue, default: 0])", value: Binding(get: { build.levels[index].boosts[ability.rawValue, default: 0] }, set: { build.levels[index].boosts[ability.rawValue] = $0 }), in: 0...min(2, feat.abilityPoints))
                        }
                    }
                }
                let issues = summary.issues.filter { $0.level == level }
                if !issues.isEmpty {
                    VStack(alignment: .leading, spacing: 6) { ForEach(issues) { Text($0.message).font(.caption).foregroundStyle(Palette.brass) } }
                }
            }
        }
    }
}

struct ChoiceRow: View {
    let name: String
    let text: String
    @Binding var isSelected: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(name, isOn: $isSelected).font(.subheadline.weight(.medium))
            DisclosureGroup("Read details") { Text(text).font(.subheadline).foregroundStyle(Palette.muted).textSelection(.enabled).padding(.vertical, 8) }
                .font(.caption).foregroundStyle(Palette.muted)
        }.padding(18).background(Palette.surface, in: RoundedRectangle(cornerRadius: 26))
            .overlay(RoundedRectangle(cornerRadius: 26).stroke(isSelected ? Palette.ink : Color.clear, lineWidth: 1))
    }
}

struct SpellPicker: View {
    let title: String
    let count: Int
    let spells: [Spell]
    @Binding var selection: [String]
    @State private var query = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(title) · \(selection.count)/\(count)").font(.headline)
            TextField("Find a spell", text: $query).folioInput()
            ForEach(spells.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }) { spell in
                ChoiceRow(name: spell.name + (spell.level > 0 ? " · level \(spell.level)" : ""), text: spell.text, isSelected: FolioAppSelection(spell.id, values: $selection))
            }
        }
    }
    private func FolioAppSelection(_ id: String, values: Binding<[String]>) -> Binding<Bool> {
        Binding(get: { values.wrappedValue.contains(id) }, set: { enabled in
            if enabled && !values.wrappedValue.contains(id) { values.wrappedValue.append(id) }
            else if !enabled { values.wrappedValue.removeAll { $0 == id } }
        })
    }
}

struct CharacterSheet: View {
    var record: CharacterRecord
    var summary: CharacterSummary
    var body: some View {
        VStack(spacing: 20) {
            FolioPanel(title: "At a glance", subtitle: "Fixed-average hit points. Armor values assume no equipped armor or shield.") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 95))]) {
                    StatView(value: "\(summary.hitPoints)", label: "Maximum HP")
                    StatView(value: "\(summary.armorClass)", label: "Unarmored AC")
                    if let ac = summary.mantleArmorClass { StatView(value: "\(ac)", label: "Mantle AC") }
                    StatView(value: signed(summary.proficiency), label: "Proficiency")
                    StatView(value: signed(summary.initiative), label: "Initiative")
                    StatView(value: "\(summary.speed) ft", label: "Speed")
                }
                Divider()
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 82))]) {
                    ForEach(Ability.allCases) { ability in
                        StatView(value: "\(summary.scores[ability.rawValue, default: 10]) (\(signed(Ability.modifier(summary.scores[ability.rawValue, default: 10]))))", label: ability.name)
                    }
                }
            }
            if summary.slots > 0 {
                FolioPanel(title: "Magic", subtitle: "These are build capacities, not a live combat tracker.") {
                    HStack {
                        StatView(value: "\(summary.slots)", label: "Level-\(summary.slotLevel) slots")
                        StatView(value: "\(summary.spellDC ?? 0)", label: "Spell save DC")
                        StatView(value: signed(summary.spellAttack ?? 0), label: "Spell attack")
                    }
                    ForEach(summary.spells) { spell in
                        DisclosureGroup { Text(spell.text).font(.subheadline).padding(.vertical, 8).textSelection(.enabled) } label: {
                            HStack { Text(spell.name); Spacer(); if summary.grantedSpellIDs.contains(spell.id) { Image(systemName: "gift").foregroundStyle(Palette.sea) } }
                        }
                    }
                }
            }
            FolioPanel(title: "Proficiencies") {
                if let cls = record.pack.classes.first(where: { $0.id == record.build.classID }) {
                    ForEach(cls.saves) { ability in
                        HStack { Text("\(ability.name) save"); Spacer(); Text(signed(Ability.modifier(summary.scores[ability.rawValue, default: 10]) + summary.proficiency)).fontWeight(.semibold) }
                    }
                    Divider()
                }
                ForEach(summary.skillModifiers.isEmpty ? summary.skills : summary.skillModifiers.keys.sorted(), id: \.self) { skill in
                    let ability = RulesEngine.skillAbilities[skill] ?? .wis
                    HStack { Text(skill + (summary.proficiencyRanks[skill] == .expertise ? " · expertise" : "")); Spacer(); Text(signed(summary.skillModifiers[skill] ?? (Ability.modifier(summary.scores[ability.rawValue, default: 10]) + summary.proficiency))).fontWeight(.semibold) }
                }
                Text(summary.languages.joined(separator: ", ")).font(.subheadline).foregroundStyle(Palette.muted)
                Text("Conditional advantages and combat effects remain in their feature descriptions.").font(.caption).foregroundStyle(Palette.muted)
            }
            FolioPanel(title: "Features & choices") {
                if let size = summary.size { Text("Configured size: \(size)") }
                ForEach(summary.traits, id: \.self) { Text($0) }
                ForEach(summary.resources) { resource in Text("\(resource.name): \(resource.maximum) · \(resource.recovery)") }
                ForEach(summary.supportDiagnostics, id: \.self) { Text($0).font(.caption) }
                if let species = record.pack.species.first(where: { $0.id == record.build.speciesID }) {
                    DisclosureGroup(species.name) { Text(species.text).font(.subheadline).padding(.vertical, 8).textSelection(.enabled) }
                }
                ForEach(record.pack.feats.filter { feat in
                    CharacterPresentation.showsFeat(feat.id, originID: record.pack.backgrounds.first(where: { $0.id == record.build.backgroundID })?.originFeatID, selectedIDs: record.build.levels.map(\.featID), edition: record.build.rulesProfile?.edition)
                }) { feat in DisclosureGroup(feat.name) { Text(feat.text).font(.subheadline).padding(.vertical, 8).textSelection(.enabled) } }
                ForEach(summary.features) { feature in DisclosureGroup(feature.name) { Text(feature.text).font(.subheadline).padding(.vertical, 8).textSelection(.enabled) } }
                ForEach(summary.talents) { talent in DisclosureGroup(talent.name) { Text(talent.text).font(.subheadline).padding(.vertical, 8).textSelection(.enabled) } }
            }
            FolioPanel(title: "What this build covers") {
                ForEach(record.pack.coverageNotes(for: record.build), id: \.self) { Text($0).font(.subheadline).foregroundStyle(Palette.muted) }
                if let cls = record.pack.classes.first(where: { $0.id == record.build.classID }) { Text(cls.equipment).font(.subheadline) }
            }
        }
    }
}
