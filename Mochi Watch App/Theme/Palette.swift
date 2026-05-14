import SwiftUI

extension Color {
    // Stress palette
    static let calm = Color(red: 0.16, green: 0.85, blue: 0.73)     // oklch(78% 0.13 165) mint approx
    static let okay = Color(red: 0.95, green: 0.82, blue: 0.28)     // oklch(82% 0.14 95) butter approx
    static let stressed = Color(red: 0.98, green: 0.53, blue: 0.38) // oklch(75% 0.16 50) peach approx
    static let over = Color(red: 0.93, green: 0.33, blue: 0.31)     // oklch(68% 0.18 25) coral approx
    
    // Core palette
    static let bg = Color(white: 0.96)                              // var(--bg)
    static let surface = Color(white: 0.98)                         // var(--surface)
    static let ink = Color(white: 0.15)                             // var(--ink)
    static let muted = Color(white: 0.45)                           // var(--muted)
    static let border = Color(white: 0.85)                          // var(--border)
}
