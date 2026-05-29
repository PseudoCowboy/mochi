import SwiftUI

extension Color {
    // Brand palette: brandPrimary/brandAccent/calmGreen/overOrange are
    // auto-generated on Color from the asset catalog by Xcode 15+
    // (GeneratedAssetSymbols.swift), so we don't redeclare them here.

    // Stress palette
    static let calm = Color(red: 0.339, green: 0.821, blue: 0.637)  // oklch(78% 0.13 165)
    static let okay = Color(red: 0.881, green: 0.763, blue: 0.293)  // oklch(82% 0.14 95)
    static let stressed = Color(red: 0.990, green: 0.548, blue: 0.272) // oklch(75% 0.16 50)
    static let over = Color(red: 0.953, green: 0.384, blue: 0.365)  // oklch(68% 0.18 25)
    
    // Core palette
    static let bg = Color(white: 0.96)                              // var(--bg)
    static let surface = Color(white: 0.98)                         // var(--surface)
    static let ink = Color(white: 0.15)                             // var(--ink)
    static let muted = Color(white: 0.45)                           // var(--muted)
    static let border = Color(white: 0.85)                          // var(--border)

    // Grow-style restyle palette (calm-blue ↔ warm-amber)
    static let growCalmBlue = Color(red: 0.42, green: 0.69, blue: 0.93)
    static let growSkyBlue  = Color(red: 0.58, green: 0.81, blue: 0.97)
    static let growAmber    = Color(red: 0.99, green: 0.74, blue: 0.31)
    static let growSun      = Color(red: 1.00, green: 0.83, blue: 0.40)
    static let growEmber    = Color(red: 0.97, green: 0.46, blue: 0.30)
}

extension StressState {
    /// Grow-style tint that shifts calm-blue → warm-amber based on state.
    var growTint: Color {
        switch self {
        case .calm:     return .growCalmBlue
        case .okay:     return .growSkyBlue
        case .stressed: return .growAmber
        case .over:     return .growEmber
        }
    }

    var growGradient: LinearGradient {
        let colors: [Color]
        switch self {
        case .calm:     colors = [.growSkyBlue, .growCalmBlue]
        case .okay:     colors = [.growSkyBlue, .growSun]
        case .stressed: colors = [.growSun, .growAmber]
        case .over:     colors = [.growAmber, .growEmber]
        }
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }
}
