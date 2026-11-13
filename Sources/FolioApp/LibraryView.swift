import SwiftUI
import UniformTypeIdentifiers
import FolioCore

struct CharacterExportFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .pdf] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct LibraryView: View {
    @Bindable var store: AppStore
    @State private var search = ""
    @State private var importer = false
    @State private var creator = false
    @State private var packSheet = false
    @State private var message: String?
    @State private var path: [UUID] = []
    @AppStorage("folio.library.listView") private var listView = false
    @Environment(\.dynamicTypeSize) private var typeSize
    private var useList: Bool { listView || typeSize.isAccessibilitySize }
    private var filtered: [CharacterRecord] {
        store.characters.filter { record in
            CharacterPresentation.matches(name: record.build.name,
                className: record.pack.classes.first { $0.id == record.build.classID }?.name ?? "", query: search)
        }
    }
    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 28) {
                    HStack {
                        Button { packSheet = true } label: { Image(systemName: "books.vertical") }
                            .buttonStyle(CircleAction()).accessibilityLabel("Content library")
                        Spacer()
                        Text("Your characters").font(.title3.weight(.semibold))
                        Spacer()
                        Button { listView.toggle() } label: { Image(systemName: useList ? "circle.grid.2x2" : "list.bullet") }
                            .buttonStyle(CircleAction()).accessibilityLabel(useList ? "Show portrait collection" : "Show character list")
                            .disabled(typeSize.isAccessibilitySize)
                    }
                    if store.characters.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "person.crop.circle.badge.plus").font(.system(size: 56, weight: .ultraLight)).padding(.top, 35)
                            Text("Who will you be?").font(.largeTitle.weight(.medium))
                            Text("Start a character, or explore Mara’s sample build.")
                                .foregroundStyle(Palette.muted).multilineTextAlignment(.center)
                            Button("Explore a sample character") {
                                if let record = store.addDemoCharacter() { path.append(record.id) }
                            }.buttonStyle(FolioButton(secondary: true)).disabled(store.readOnly)
                        }.padding(.vertical, 24)
                    } else if filtered.isEmpty {
                        VStack(spacing: 14) {
                            Text("No matching characters").font(.title2.weight(.medium))
                            Text("Try a character or class name.").foregroundStyle(Palette.muted)
                            Button("Clear search") { search = "" }.buttonStyle(FolioButton(secondary: true))
                        }.padding(.vertical, 50)
                    } else if useList {
                        LazyVStack(spacing: 8) {
                            ForEach(filtered) { record in
                                Button { path.append(record.id) } label: { CharacterListRow(record: record) }.buttonStyle(.plain)
                            }
                        }
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .center, spacing: 25) {
                            ForEach(Array(filtered.enumerated()), id: \.element.id) { index, record in
                                Button { path.append(record.id) } label: {
                                    CharacterBubble(record: record, size: [116.0, 92.0, 94.0, 128.0][index % 4])
                                        .padding(.top, index % 2 == 0 ? 0 : 26)
                                }.buttonStyle(.plain)
                            }
                            Button { creator = true } label: {
                                VStack(spacing: 10) {
                                    Image(systemName: "plus").font(.system(size: 29, weight: .light))
                                        .frame(width: 78, height: 78).background(Palette.surface, in: Circle())
                                    Text("New character").font(.subheadline).foregroundStyle(Palette.muted)
                                }.padding(.vertical, 18).frame(maxWidth: .infinity)
                            }.buttonStyle(.plain).disabled(store.readOnly)
                        }.padding(.vertical, 16)
                    }
                }.padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
            }.background(Palette.paper)
                .safeAreaInset(edge: .bottom, spacing: 0) { dock }
                .navigationTitle("Character Folio")
                .navigationDestination(for: UUID.self) { id in
                    if let record = store.library.characters.first(where: { $0.id == id }) {
                        CharacterView(store: store, initial: record)
                    } else { Text("This character is no longer in the library.") }
                }
                .sheet(isPresented: $creator) { NewCharacterView(store: store) { path.append($0) } }
                .sheet(isPresented: $packSheet) { PackLibraryView(store: store) }
                .fileImporter(isPresented: $importer, allowedContentTypes: [.json]) { result in
                    do {
                        let url = try result.get(); let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                        message = try store.importFile(Data(contentsOf: url))
                    } catch { store.error = error.localizedDescription }
                }
                .alert("Import complete", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("Done") { message = nil } } message: { Text(message ?? "") }
                .alert("Your library needs attention", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("OK") { store.error = nil } } message: { Text(store.error ?? "") }
        }
    }
    private var dock: some View {
        VStack(spacing: 16) {
            HStack {
                dockAction("Create", icon: "plus") { creator = true }.disabled(store.readOnly)
                dockAction("Import", icon: "square.and.arrow.down") { importer = true }.disabled(store.readOnly)
                dockAction("Content", icon: "books.vertical") { packSheet = true }
            }
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                TextField("Find a character or class", text: $search).textFieldStyle(.plain)
                    .accessibilityIdentifier("library.search")
                if !search.isEmpty {
                    Button { search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.muted) }
                        .buttonStyle(.plain).accessibilityLabel("Clear search")
                }
            }.padding(15).background(.white, in: Capsule())
        }.padding(18).background(Palette.surface, in: RoundedRectangle(cornerRadius: 34))
            .padding(.horizontal, 12).padding(.bottom, 12).frame(maxWidth: 620).frame(maxWidth: .infinity)
            .background(Palette.paper)
    }
    private func dockAction(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) { Image(systemName: icon).font(.system(size: 23, weight: .regular)); Text(title).font(.caption) }
                .frame(maxWidth: .infinity, minHeight: 48)
        }.buttonStyle(.plain).accessibilityLabel(title)
    }
}

