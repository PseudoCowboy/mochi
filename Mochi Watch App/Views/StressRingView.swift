import SwiftUI

struct StressRingView: View {
    var segments: Int
    var activeColor: Color
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<4) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(index < segments ? activeColor : Color.gray.opacity(0.3))
                    .frame(width: 14, height: 3)
            }
        }
    }
}

#Preview {
    StressRingView(segments: 2, activeColor: .okay)
}
