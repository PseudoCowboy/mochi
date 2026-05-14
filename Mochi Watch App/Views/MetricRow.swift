import SwiftUI

struct MetricRow: View {
    var bpm: Int
    var hrv: Int
    
    var body: some View {
        HStack(spacing: 4) {
            VStack(alignment: .leading, spacing: 0) {
                Text("♥ BPM")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.gray)
                Text("\(bpm)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.9, green: 0.3, blue: 0.3)) // Coral
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 0) {
                Text("HRV")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.gray)
                HStack(alignment: .lastTextBaseline, spacing: 1) {
                    Text("\(hrv)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("ms")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.gray)
                }
            }
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