struct CharacterBubble: View {
    let record: CharacterRecord
    let size: CGFloat
    var body: some View {
        VStack(spacing: 8) {
            CharacterAvatar(name: record.build.name, portrait: record.build.portrait, size: size)
            Text(record.build.name).font(.subheadline).multilineTextAlignment(.center).foregroundStyle(Palette.ink)
            Text("Level \(record.build.level)").font(.caption).foregroundStyle(Palette.muted)
        }.frame(maxWidth: .infinity).padding(.horizontal, 4)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(record.build.name), level \(record.build.level)")
    }
}

struct CharacterListRow: View {
    let record: CharacterRecord
    var body: some View {
        let cls = record.pack.classes.first { $0.id == record.build.classID }
        HStack(spacing: 15) {
            CharacterAvatar(name: record.build.name, portrait: record.build.portrait, size: 52)
            VStack(alignment: .leading, spacing: 6) {
                Text(record.build.name).font(.body.weight(.medium))
                Text("Level \(record.build.level) \(cls?.name ?? "character")").font(.subheadline).foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Palette.muted)
        }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 32))
    }
}

struct NewCharacterView: View {
    var store: AppStore
    var onCreate: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedClass = ""
    @State private var name = ""
    @State private var catalog: ContentCatalog?
    @State private var catalogError: String?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Who are you imagining?").font(.largeTitle.weight(.regular))
                    TextField("Character name", text: $name).folioInput()
                    FolioRow {
                        Picker("Class", selection: $selectedClass) {
                            Text("Choose a class").tag("")
                            ForEach(catalog?.classes ?? []) { cls in
                                Text("\(cls.name) · \(cls.edition) · \(cls.sourceLabel)").tag(cls.id)
                            }
                        }
                    }
                    if catalog?.classes.isEmpty == true { Text("No classes installed. Import a class content pack from your library.").foregroundStyle(Palette.muted) }
                    if let catalogError { Text(catalogError).foregroundStyle(.red) }
                    Text("Start with a name. You can save unfinished builds and return to the choices later.").foregroundStyle(Palette.muted)
                    Button {
                        do {
                            guard let catalog else { return }
                            let pack = try catalog.snapshot(for:selectedClass)
                            var build = CharacterBuild(classID: selectedClass)
                            if let cls = pack.classes.first(where: { $0.id == selectedClass }), let capabilities = cls.capabilities {
                                build.rulesProfile = .init(edition: capabilities.edition)
                                build.levels[0].capabilities = .init()
                                if pack.capabilities?.required.contains("multiclass") == true { build.levels[0].classID=selectedClass }
                            }
                            build.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                            let record = CharacterRecord(pack: pack, build: build)
                            if store.save(record) { dismiss(); onCreate(record.id) }
                        } catch { catalogError = error.localizedDescription }
                    } label: { Text("Create character").frame(maxWidth: .infinity) }
                        .buttonStyle(FolioButton())
                        .disabled(store.readOnly || catalog == nil || selectedClass.isEmpty || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if let error = store.error { Text(error).font(.caption).foregroundStyle(.red) }
                }.padding(24)
            }.background(Palette.paper).navigationTitle("New character")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }.frame(minWidth: 320, idealWidth: 500, minHeight: 440)
            .onAppear {
                do { catalog = try ContentCatalog(packs:store.library.packs) }
                catch { catalogError = error.localizedDescription }
            }
    }
}

struct PackLibraryView: View {
    var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                ForEach(store.packs, id: \.self) { pack in
                    Section("\(pack.name) · \(pack.version)") {
                        Text(pack.attribution).font(.subheadline)
                        Label(pack.isPrivate ? "Private content" : "Public demonstration", systemImage: pack.isPrivate ? "lock" : "book")
                        Text("\(pack.classes.count) classes · \(pack.species.count) species · \(pack.spells.count) spells")
                        ForEach(pack.coverageNotes, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }.navigationTitle("Content library").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }.frame(minWidth: 320, idealWidth: 580, minHeight: 480)
    }
}
