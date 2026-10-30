import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import FolioCore
import FolioPDF

struct SheetExportView:View {
    var record:CharacterRecord
    var directory:URL
    var onExport:(Data)->Void
    @State private var pdf:Data?
    @State private var importing=false
    @State private var error:String?
    private var storage:SheetTemplateStore { SheetTemplateStore(directory:directory) }
    var body:some View {
        VStack(alignment:.leading,spacing:18) {
            Text("Your 2024 character sheet").font(.title2.weight(.medium))
            if let pdf {
                Text("Built from your current choices. Blank combat and equipment fields are for manual completion; full descriptions continue on extra pages.").font(.subheadline).foregroundStyle(Palette.muted)
                if record.pack.isPrivate { Label("This PDF includes private content. Share only where you have permission.",systemImage:"lock").font(.caption) }
                Button {
                    onExport(pdf)
                } label: { Label("Export PDF",systemImage:"square.and.arrow.up").frame(maxWidth:.infinity) }.buttonStyle(FolioButton())
                SheetPDFView(data:pdf).frame(height:680).clipShape(RoundedRectangle(cornerRadius:18))
                    .accessibilityLabel("2024 character sheet PDF preview")
                Text("The preview is read-only. You can edit form fields in a PDF app after export; those edits do not change this character.").font(.caption).foregroundStyle(Palette.muted)
            } else {
                Text("One-time setup: download the official blank sheet, then import that PDF here. It stays on your device and works offline after setup.")
                Link("Download the official 2024 sheet",destination:SheetPDF.templateURL)
                Button("Import blank sheet PDF") { importing=true }.buttonStyle(FolioButton())
            }
            if let error { Text(error).foregroundStyle(.red).textSelection(.enabled) }
            if pdf != nil { Button("Replace blank template") { importing=true }.buttonStyle(.plain).font(.caption) }
        }
        .onAppear { rebuild() }
        .onChange(of:record) { rebuild() }
        .fileImporter(isPresented:$importing,allowedContentTypes:[.pdf]) { result in
            do {
                let url=try result.get(), access=url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let size=try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0
                guard size <= 5_000_000 else { throw FolioError.invalid("Choose a blank template under 5 MB.") }
                try storage.install(Data(contentsOf:url)); rebuild()
            } catch { self.error=error.localizedDescription }
        }
    }
    private func rebuild() {
        pdf=nil; error=nil
        guard FileManager.default.fileExists(atPath:directory.appendingPathComponent("blank-2024-sheet.pdf").path) else { return }
        do { pdf=try SheetPDF.render(PrintableSheet(record:record),template:storage.load()) }
        catch { self.error=error.localizedDescription }
    }
}

@MainActor private func configure(_ view:PDFView,data:Data) {
    guard let document=PDFDocument(data:data) else { return }
    // Read-only preview copy; exported bytes keep their editable fields.
    for i in 0..<document.pageCount { for a in document.page(at:i)?.annotations ?? [] { a.isReadOnly=true } }
    view.document=document; view.autoScales=true; view.displayMode = .singlePageContinuous
}

#if os(macOS)
struct SheetPDFView:NSViewRepresentable {
    var data:Data
    class Coordinator { var data:Data? }
    func makeCoordinator()->Coordinator { Coordinator() }
    func makeNSView(context:Context)->PDFView { PDFView() }
    func updateNSView(_ view:PDFView,context:Context) {
        guard context.coordinator.data != data else { return }
        context.coordinator.data=data; configure(view,data:data)
    }
}
#else
struct SheetPDFView:UIViewRepresentable {
    var data:Data
    class Coordinator { var data:Data? }
    func makeCoordinator()->Coordinator { Coordinator() }
    func makeUIView(context:Context)->PDFView { PDFView() }
    func updateUIView(_ view:PDFView,context:Context) {
        guard context.coordinator.data != data else { return }
        context.coordinator.data=data; configure(view,data:data)
    }
}
#endif
