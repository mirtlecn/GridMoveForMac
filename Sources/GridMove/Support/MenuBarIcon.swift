import AppKit

enum MenuBarIcon {
    static func makeImage() -> NSImage {
        let edge = max(16, NSStatusBar.system.thickness - 6)
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            drawIcon(in: rect)
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func drawIcon(in rect: CGRect) {
        let unit = min(rect.width, rect.height) / 16.0
        NSColor.black.setFill()

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
}
