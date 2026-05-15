import SwiftUI

struct PetView: View {
    enum Mouth {
        case smile
        case neutral
        case small
        case o
    }
    
    struct MouthShape: Shape {
        var mouth: Mouth
        
        func path(in rect: CGRect) -> Path {
            var path = Path()
            let w = rect.width
            let h = rect.height
            let cx = w / 2
            let cy = h / 2
            
            switch mouth {
            case .smile:
                path.move(to: CGPoint(x: cx - w * 0.08, y: cy + h * 0.1))
                path.addQuadCurve(to: CGPoint(x: cx, y: cy + h * 0.1), control: CGPoint(x: cx - w * 0.04, y: cy + h * 0.14))
                path.addQuadCurve(to: CGPoint(x: cx + w * 0.08, y: cy + h * 0.1), control: CGPoint(x: cx + w * 0.04, y: cy + h * 0.14))
            case .neutral:
                path.move(to: CGPoint(x: cx - w * 0.04, y: cy + h * 0.12))
                path.addQuadCurve(to: CGPoint(x: cx + w * 0.04, y: cy + h * 0.1), control: CGPoint(x: cx, y: cy + h * 0.13))
            case .small:
                path.move(to: CGPoint(x: cx - w * 0.04, y: cy + h * 0.12))
                path.addLine(to: CGPoint(x: cx + w * 0.04, y: cy + h * 0.12))
            case .o:
                path.move(to: CGPoint(x: cx - w * 0.05, y: cy + h * 0.14))
                path.addQuadCurve(to: CGPoint(x: cx + w * 0.05, y: cy + h * 0.14), control: CGPoint(x: cx, y: cy + h * 0.09))
            }
            return path
        }
    }
    
    var mouth: Mouth
    var blink: Bool
    
    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let w = size.width
            let h = size.height
            let cx = w / 2
            let cy = h / 2
            
            ZStack {
                // Ears
                Path { path in
                    path.move(to: CGPoint(x: cx - w * 0.35, y: cy - h * 0.15))
                    path.addLine(to: CGPoint(x: cx - w * 0.25, y: cy - h * 0.4))
                    path.addLine(to: CGPoint(x: cx - w * 0.15, y: cy - h * 0.2))
                    path.closeSubpath()
                }
                .fill(Color(white: 0.85))
                
                Path { path in
                    path.move(to: CGPoint(x: cx + w * 0.35, y: cy - h * 0.15))
                    path.addLine(to: CGPoint(x: cx + w * 0.25, y: cy - h * 0.4))
                    path.addLine(to: CGPoint(x: cx + w * 0.15, y: cy - h * 0.2))
                    path.closeSubpath()
                }
                .fill(Color(white: 0.85))
                
                // Head
                Ellipse()
                    .fill(Color(white: 0.88))
                    .frame(width: w * 0.75, height: h * 0.65)
                
                // Cheeks
                Circle()
                    .fill(Color(red: 0.9, green: 0.4, blue: 0.4).opacity(0.4))
                    .frame(width: w * 0.12, height: w * 0.12)
                    .position(x: cx - w * 0.2, y: cy + h * 0.05)
                
                Circle()
                    .fill(Color(red: 0.9, green: 0.4, blue: 0.4).opacity(0.4))
                    .frame(width: w * 0.12, height: w * 0.12)
                    .position(x: cx + w * 0.2, y: cy + h * 0.05)
                
                // Eyes
                Group {
                    if blink {
                        Path { path in
                            path.move(to: CGPoint(x: cx - w * 0.18, y: cy - h * 0.05))
                            path.addLine(to: CGPoint(x: cx - w * 0.1, y: cy - h * 0.05))
                        }
                        .stroke(Color.black, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        
                        Path { path in
                            path.move(to: CGPoint(x: cx + w * 0.1, y: cy - h * 0.05))
                            path.addLine(to: CGPoint(x: cx + w * 0.18, y: cy - h * 0.05))
                        }
                        .stroke(Color.black, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    } else {
                        // Eye arcs
                        Path { path in
                            path.move(to: CGPoint(x: cx - w * 0.18, y: cy - h * 0.05))
                            path.addQuadCurve(to: CGPoint(x: cx - w * 0.1, y: cy - h * 0.05), control: CGPoint(x: cx - w * 0.14, y: cy - h * 0.09))
                        }
                        .stroke(Color.black, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        
                        Path { path in
                            path.move(to: CGPoint(x: cx + w * 0.1, y: cy - h * 0.05))
                            path.addQuadCurve(to: CGPoint(x: cx + w * 0.18, y: cy - h * 0.05), control: CGPoint(x: cx + w * 0.14, y: cy - h * 0.09))
                        }
                        .stroke(Color.black, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    }
                }
                
                // Nose
                Path { path in
                    path.move(to: CGPoint(x: cx - w * 0.03, y: cy + h * 0.04))
                    path.addLine(to: CGPoint(x: cx + w * 0.03, y: cy + h * 0.04))
                    path.addLine(to: CGPoint(x: cx, y: cy + h * 0.07))
                    path.closeSubpath()
                }
                .fill(Color(white: 0.3))
                
                // Mouth
                MouthShape(mouth: mouth)
                    .stroke(Color.black, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                
            }
        }
    }
}

#Preview {
    PetView(mouth: .smile, blink: false)
        .frame(width: 100, height: 100)
}
