import SwiftUI
import WidgetKit

struct MiniPetFace: View {
    let state: StressState
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let cx = w / 2
            let cy = h / 2
            
            ZStack {
                // Two eye dots
                Circle()
                    .fill(Color.ink)
                    .frame(width: w * 0.15, height: w * 0.15)
                    .position(x: cx - w * 0.15, y: cy - h * 0.05)
                
                Circle()
                    .fill(Color.ink)
                    .frame(width: w * 0.15, height: w * 0.15)
                    .position(x: cx + w * 0.15, y: cy - h * 0.05)
                
                // Mouth shape reusing PetView.MouthShape
                PetView.MouthShape(mouth: state.mouthShape)
                    .stroke(Color.ink, style: StrokeStyle(lineWidth: max(1.5, w * 0.05), lineCap: .round))
            }
        }
    }
}

struct StressPetComplicationView: View {
    var entry: StressPetEntry
    
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                Circle()
                    .fill(entry.state.headlineColor)
                
                MiniPetFace(state: entry.state)
                    .padding(8)
            }
            .widgetAccentable()
            .accessibilityLabel(Text(entry.state.label))
            .accessibilityValue(Text("\(entry.bpm) BPM"))
            .accessibilityHint(Text("Double-tap to open Mochi"))
            
        case .accessoryCorner:
            ZStack {
                Circle()
                    .stroke(entry.state.headlineColor, lineWidth: 3)
                    .widgetCurvesContent()
                
                MiniPetFace(state: entry.state)
                    .padding(4)
            }
            .widgetLabel {
                Text(entry.state.label)
            }
            .accessibilityLabel(Text(entry.state.label))
            .accessibilityValue(Text("\(entry.bpm) BPM"))
            .accessibilityHint(Text("Double-tap to open Mochi"))
            
        default:
            Text(entry.state.label)
        }
    }
}

// Ensure Xcode previews work if StressPetEntry is available
#Preview("Circular", traits: .sizeThatFitsLayout) {
    StressPetComplicationView(entry: StressPetEntry(date: Date(), state: .okay, bpm: 80))
}
