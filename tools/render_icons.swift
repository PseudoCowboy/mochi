#!/usr/bin/env swift
import SwiftUI
import AppKit

var outDir = ""
var variant: String? = nil

let args = CommandLine.arguments
var i = 1
while i < args.count {
    if args[i] == "--out" && i + 1 < args.count {
        outDir = args[i+1]
        i += 2
    } else if args[i] == "--variant" && i + 1 < args.count {
        variant = args[i+1]
        i += 2
    } else {
        i += 1
    }
}

if outDir.isEmpty {
    print("Usage: swift render_icons.swift --out <dir> [--variant light|dark|tinted]")
    exit(1)
}

struct CalmPetFaceIcon: View {
    var variant: String

    var bgColor: Color {
        switch variant {
        case "dark": return Color(red: 0.1, green: 0.1, blue: 0.1) // #191919
        case "tinted": return Color.black
        default: return Color(red: 0.98, green: 0.85, blue: 0.38) // BrandPrimary
        }
    }

    var fgColor: Color {
        switch variant {
        case "tinted": return Color(red: 0.98, green: 0.85, blue: 0.38)
        default: return .white
        }
    }
    
    var eyeColor: Color {
        switch variant {
        case "tinted": return Color.black
        default: return bgColor
        }
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(bgColor)
            
            Circle()
                .fill(fgColor)
                .frame(width: 600, height: 600)
            
            // Eyes
            HStack(spacing: 120) {
                Circle()
                    .fill(eyeColor)
                    .frame(width: 80, height: 80)
                Circle()
                    .fill(eyeColor)
                    .frame(width: 80, height: 80)
            }
            .offset(y: -40)
            
            // Smile
            Path { path in
                path.move(to: CGPoint(x: 400, y: 600))
                path.addQuadCurve(
                    to: CGPoint(x: 624, y: 600),
                    control: CGPoint(x: 512, y: 700)
                )
            }
            .stroke(eyeColor, style: StrokeStyle(lineWidth: 40, lineCap: .round))
        }
        .frame(width: 1024, height: 1024)
    }
}

@MainActor
func render(variant: String, to path: String) {
    let view = CalmPetFaceIcon(variant: variant)
    
    if #available(macOS 13.0, *) {
        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = .init(width: 1024, height: 1024)
        
        guard let nsImage = renderer.nsImage else {
            print("Failed to render NSImage")
            exit(1)
        }
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            print("Failed to generate PNG data")
            exit(1)
        }
        
        let url = URL(fileURLWithPath: path)
        do {
            try pngData.write(to: url)
            print("Wrote \(path)")
        } catch {
            print("Failed to write \(path): \(error)")
            exit(1)
        }
    } else {
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = CGRect(x: 0, y: 0, width: 1024, height: 1024)
        
        guard let bitmapRep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            print("Failed to create bitmap representation")
            exit(1)
        }
        
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmapRep)
        
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            print("Failed to generate PNG data")
            exit(1)
        }
        
        let url = URL(fileURLWithPath: path)
        do {
            try pngData.write(to: url)
            print("Wrote \(path)")
        } catch {
            print("Failed to write \(path): \(error)")
            exit(1)
        }
    }
}

func filename(for variant: String) -> String {
    switch variant {
    case "dark": return "icon-dark-1024.png"
    case "tinted": return "icon-tinted-1024.png"
    default: return "icon-1024.png"
    }
}

@MainActor
func run() {
    let variantsToRender = variant != nil ? [variant!] : ["light", "dark", "tinted"]
    
    for v in variantsToRender {
        let path = outDir + "/" + filename(for: v)
        render(variant: v, to: path)
    }
}

Task { @MainActor in
    run()
    exit(0)
}
dispatchMain()
