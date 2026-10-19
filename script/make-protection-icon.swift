#!/usr/bin/swift
import AppKit
import Foundation

// Code-native monochrome artwork; keep the main OP icon unchanged.
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for size in [16, 32, 64, 128, 256, 512, 1024] {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    NSColor.white.setFill()
    NSBezierPath(roundedRect: NSRect(x: 32, y: 32, width: 960, height: 960), xRadius: 210, yRadius: 210).fill()
    NSColor(calibratedWhite: 0.05, alpha: 1).setStroke()
    // Two opposing repeat arrows, with rounded stems and a generous white center.
    for lower in [false, true] {
        context.saveGState()
        if lower { context.translateBy(x: 1024, y: 1024); context.rotate(by: .pi) }
        let path = NSBezierPath()
        path.lineWidth = 68; path.lineCapStyle = .round; path.lineJoinStyle = .round
        path.move(to: NSPoint(x: 250, y: 466))
        path.line(to: NSPoint(x: 250, y: 560))
        path.curve(to: NSPoint(x: 360, y: 670), controlPoint1: NSPoint(x: 250, y: 627), controlPoint2: NSPoint(x: 293, y: 670))
        path.line(to: NSPoint(x: 756, y: 670))
        path.stroke()
        let head = NSBezierPath()
        head.lineWidth = 68; head.lineCapStyle = .round; head.lineJoinStyle = .round
        head.move(to: NSPoint(x: 670, y: 756)); head.line(to: NSPoint(x: 756, y: 670)); head.line(to: NSPoint(x: 670, y: 584)); head.stroke()
        context.restoreGState()
    }
    NSGraphicsContext.restoreGraphicsState()
    let png = rep.representation(using: .png, properties: [:])!
    for base in [16, 32, 128, 256, 512] {
        if size == base { try png.write(to: output.appendingPathComponent("icon_\(base)x\(base).png")) }
        if size == base * 2 { try png.write(to: output.appendingPathComponent("icon_\(base)x\(base)@2x.png")) }
    }
}
