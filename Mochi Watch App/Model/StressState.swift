import SwiftUI

enum StressState: Int, CaseIterable, Identifiable {
    case calm
    case okay
    case stressed
    case over
    
    var id: Self { self }
    
    var label: String {
        switch self {
        case .calm: return "Calm"
        case .okay: return "Okay"
        case .stressed: return "Stressed"
        case .over: return "Overwhelmed"
        }
    }
    
    var headlineColor: Color {
        switch self {
        case .calm: return .calm
        case .okay: return .okay
        case .stressed: return .stressed
        case .over: return .over
        }
    }
    
    var message: String {
        switch self {
        case .calm: return "You're glowing. Keep this energy ✨"
        case .okay: return "Cruising along nicely. Sip some water."
        case .stressed: return "Take 3 slow breaths with me."
        case .over: return "Pause. Eat something good. 吃点好的 🍡"
        }
    }
    
    var speech: String {
        switch self {
        case .calm: return "元气满满！"
        case .okay: return "喝口水～"
        case .stressed: return "深呼吸~"
        case .over: return "吃点好的"
        }
    }
    
    var ringSegments: Int {
        switch self {
        case .calm: return 1
        case .okay: return 2
        case .stressed: return 3
        case .over: return 4
        }
    }
    
    var mouthShape: PetView.Mouth {
        switch self {
        case .calm: return .smile
        case .okay: return .neutral
        case .stressed: return .small
        case .over: return .o
        }
    }
}
