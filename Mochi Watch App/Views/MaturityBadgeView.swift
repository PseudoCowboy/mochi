import SwiftUI

struct MaturityBadgeView: View {
    let level: PetMaturity.Level
    
    var body: some View {
        HStack(spacing: 2) {
            switch level {
            case .l0:
                EmptyView()
            case .l1:
                icon
            case .l2:
                icon
                icon
            case .l3:
                icon
                icon
                icon
            }
        }
    }
    
    private var icon: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 8))
            .foregroundColor(.pink)
    }
}

#Preview {
    VStack(spacing: 10) {
        // We mock PetMaturity.Level here if needed for preview, 
        // but since it's from Atlas's model, we'd rather not compile previews 
        // that rely on it without Atlas's code. 
        // If we want a preview, we can just comment it out to be safe.
    }
}
