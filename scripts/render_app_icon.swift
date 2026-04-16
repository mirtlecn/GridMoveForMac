#!/usr/bin/swift

import AppKit
import Foundation

enum AppIconRenderer {
    static let canvasSizes: [Int] = [16, 32, 128, 256, 512]
    static let backgroundColor = NSColor(
        calibratedRed: 0.06,
        green: 0.49,
        blue: 0.88,
        alpha: 1.0
    )
    static let glyphColor = NSColor.white

    static func main() throws {
        let arguments = CommandLine.arguments
        guard arguments.count == 2 else {
            fputs("usage: render_app_icon.swift <iconset-directory>\n", stderr)
            exit(EXIT_FAILURE)
        }

        let outputDirectoryURL = URL(fileURLWithPath: arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(
            at: outputDirectoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        for baseSize in canvasSizes {
            try writeImage(to: outputDirectoryURL, pixelSize: baseSize, scale: 1)
            try writeImage(to: outputDirectoryURL, pixelSize: baseSize, scale: 2)
        }
    }

    private static func writeImage(to directoryURL: URL, pixelSize: Int, scale: Int) throws {
        let totalPixels = pixelSize * scale
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: totalPixels,
            pixelsHigh: totalPixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )

        guard let bitmap else {
            throw RendererError.failedToCreateBitmap
        }

        bitmap.size = NSSize(width: pixelSize, height: pixelSize)

        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw RendererError.failedToCreateGraphicsContext
        }
        NSGraphicsContext.current = context

        let edge = CGFloat(pixelSize)
        let rect = CGRect(origin: .zero, size: CGSize(width: edge, height: edge))
        drawBackground(in: rect)
        let inset = edge * 0.14
        drawGlyph(in: rect.insetBy(dx: inset, dy: inset))

        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()

        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw RendererError.failedToEncodePNG
        }

        let fileURL = directoryURL.appendingPathComponent(fileName(for: pixelSize, scale: scale))
        try data.write(to: fileURL)
    }

    private static func drawBackground(in rect: CGRect) {
        let radius = rect.width * 0.22
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        backgroundColor.setFill()
        path.fill()
    }

    private static func drawGlyph(in rect: CGRect) {
        let unit = min(rect.width, rect.height) / 16.0
        glyphColor.setFill()

        let cells = [
            CGRect(x: 1, y: 11, width: 6, height: 4),
            CGRect(x: 1, y: 1, width: 6, height: 8),
            CGRect(x: 9, y: 7, width: 6, height: 8),
            CGRect(x: 9, y: 1, width: 6, height: 4),
        ]

        for cell in cells {
            let path = NSBezierPath(
                roundedRect: CGRect(
                    x: rect.minX + cell.minX * unit,
                    y: rect.minY + cell.minY * unit,
                    width: cell.width * unit,
                    height: cell.height * unit
                ),
                xRadius: unit,
                yRadius: unit
            )
            path.fill()
        }
    }

    private static func fileName(for pixelSize: Int, scale: Int) -> String {
        let scaledSuffix = scale == 2 ? "@2x" : ""
        return "icon_\(pixelSize)x\(pixelSize)\(scaledSuffix).png"
    }

    enum RendererError: Error {
        case failedToCreateBitmap
        case failedToCreateGraphicsContext
        case failedToEncodePNG
    }
}

do {
    try AppIconRenderer.main()
} catch {
    fputs("failed to render app icon: \(error)\n", stderr)
    exit(EXIT_FAILURE)
}
