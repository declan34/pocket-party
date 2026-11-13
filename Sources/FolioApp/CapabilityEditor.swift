import SwiftUI
import FolioCore

/// Edits data only. Eligibility and replacement decisions remain in FolioCore replay.
struct CapabilityEditor: View {
    @Binding var build: CharacterBuild
    let pack: ContentPack
    let definition: ClassDefinition
    let level: Int
    private var index: Int { level - 1 }
    private var choices: CapabilityChoices { build.levels[index].capabilities ?? .init() }
    private var summary: CharacterSummary { RulesEngine.evaluate(build, in: pack, through: level) }
    private var definitions: [DefinitionCapabilities] {
        let local = [definition.capabilities, definition.subclasses.first { $0.id == build.levels[index].subclassID }?.capabilities].compactMap { $0 }.map { Multiclassing.timeline($0,owner:definition.id,build:build) }
        let base = local + [
         pack.species.first { $0.id == build.speciesID }?.capabilities,
         pack.backgrounds.first { $0.id == build.backgroundID }?.capabilities].compactMap { $0 }
        let origin = build.rulesProfile?.edition == "2014" ? "" : pack.backgrounds.first { $0.id == build.backgroundID }?.originFeatID ?? ""
        return base + pack.feats.filter { feat in feat.id == origin || build.levels.prefix(level).contains { $0.featID == feat.id } }.compactMap(\.capabilities)
    }
    private func values(_ key: String, field: String = "groups") -> Binding<[String]> {
        Binding(get: {
            switch field { case "spells": choices.spells?[key] ?? []; case "prepared": choices.prepared?[key] ?? []; default: choices.groups?[key] ?? [] }
        }, set: { values in
            var next = choices
            switch field {
            case "spells": if next.spells == nil { next.spells = [:] }; next.spells?[key] = values
            case "prepared": if next.prepared == nil { next.prepared = [:] }; next.prepared?[key] = values
            default: if next.groups == nil { next.groups = [:] }; next.groups?[key] = values
            }
            build.levels[index].capabilities = next
        })
    }
    private func loadout(_ source: CastingSourceSummary) -> Binding<[String]> {
        Binding(get: { build.castingLoadouts?[source.id] ?? source.selectedLoadout }, set: { ids in
            if build.castingLoadouts == nil { build.castingLoadouts = [:] }
            build.castingLoadouts?[source.id] = ids
        })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("\(build.rulesProfile?.edition ?? pack.ruleset) rules · \(pack.sourceLabels?[definition.id] ?? pack.name)").font(.caption).foregroundStyle(Palette.muted)
            ForEach(definitions.flatMap { $0.configurations ?? [] }) { config in
                Toggle(config.name, isOn: Binding(get: { choices.configurations?.contains(config.id) == true }, set: { enabled in
                    var next = choices; var active = next.configurations ?? []
                    active.removeAll { $0 == config.id }; if enabled { active.append(config.id) }
                    next.configurations = active; build.levels[index].capabilities = next
                }))
                if !config.text.isEmpty { Text(config.text).font(.caption).foregroundStyle(Palette.muted) }
            }
            ForEach(definitions.flatMap { $0.groups ?? [] }) { group in
                let active = summary.activeGroupIDs.contains(group.id)
                Text("\(group.name) · \(values(group.id).wrappedValue.count)/\(active ? group.count(at: level) : 0)").font(.headline)
                if !active { Text("Inactive for this level/configuration. Remove any retained choices.").font(.caption).foregroundStyle(Palette.muted) }
                Text(group.locked == true ? "Bonus track: choices cannot be replaced." : "Choices are checked against this track's prerequisites and replacement schedule.").font(.caption).foregroundStyle(Palette.muted)
                if group.requirementTiming == .acquisition { Text("Required bonus alternatives are checked when first acquired; later edits recheck that history.").font(.caption).foregroundStyle(Palette.muted) }
                if !(group.exclusiveGroupExceptions ?? []).isEmpty { Text("This track explicitly permits an additional distinct variant from its declared family; duplicate options remain invalid.").font(.caption).foregroundStyle(Palette.muted) }
                ForEach(Set(values(group.id).wrappedValue).sorted().filter { id in !group.options.contains { $0.id == id } },id:\.self) { id in
                    Text("Retained unavailable choice: \(id)").font(.caption)
                    Button("Remove unavailable choice") { values(group.id).wrappedValue.removeAll { $0 == id } }
                }
                ForEach(group.options) { option in
                    if option.repeatable == true {
                        Stepper(option.name + " · \(values(group.id).wrappedValue.filter { $0 == option.id }.count)", value: Binding(get: { values(group.id).wrappedValue.filter { $0 == option.id }.count }, set: { count in
                            var selected = values(group.id).wrappedValue.filter { $0 != option.id }; selected += Array(repeating: option.id, count: count); values(group.id).wrappedValue = selected
                        }), in: 0...group.count(at: level))
                    } else { ChoiceRow(name: option.name, text: option.text, isSelected: selection(option.id, in: values(group.id))) }
                }
            }
            ForEach(definitions.flatMap { $0.casting ?? [] }) { policy in
                let active = summary.activePolicyIDs.contains(policy.id)
                let count = active && policy.counts.indices.contains(index) ? policy.counts[index] : 0
                let maximum = policy.maximumSpellLevels.indices.contains(index) ? policy.maximumSpellLevels[index] : 0
                if !(policy.hasEditableLoadout && policy.mode == .prepared && active) {
                    SpellPicker(title: "\(policy.name) · \(policy.mode == .book ? "Learned in book" : policy.mode.rawValue.capitalized)", count: count, spells: pack.spells.filter { policy.spellIDs.contains($0.id) && $0.level <= maximum && !(policy.alwaysGrantedSpellIDs ?? []).contains($0.id) }, selection: values(policy.id, field: "spells"))
                }
                if !active { Text("Inactive policy. Clear its choices when switching to a replacement policy.").font(.caption).foregroundStyle(Palette.muted) }
                if let text = policy.text { Text(text).font(.caption).foregroundStyle(Palette.muted) }
                if policy.hasEditableLoadout, active, let source=summary.castingSources.first(where: { $0.id == policy.id }) {
                    Text("\(source.name) · \(source.ability.name) · DC \(source.dc) · access through tier \(source.maximumSpellLevel)").font(.caption).foregroundStyle(Palette.muted)
                    Text(pack.sourceLabels?[source.sourceID] ?? pack.name).font(.caption).foregroundStyle(Palette.muted)
                    if level == build.level {
                        SpellPicker(title:"Current preparation · \(policy.mode == .book ? "from learned book" : "from available list")",count:source.preparationCount,spells:pack.spells.filter { source.memberSpellIDs.contains($0.id) && !(policy.alwaysGrantedSpellIDs ?? []).contains($0.id) },selection:loadout(source))
                        Text("Preparation can change without rewriting acquired spells or earlier levels. Empty or incomplete choices remain a saved draft.").font(.caption).foregroundStyle(Palette.muted)
                    } else { Text("Edit current preparation at the latest level. This view retains acquisition history.").font(.caption).foregroundStyle(Palette.muted) }
                    if !(policy.alwaysGrantedSpellIDs ?? []).isEmpty { Text("Always granted: " + pack.spells.filter { (policy.alwaysGrantedSpellIDs ?? []).contains($0.id) }.map(\.name).joined(separator:", ")).font(.caption) }
                } else if policy.mode == .book {
                    SpellPicker(title: "Prepared from book", count: policy.preparedCounts.flatMap { $0.indices.contains(index) ? $0[index] : nil } ?? 0, spells: pack.spells.filter { values(policy.id, field: "spells").wrappedValue.contains($0.id) }, selection: values(policy.id, field: "prepared"))
                }
                if policy.loadout == .retained { Text("Retained acquisition list: replacements follow the level-up policy, even when the source calls these spells Prepared.").font(.caption).foregroundStyle(Palette.muted) }
            }
            ForEach(summary.spellPools) { pool in
                Text("\(pool.name) · \(pool.capacityDescription) · \(pool.recovery)").font(.subheadline)
            }
            if level == build.level {
                ForEach(summary.castingSources.filter { source in source.editableLoadout && !definitions.flatMap({ $0.casting ?? [] }).contains(where: { $0.id == source.id }) }) { source in
                    SpellPicker(title:"\(source.name) · current preparation",count:source.preparationCount,spells:pack.spells.filter { source.memberSpellIDs.contains($0.id) },selection:loadout(source))
                }
                ForEach((build.castingLoadouts ?? [:]).keys.sorted().filter { id in !summary.castingSources.contains { $0.id == id && $0.editableLoadout } }, id: \.self) { id in
                    Button("Clear inactive preparation: \(id)") { build.castingLoadouts?.removeValue(forKey:id) }
                }
            }
            let knownGroups=Set(definitions.flatMap { ($0.groups ?? []).map(\.id) })
            let knownPolicies=Set(definitions.flatMap { ($0.casting ?? []).map(\.id) })
            ForEach((choices.groups ?? [:]).keys.sorted().filter { !knownGroups.contains($0) },id:\.self) { id in
                Text("Retained track \(id): \((choices.groups?[id] ?? []).joined(separator:", "))").font(.caption)
                Button("Clear retained track") { build.levels[index].capabilities?.groups?.removeValue(forKey:id) }
            }
            ForEach(Set((choices.spells ?? [:]).keys).union((choices.prepared ?? [:]).keys).sorted().filter { !knownPolicies.contains($0) },id:\.self) { id in
                Text("Retained casting \(id): \((choices.spells?[id] ?? []).joined(separator:", "))").font(.caption)
                Button("Clear retained casting") { build.levels[index].capabilities?.spells?.removeValue(forKey:id); build.levels[index].capabilities?.prepared?.removeValue(forKey:id) }
            }
            let knownConfigs=Set(definitions.flatMap { ($0.configurations ?? []).map(\.id) })
            ForEach((choices.configurations ?? []).filter { !knownConfigs.contains($0) },id:\.self) { id in
                Text("Retained configuration: \(id)").font(.caption)
                Button("Clear retained configuration") { build.levels[index].capabilities?.configurations?.removeAll { $0 == id } }
            }
        }
    }
}
