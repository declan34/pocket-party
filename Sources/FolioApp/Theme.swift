import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum Palette {
    static let ink = Color.black
    static let paper = Color.white
    static let surface = Color(red: 0.957, green: 0.957, blue: 0.965)
    static let muted = Color(red: 0.40, green: 0.40, blue: 0.43)
    static let line = Color.black.opacity(0.10)
    static let brass = Color(red: 0.48, green: 0.32, blue: 0.12)
    static let sea = Color(red: 0.18, green: 0.38, blue: 0.29)
    static let portraits: [Color] = [
        Color(red: 0.79, green: 0.87, blue: 0.95), Color(red: 0.83, green: 0.90, blue: 0.85),
        Color(red: 0.89, green: 0.86, blue: 0.93), Color(red: 0.95, green: 0.87, blue: 0.81)
    ]
}

struct FolioPanel<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 7) {
                Text(title).font(.title3.weight(.semibold)).foregroundStyle(Palette.ink)
                if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true) }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 12)
    }
}

struct FolioButton: ButtonStyle {
    var secondary = false
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.body.weight(.medium))
            .padding(.horizontal, 22).padding(.vertical, 15).frame(minHeight: 48)
            .foregroundStyle(secondary ? Palette.ink : Color.white)
            .background(secondary ? Palette.surface : Palette.ink, in: Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.35)
    }
}

struct FolioRow<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        HStack(spacing: 12) { content }
            .padding(.horizontal, 18).padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 30))
    }
}

struct CircleAction: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 19, weight: .regular))
            .frame(width: 46, height: 46).background(Palette.paper, in: Circle())
            .overlay(Circle().stroke(Palette.line, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

struct CharacterAvatar: View {
    var name: String
    var portrait: Data?
    var size: CGFloat
    private var color: Color {
        let value = name.unicodeScalars.reduce(UInt32(0)) { $0 &+ $1.value }
        return Palette.portraits[Int(value % UInt32(Palette.portraits.count))]
    }
    private var image: Image? {
        guard let portrait else { return nil }
        #if os(macOS)
        return NSImage(data: portrait).map { Image(nsImage: $0) }
        #else
        return UIImage(data: portrait).map { Image(uiImage: $0) }
        #endif
    }
    var body: some View {
        ZStack {
            Circle().fill(color)
            if let image { image.resizable().scaledToFill() }
            else {
                Text(CharacterPresentation.initials(for: name))
                    .font(.system(size: size * 0.30, weight: .regular))
                    .foregroundStyle(Palette.ink.opacity(0.65))
            }
        }.frame(width: size, height: size).clipShape(Circle()).accessibilityHidden(true)
    }
}

struct StatView: View {
    var value: String
    var label: String
    var body: some View {
        VStack(spacing: 7) {
            Text(value).font(.title2.weight(.medium)).foregroundStyle(Palette.ink)
            Text(label).font(.caption).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 15)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 25))
    }
}

extension View {
    func folioInput() -> some View {
        self.textFieldStyle(.plain).padding(16)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 24))
    }
}

func signed(_ value: Int) -> String { value >= 0 ? "+\(value)" : "\(value)" }
