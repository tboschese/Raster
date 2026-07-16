import SwiftUI

/// Native mirror of the color tokens defined in `WebCore/styles.css`, so the
/// SwiftUI chrome (toolbar, sidebar, tabs, status bar) and the WebView content
/// stay visually identical. Keep both files in sync when tokens change.
struct RasterColors {
    var bg: Color
    var panel: Color
    var side: Color
    var editorBackground: Color
    var border: Color
    var ink: Color
    var inkStrong: Color
    var dim: Color
    var accent: Color
    var info: Color
    var danger: Color
    var hover: Color
    var accentSoft: Color

    static let dark = RasterColors(
        bg: Color(hex: 0x14161A),
        panel: Color(hex: 0x1B1E24),
        side: Color(hex: 0x181B20),
        editorBackground: Color(hex: 0x16181D),
        border: Color(hex: 0x2A2E37),
        ink: Color(hex: 0xE7E5DF),
        inkStrong: Color(hex: 0xF4F2EC),
        dim: Color(hex: 0x9AA0AB),
        accent: Color(hex: 0xE0A02E),
        info: Color(hex: 0x5FB3A1),
        danger: Color(hex: 0xE4726B),
        hover: Color.white.opacity(0.05),
        accentSoft: Color(hex: 0xE0A02E).opacity(0.12)
    )

    static let light = RasterColors(
        bg: Color(hex: 0xFCFBF8),
        panel: Color(hex: 0xFFFFFF),
        side: Color(hex: 0xF6F4EF),
        editorBackground: Color(hex: 0xFCFCFA),
        border: Color(hex: 0xE5E2DB),
        ink: Color(hex: 0x23262C),
        inkStrong: Color(hex: 0x111418),
        dim: Color(hex: 0x7A8089),
        accent: Color(hex: 0xC6871B),
        info: Color(hex: 0x2F8A78),
        danger: Color(hex: 0xC0544C),
        hover: Color.black.opacity(0.045),
        accentSoft: Color(hex: 0xC6871B).opacity(0.12)
    )
}

extension Theme {
    var colors: RasterColors { self == .dark ? .dark : .light }
}

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
