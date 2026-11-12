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
        let base = [definition.capabilities, definition.subclasses.first { $0.id == build.levels[index].subclassID }?.capabilities,
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
                SpellPicker(title: "\(policy.name) · \(policy.mode.rawValue.capitalized)", count: count, spells: pack.spells.filter { policy.spellIDs.contains($0.id) && $0.level <= maximum }, selection: values(policy.id, field: "spells"))
                if !active { Text("Inactive policy. Clear its choices when switching to a replacement policy.").font(.caption).foregroundStyle(Palette.muted) }
                if let text = policy.text { Text(text).font(.caption).foregroundStyle(Palette.muted) }
                if policy.mode == .book {
                    SpellPicker(title: "Prepared from book", count: policy.preparedCounts.flatMap { $0.indices.contains(index) ? $0[index] : nil } ?? 0, spells: pack.spells.filter { values(policy.id, field: "spells").wrappedValue.contains($0.id) }, selection: values(policy.id, field: "prepared"))
                }
            }
        }
    }
}
