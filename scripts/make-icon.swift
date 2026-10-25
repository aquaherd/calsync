#!/usr/bin/env swift
// Renders the 1024×1024 opaque App Store icon.
// Usage: swift scripts/make-icon.swift CalSync/Assets.xcassets/AppIcon.appiconset/AppIcon.png
import AppKit

let size = 1024
let output = CommandLine.arguments.dropFirst().first ?? "AppIcon.png"

let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
    space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
)!

let gradient = CGGradient(colorsSpace: colorSpace, colors: [
    CGColor(red: 0.00, green: 0.48, blue: 0.85, alpha: 1),
    CGColor(red: 0.20, green: 0.78, blue: 0.75, alpha: 1),
] as CFArray, locations: [0, 1])!
context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: CGFloat(size)), end: CGPoint(x: CGFloat(size), y: 0), options: [])

NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)

func drawSymbol(_ name: String, pointSize: CGFloat, center: CGPoint, alpha: CGFloat) {
    let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        .applying(.init(paletteColors: [NSColor.white.withAlphaComponent(alpha)]))
    guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(config) else { fatalError("Missing symbol \(name)") }
    let rect = NSRect(x: center.x - image.size.width / 2, y: center.y - image.size.height / 2,
                      width: image.size.width, height: image.size.height)
    image.draw(in: rect)
}

drawSymbol("calendar", pointSize: 300, center: CGPoint(x: 360, y: 640), alpha: 0.55)
drawSymbol("calendar", pointSize: 300, center: CGPoint(x: 664, y: 384), alpha: 1)
drawSymbol("arrow.down.right", pointSize: 150, center: CGPoint(x: 680, y: 700), alpha: 1)

let image = context.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
print("Wrote \(output)")
