import AppKit

struct SettingsPreviewGeometry {
    let screenFrame: CGRect
    let usableFrame: CGRect
    let screenRect: CGRect
    let menuBarRect: CGRect
    let sourceMenuBarFrame: CGRect
    let usableRect: CGRect
}

enum SettingsPreviewSupport {
    static let referenceScreenFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
    static let referenceUsableFrame = CGRect(x: 0, y: 0, width: 1440, height: 872)
    static let defaultPreviewColumns = 12
    static let defaultPreviewRows = 6
    private static let detachedMenuBarGap: CGFloat = 6
    private static let detachedMenuBarHeight: CGFloat = 10
    private static let displayFillColor = NSColor(calibratedRed: 0.17, green: 0.20, blue: 0.25, alpha: 1)
    private static let displayStrokeColor = NSColor.white.withAlphaComponent(0.22)
    private static let menuBarFillColor = NSColor(calibratedRed: 0.24, green: 0.28, blue: 0.34, alpha: 1)
    private static let menuBarStrokeColor = NSColor.white.withAlphaComponent(0.18)
    private static let menuBarPlaceholderColor = NSColor.white.withAlphaComponent(0.42)

    static func makeGeometry(in bounds: CGRect) -> SettingsPreviewGeometry {
        let previewRect = bounds.insetBy(dx: 8, dy: 8)
        let sourceMenuBarFrame = CGRect(
            x: referenceScreenFrame.minX,
            y: referenceUsableFrame.maxY,
            width: referenceScreenFrame.width,
            height: referenceScreenFrame.maxY - referenceUsableFrame.maxY
        )

        let availableHeight = previewRect.height - detachedMenuBarHeight - detachedMenuBarGap
        let scale = min(previewRect.width / referenceUsableFrame.width, availableHeight / referenceUsableFrame.height)
        let bodyWidth = referenceUsableFrame.width * scale
        let bodyHeight = referenceUsableFrame.height * scale
        let screenRect = CGRect(
            x: previewRect.midX - (bodyWidth / 2),
            y: previewRect.maxY - bodyHeight,
            width: bodyWidth,
            height: bodyHeight
        ).integral

        let menuBarRect = CGRect(
            x: screenRect.minX,
            y: screenRect.minY - detachedMenuBarGap - detachedMenuBarHeight,
            width: screenRect.width,
            height: detachedMenuBarHeight
        ).integral

        return SettingsPreviewGeometry(
            screenFrame: referenceScreenFrame,
            usableFrame: referenceUsableFrame,
            screenRect: screenRect,
            menuBarRect: menuBarRect,
            sourceMenuBarFrame: sourceMenuBarFrame,
            usableRect: screenRect
        )
    }

    static func drawDisplayChrome(in geometry: SettingsPreviewGeometry) {
        let outerPath = NSBezierPath(roundedRect: geometry.screenRect, xRadius: 14, yRadius: 14)
        displayFillColor.setFill()
        outerPath.fill()
        displayStrokeColor.setStroke()
        outerPath.lineWidth = 1
        outerPath.stroke()

        let menuBarPath = NSBezierPath(
            roundedRect: geometry.menuBarRect,
            xRadius: geometry.menuBarRect.height / 2,
            yRadius: geometry.menuBarRect.height / 2
        )
        menuBarFillColor.setFill()
        menuBarPath.fill()
        menuBarStrokeColor.setStroke()
        menuBarPath.lineWidth = 1
        menuBarPath.stroke()

        drawMenuBarPlaceholders(in: geometry.menuBarRect)
    }

    static func drawGrid(columns: Int, rows: Int, in rect: CGRect) {
        guard columns > 1 || rows > 1 else {
            return
        }

        let path = NSBezierPath()
        for column in 1..<columns {
            let x = rect.minX + rect.width * CGFloat(column) / CGFloat(columns)
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.line(to: CGPoint(x: x, y: rect.maxY))
        }

        for row in 1..<rows {
            let y = rect.minY + rect.height * CGFloat(row) / CGFloat(rows)
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.line(to: CGPoint(x: rect.maxX, y: y))
        }

        path.lineWidth = 1
        NSColor(calibratedWhite: 1, alpha: 0.08).setStroke()
        path.stroke()
    }

