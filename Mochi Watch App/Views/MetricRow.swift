import SwiftUI

struct MetricRow: View {
    var bpm: Int
    var hrv: Int
    
    var body: some View {
        HStack(spacing: 4) {
            VStack(alignment: .leading, spacing: 0) {
                Text("♥ BPM")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.gray)
                Text("\(bpm)")
                    .font(.title3.weight(.bold))
                    .foregroundColor(Color(red: 0.9, green: 0.3, blue: 0.3)) // Coral
            }
            .dynamicTypeSize(.small ... .accessibility2)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 0) {
                Text("HRV")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.gray)
                HStack(alignment: .lastTextBaseline, spacing: 1) {
                    Text("\(hrv)")
                        .font(.title3.weight(.bold))
                        .foregroundColor(.white)
                    Text("ms")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.gray)
                }
            }
            .dynamicTypeSize(.small ... .accessibility2)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
        }
    }
}

#Preview {
    MetricRow(bpm: 68, hrv: 62)
}
