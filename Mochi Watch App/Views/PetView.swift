import SwiftUI

struct PetView: View {
    enum Mouth {
        case smile
        case neutral
        case small
        case o
        
        var moodDescription: String {
            switch self {
            case .smile: return "smiling"
            case .neutral: return "neutral"
            case .small: return "serious"
            case .o: return "surprised"
            }
        }
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
    
    var stage: EvolutionStage
    var mouth: Mouth
    var blink: Bool
    
    var body: some View {
        Group {
            switch stage {
            case .egg:
                EggBody()
            case .baby:
                BabyBody()
            case .teen:
                TeenBody(mouth: mouth, blink: blink)
            case .adult:
                AdultBody(mouth: mouth, blink: blink)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pet, stage \(stage.displayName)")
        .accessibilityValue("\(mouth.moodDescription)\(blink ? ", blinking" : "")")
    }
}

struct EggBody: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let cx = w / 2
            let cy = h / 2
            
            ZStack {
                // Egg: elongated Ellipse filled Color(white: 0.88)
                Ellipse()
                    .fill(Color(white: 0.88))
                    .frame(width: w * 0.6, height: h * 0.8)
                    .position(x: cx, y: cy)
                
                // subtle horizontal crack Path accent
                Path { path in
                    path.move(to: CGPoint(x: cx - w * 0.2, y: cy + h * 0.1))
                    path.addLine(to: CGPoint(x: cx - w * 0.05, y: cy + h * 0.15))
                    path.addLine(to: CGPoint(x: cx + w * 0.05, y: cy + h * 0.1))
                    path.addLine(to: CGPoint(x: cx + w * 0.2, y: cy + h * 0.13))
                }
                .stroke(Color(white: 0.8), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

struct BabyBody: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let cx = w / 2
            let cy = h / 2
            
            ZStack {
                // Baby: small Circle body (~55% of frame)
                
                // Limbs (short stub limbs, rounded Capsules at bottom corners)
                Capsule()
                    .fill(Color(white: 0.88))
                    .frame(width: w * 0.12, height: h * 0.18)
                    .rotationEffect(.degrees(30))
                    .position(x: cx - w * 0.15, y: cy + h * 0.2)
                
                Capsule()
                    .fill(Color(white: 0.88))
                    .frame(width: w * 0.12, height: h * 0.18)
                    .rotationEffect(.degrees(-30))
                    .position(x: cx + w * 0.15, y: cy + h * 0.2)
                
                Circle()
                    .fill(Color(white: 0.88))
                    .frame(width: w * 0.55, height: h * 0.55)
                    .position(x: cx, y: cy)
                
                // Dot eyes, no mouth/ears
                Circle()
                    .fill(Color.black)
                    .frame(width: w * 0.05, height: h * 0.05)
                    .position(x: cx - w * 0.1, y: cy - h * 0.05)
                
                Circle()
                    .fill(Color.black)
                    .frame(width: w * 0.05, height: h * 0.05)
                    .position(x: cx + w * 0.1, y: cy - h * 0.05)
            }
        }
    }
}

struct TeenBody: View {
    var mouth: PetView.Mouth
    var blink: Bool
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let cx = w / 2
            let cy = h / 2
            
            ZStack {
                // Teen: taller rounded-rectangle / vertical capsule body (~70% x 85% of frame)
                // Angled arm/leg capsules
                
                // Arms
                Capsule()
                    .fill(Color(white: 0.88))
                    .frame(width: w * 0.12, height: h * 0.3)
                    .rotationEffect(.degrees(45))
                    .position(x: cx - w * 0.3, y: cy)
                
                Capsule()
                    .fill(Color(white: 0.88))
                    .frame(width: w * 0.12, height: h * 0.3)
                    .rotationEffect(.degrees(-45))
                    .position(x: cx + w * 0.3, y: cy)
                
                // Legs
                Capsule()
                    .fill(Color(white: 0.88))
                    .frame(width: w * 0.12, height: h * 0.25)
                    .position(x: cx - w * 0.15, y: cy + h * 0.35)
                
                Capsule()
                    .fill(Color(white: 0.88))
                    .frame(width: w * 0.12, height: h * 0.25)
                    .position(x: cx + w * 0.15, y: cy + h * 0.35)
                
                // Body
                Capsule()
                    .fill(Color(white: 0.88))
                    .frame(width: w * 0.70, height: h * 0.85)
                    .position(x: cx, y: cy)
                
                // Eyes (dot eyes)
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
                    Circle()
                        .fill(Color.black)
                        .frame(width: w * 0.05, height: h * 0.05)
                        .position(x: cx - w * 0.14, y: cy - h * 0.05)
                    
                    Circle()
                        .fill(Color.black)
                        .frame(width: w * 0.05, height: h * 0.05)
                        .position(x: cx + w * 0.14, y: cy - h * 0.05)
                }
                
                // Mouth
                PetView.MouthShape(mouth: mouth)
                    .stroke(Color.black, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
        }
    }
}

struct AdultBody: View {
    var mouth: PetView.Mouth
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
                    .position(x: cx, y: cy)
                
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
                PetView.MouthShape(mouth: mouth)
                    .stroke(Color.black, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                
            }
        }
    }
}

#Preview {
    Group {
        PetView(stage: .egg, mouth: .smile, blink: false)
            .frame(width: 90, height: 90)
            .background(Color.gray)
        PetView(stage: .baby, mouth: .smile, blink: false)
            .frame(width: 90, height: 90)
            .background(Color.gray)
        PetView(stage: .teen, mouth: .smile, blink: false)
            .frame(width: 90, height: 90)
            .background(Color.gray)
        PetView(stage: .adult, mouth: .smile, blink: false)
            .frame(width: 90, height: 90)
            .background(Color.gray)
    }
}
