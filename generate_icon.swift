#!/usr/bin/swift

import AppKit
import Foundation

// Generate NeuroShell app icon from brain.head.profile SF Symbol
// with purple -> blue -> cyan gradient, matching the sidebar branding

let sizes: [(name: String, pixelSize: Int, logicalSize: Int, scale: Int)] = [
    ("icon_16x16", 16, 16, 1),
    ("icon_16x16@2x", 32, 16, 2),
    ("icon_32x32", 32, 32, 1),
    ("icon_32x32@2x", 64, 32, 2),
    ("icon_128x128", 128, 128, 1),
    ("icon_128x128@2x", 256, 128, 2),
    ("icon_256x256", 256, 256, 1),
    ("icon_256x256@2x", 512, 256, 2),
    ("icon_512x512", 512, 512, 1),
    ("icon_512x512@2x", 1024, 512, 2),
]

func generateIcon(pixelSize: Int) -> Data? {
    let size = pixelSize

    // Create a bitmap image rep with exact pixel dimensions at 72 DPI (1x scale)
    guard let bitmapRep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        return nil
    }

    // Set the size in points to match pixels (72 DPI = 1:1 mapping)
    bitmapRep.size = NSSize(width: size, height: size)

    let context = NSGraphicsContext(bitmapImageRep: bitmapRep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.shouldAntialias = true
    context.imageInterpolation = .high

    let cgContext = context.cgContext
    let s = CGFloat(size)

    // Background: rounded rectangle with dark gradient
    let rect = CGRect(x: 0, y: 0, width: s, height: s)
    let cornerRadius = s * 0.22
    let bgPath = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    // Dark background gradient (dark purple-black to dark blue-black)
    let bgColors: [CGColor] = [
        NSColor(red: 0.08, green: 0.04, blue: 0.16, alpha: 1.0).cgColor,
        NSColor(red: 0.04, green: 0.06, blue: 0.18, alpha: 1.0).cgColor,
        NSColor(red: 0.02, green: 0.08, blue: 0.14, alpha: 1.0).cgColor,
    ]
    let bgGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                 colors: bgColors as CFArray,
                                 locations: [0.0, 0.5, 1.0])!

    cgContext.saveGState()
    cgContext.addPath(bgPath)
    cgContext.clip()
    cgContext.drawLinearGradient(bgGradient,
                                 start: CGPoint(x: 0, y: s),
                                 end: CGPoint(x: s, y: 0),
                                 options: [])

    // Subtle inner glow
    let glowCenter = CGPoint(x: s * 0.5, y: s * 0.55)
    let glowColors: [CGColor] = [
        NSColor(red: 0.4, green: 0.2, blue: 0.8, alpha: 0.15).cgColor,
        NSColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 0.05).cgColor,
        NSColor.clear.cgColor,
    ]
    let glowGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                   colors: glowColors as CFArray,
                                   locations: [0.0, 0.5, 1.0])!
    cgContext.drawRadialGradient(glowGradient,
                                  startCenter: glowCenter, startRadius: 0,
                                  endCenter: glowCenter, endRadius: s * 0.6,
                                  options: [])
    cgContext.restoreGState()

    // Border with gradient
    cgContext.saveGState()
    let borderRect = rect.insetBy(dx: 0.5, dy: 0.5)
    let borderPath = CGPath(roundedRect: borderRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    cgContext.addPath(borderPath)
    cgContext.setLineWidth(max(1.0, s / 128.0))
    let borderColor = NSColor(red: 0.4, green: 0.3, blue: 0.7, alpha: 0.4)
    cgContext.setStrokeColor(borderColor.cgColor)
    cgContext.strokePath()
    cgContext.restoreGState()

    // Draw the brain.head.profile SF Symbol
    let symbolPointSize = s * 0.48
    let symbolConfig = NSImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .medium)
    if let symbolImage = NSImage(systemSymbolName: "brain.head.profile", accessibilityDescription: nil)?.withSymbolConfiguration(symbolConfig) {
        let symbolSize = symbolImage.size
        let symbolX = (s - symbolSize.width) / 2.0
        let symbolY = (s - symbolSize.height) / 2.0 - s * 0.02
        let symbolRect = NSRect(x: symbolX, y: symbolY, width: symbolSize.width, height: symbolSize.height)

        let fullRect = NSRect(x: 0, y: 0, width: s, height: s)

        // Render symbol as mask into a temporary bitmap
        guard let tempRep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else {
            NSGraphicsContext.restoreGraphicsState()
            return bitmapRep.representation(using: .png, properties: [:])
        }
        tempRep.size = NSSize(width: size, height: size)

        let tempCtx = NSGraphicsContext(bitmapImageRep: tempRep)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = tempCtx
        symbolImage.draw(in: symbolRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        NSGraphicsContext.restoreGraphicsState()

        // Create gradient bitmap
        guard let gradRep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else {
            NSGraphicsContext.restoreGraphicsState()
            return bitmapRep.representation(using: .png, properties: [:])
        }
        gradRep.size = NSSize(width: size, height: size)

        let gradCtx = NSGraphicsContext(bitmapImageRep: gradRep)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = gradCtx

        let gCgCtx = gradCtx.cgContext
        let gradColors: [CGColor] = [
            NSColor(red: 0.7, green: 0.3, blue: 1.0, alpha: 1.0).cgColor,   // purple
            NSColor(red: 0.4, green: 0.5, blue: 1.0, alpha: 1.0).cgColor,   // blue
            NSColor(red: 0.0, green: 0.85, blue: 0.95, alpha: 1.0).cgColor, // cyan
        ]
        let symGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: gradColors as CFArray,
                                      locations: [0.0, 0.5, 1.0])!
        gCgCtx.drawLinearGradient(symGradient,
                                   start: CGPoint(x: 0, y: s),
                                   end: CGPoint(x: s, y: 0),
                                   options: [])

        // Mask the gradient with the symbol shape
        let tempImage = NSImage(size: NSSize(width: size, height: size))
        tempImage.addRepresentation(tempRep)
        tempImage.draw(in: fullRect, from: .zero, operation: .destinationIn, fraction: 1.0)

        NSGraphicsContext.restoreGraphicsState()

        // Now draw the masked gradient symbol onto the main context
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context

        let gradImage = NSImage(size: NSSize(width: size, height: size))
        gradImage.addRepresentation(gradRep)
        gradImage.draw(in: fullRect, from: .zero, operation: .sourceOver, fraction: 1.0)

        NSGraphicsContext.restoreGraphicsState()

        // Restore main context for final operations
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        NSGraphicsContext.restoreGraphicsState()
    } else {
        // Fallback: draw a simple circle if SF Symbol not available
        let centerX = s / 2.0
        let centerY = s / 2.0
        let r = s * 0.25

        cgContext.saveGState()
        let fallbackColors: [CGColor] = [
            NSColor(red: 0.7, green: 0.3, blue: 1.0, alpha: 1.0).cgColor,
            NSColor(red: 0.0, green: 0.85, blue: 0.95, alpha: 1.0).cgColor,
        ]
        let fbGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: fallbackColors as CFArray,
                                     locations: [0.0, 1.0])!

        cgContext.addEllipse(in: CGRect(x: centerX - r, y: centerY - r, width: r * 2, height: r * 2))
        cgContext.clip()
        cgContext.drawLinearGradient(fbGradient,
                                      start: CGPoint(x: centerX - r, y: centerY + r),
                                      end: CGPoint(x: centerX + r, y: centerY - r),
                                      options: [])
        cgContext.restoreGState()
    }

    NSGraphicsContext.restoreGraphicsState()

    return bitmapRep.representation(using: .png, properties: [:])
}