    static func drawMenuBarSegments(segments: Int, in rect: CGRect) {
        guard segments > 1 else {
            return
        }

        let path = NSBezierPath()
        for segment in 1..<segments {
            let x = rect.minX + rect.width * CGFloat(segment) / CGFloat(segments)
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.line(to: CGPoint(x: x, y: rect.maxY))
        }

        path.lineWidth = 1
        NSColor.white.withAlphaComponent(0.14).setStroke()
        path.stroke()
    }

    static func localRect(from globalRect: CGRect, in geometry: SettingsPreviewGeometry) -> CGRect {
        if globalRect.minY >= geometry.usableFrame.maxY {
            return localRect(
                from: globalRect,
                sourceRect: geometry.sourceMenuBarFrame,
                destinationRect: geometry.menuBarRect
            )
        }

        return localRect(
            from: globalRect,
            sourceRect: geometry.usableFrame,
            destinationRect: geometry.usableRect
        )
    }

    static func frame(for selection: GridSelection, columns: Int, rows: Int, in rect: CGRect) -> CGRect {
        let cellWidth = rect.width / CGFloat(columns)
        let cellHeight = rect.height / CGFloat(rows)
        return CGRect(
            x: rect.minX + CGFloat(selection.x) * cellWidth,
            y: rect.minY + CGFloat(selection.y) * cellHeight,
            width: CGFloat(selection.w) * cellWidth,
            height: CGFloat(selection.h) * cellHeight
        )
    }

    static func frame(for selection: MenuBarSelection, segments: Int, in rect: CGRect) -> CGRect {
        let cellWidth = rect.width / CGFloat(max(segments, 1))
        return CGRect(
            x: rect.minX + CGFloat(selection.x) * cellWidth,
            y: rect.minY,
            width: CGFloat(selection.w) * cellWidth,
            height: rect.height
        )
    }

    private static func localRect(from globalRect: CGRect, sourceRect: CGRect, destinationRect: CGRect) -> CGRect {
        let scaleX = destinationRect.width / sourceRect.width
        let scaleY = destinationRect.height / sourceRect.height
        return CGRect(
            x: destinationRect.minX + (globalRect.minX - sourceRect.minX) * scaleX,
            y: destinationRect.minY + (sourceRect.maxY - globalRect.maxY) * scaleY,
            width: globalRect.width * scaleX,
            height: globalRect.height * scaleY
        ).integral
    }

    private static func drawMenuBarPlaceholders(in rect: CGRect) {
        let placeholderHeight = max(3, rect.height - 4)
        let itemCornerRadius = placeholderHeight / 2

        var leftX = rect.minX + 8
        let leftWidths: [CGFloat] = [10, 30, 24, 28]
        for width in leftWidths {
            let itemRect = CGRect(
                x: leftX,
                y: rect.midY - (placeholderHeight / 2),
                width: width,
                height: placeholderHeight
            )
            let itemPath = NSBezierPath(roundedRect: itemRect, xRadius: itemCornerRadius, yRadius: itemCornerRadius)
            menuBarPlaceholderColor.setFill()
            itemPath.fill()
            leftX += width + 6
        }

        var rightX = rect.maxX - 8
        let rightWidths: [CGFloat] = [14, 10, 10]
        for width in rightWidths {
            rightX -= width
            let itemRect = CGRect(
                x: rightX,
                y: rect.midY - (placeholderHeight / 2),
                width: width,
                height: placeholderHeight
            )
            let itemPath = NSBezierPath(roundedRect: itemRect, xRadius: itemCornerRadius, yRadius: itemCornerRadius)
            menuBarPlaceholderColor.setFill()
            itemPath.fill()
            rightX -= 6
        }
    }
}
