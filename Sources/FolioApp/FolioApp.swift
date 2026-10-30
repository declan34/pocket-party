import SwiftUI
import FolioCore

@main
struct FolioApp: App {
    @State private var store = AppStore()
    var body: some Scene {
        #if os(macOS)
        Window("Character Folio", id: "folio") {
            content.frame(minWidth: 420, minHeight: 680)
        }
        .defaultSize(width: 1020, height: 820)
        #else
        WindowGroup { content }
        #endif
    }
    private var content: some View {
        LibraryView(store: store).tint(Palette.ink).preferredColorScheme(.light)
    }
}