// Get the script's directory to find the asset catalog
let scriptPath = CommandLine.arguments[0]
let scriptURL = URL(fileURLWithPath: scriptPath)
let projectDir = scriptURL.deletingLastPathComponent()
let iconsetDir = projectDir.appendingPathComponent("Assets.xcassets/AppIcon.appiconset")

// Create iconset directory if needed
try? FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

print("Generating NeuroShell app icons...")
print("Output directory: \(iconsetDir.path)")

var contentsImages: [[String: String]] = []

for sizeSpec in sizes {
    guard let pngData = generateIcon(pixelSize: sizeSpec.pixelSize) else {
        print("  ERROR: Failed to generate \(sizeSpec.name).png")
        continue
    }

    let filename = "\(sizeSpec.name).png"
    let fileURL = iconsetDir.appendingPathComponent(filename)
    try pngData.write(to: fileURL)
    print("  Generated \(filename) (\(sizeSpec.pixelSize)x\(sizeSpec.pixelSize) px)")

    let scaleStr = "\(sizeSpec.scale)x"

    contentsImages.append([
        "filename": filename,
        "idiom": "mac",
        "scale": scaleStr,
        "size": "\(sizeSpec.logicalSize)x\(sizeSpec.logicalSize)",
    ])
}

// Write Contents.json
let contentsJSON: [String: Any] = [
    "images": contentsImages,
    "info": [
        "author": "xcode",
        "version": 1,
    ] as [String: Any],
]

let jsonData = try JSONSerialization.data(withJSONObject: contentsJSON, options: [.prettyPrinted, .sortedKeys])
let contentsURL = iconsetDir.appendingPathComponent("Contents.json")
try jsonData.write(to: contentsURL)

print("\nContents.json updated.")
print("Done! All icon sizes generated successfully.")