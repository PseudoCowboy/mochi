import SwiftUI

extension Color {
    // Brand palette
    static let brandPrimary = Color("BrandPrimary")
    static let brandAccent = Color("BrandAccent")
    static let calmGreen = Color("CalmGreen")
    static let overOrange = Color("OverOrange")

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
}
