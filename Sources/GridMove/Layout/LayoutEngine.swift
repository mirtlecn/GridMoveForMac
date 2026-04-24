import AppKit
import Foundation

struct ResolvedTriggerSlot: Equatable {
    let layoutID: String
    let triggerFrame: CGRect
    let hitTestFrames: [CGRect]
    let targetFrame: CGRect
}

final class LayoutEngine {
    private enum CacheLimit {
        static let recentWindowCount = 10
    }

    private var windowLayoutIDs: [String: String] = [:]
    private var recentWindowIdentities: [String] = []

    func frame(for preset: LayoutPreset, on screen: NSScreen, layoutGap: Int = 0) -> CGRect? {
        frame(for: preset, in: screen.visibleFrame, layoutGap: layoutGap)
    }

    func frame(for preset: LayoutPreset, in usableFrame: CGRect, layoutGap: Int = 0) -> CGRect? {
        insetLayoutFrame(
            frame(
                for: preset.windowSelection,
                columns: preset.gridColumns,
                rows: preset.gridRows,
                in: usableFrame
            ),
            layoutGap: layoutGap
        )
    }

    private func insetLayoutFrame(_ frame: CGRect, layoutGap: Int) -> CGRect? {
        let insetFrame = frame.insetBy(dx: CGFloat(layoutGap), dy: CGFloat(layoutGap))
        guard !insetFrame.isNull, !insetFrame.isEmpty, insetFrame.width > 0, insetFrame.height > 0 else {
            return nil
        }

        let integralFrame = insetFrame.integral
        guard !integralFrame.isNull, !integralFrame.isEmpty, integralFrame.width > 0, integralFrame.height > 0 else {
            return nil
        }

        return integralFrame
    }

    func frame(
        for selection: GridSelection,
        columns: Int,
        rows: Int,
        in usableFrame: CGRect
    ) -> CGRect {
        CGRect(
            x: usableFrame.origin.x + usableFrame.width * CGFloat(selection.x) / CGFloat(columns),
            y: usableFrame.maxY - usableFrame.height * CGFloat(selection.y + selection.h) / CGFloat(rows),
            width: usableFrame.width * CGFloat(selection.w) / CGFloat(columns),
            height: usableFrame.height * CGFloat(selection.h) / CGFloat(rows)
        ).integral
    }

    func resolveTriggerSlots(on screen: NSScreen, layouts: [LayoutPreset], triggerGap: Double, layoutGap: Int = 0) -> [ResolvedTriggerSlot] {
        resolveTriggerSlots(
            screenFrame: screen.frame,
            usableFrame: screen.visibleFrame,
            layouts: layouts,
            triggerGap: triggerGap,
            layoutGap: layoutGap
        )
    }

    func resolveTriggerSlots(in usableFrame: CGRect, layouts: [LayoutPreset], triggerGap: Double, layoutGap: Int = 0) -> [ResolvedTriggerSlot] {
        resolveTriggerSlots(screenFrame: usableFrame, usableFrame: usableFrame, layouts: layouts, triggerGap: triggerGap, layoutGap: layoutGap)
    }

    func resolveTriggerSlots(
        screenFrame: CGRect,
        usableFrame: CGRect,
        layouts: [LayoutPreset],
        triggerGap: Double,
        layoutGap: Int = 0
    ) -> [ResolvedTriggerSlot] {
        let rawSlots: [ResolvedTriggerSlot] = layouts.flatMap { preset -> [ResolvedTriggerSlot] in
            guard let targetFrame = frame(for: preset, in: usableFrame, layoutGap: layoutGap) else {
                return []
            }
            return preset.triggerRegions.compactMap { region -> ResolvedTriggerSlot? in
                guard let triggerFrame = triggerFrame(
                    for: region,
                    columns: preset.gridColumns,
                    rows: preset.gridRows,
                    screenFrame: screenFrame,
                    usableFrame: usableFrame,
                    gap: triggerGap
                ) else {
                    return nil
                }
                return ResolvedTriggerSlot(
                    layoutID: preset.id,
                    triggerFrame: triggerFrame,
                    hitTestFrames: [triggerFrame],
                    targetFrame: targetFrame
                )
            }
        }
        return resolveOverlappingHitTestFrames(in: rawSlots)
    }

    func recordLayoutID(_ layoutID: String, for windowIdentity: String) {
        windowLayoutIDs[windowIdentity] = layoutID
        recentWindowIdentities.removeAll { $0 == windowIdentity }
        recentWindowIdentities.append(windowIdentity)
        trimRecordedLayoutIDsIfNeeded()
    }

    func removeWindow(identity: String) {
        windowLayoutIDs[identity] = nil
        recentWindowIdentities.removeAll { $0 == identity }
    }

    func resetRecordedLayoutIDs() {
        windowLayoutIDs.removeAll()
        recentWindowIdentities.removeAll()
    }

    func currentLayoutID(for windowIdentity: String, layouts: [LayoutPreset]) -> String {
        let cycleLayouts = cycleEligibleLayouts(from: layouts)
        if let layoutID = windowLayoutIDs[windowIdentity], cycleLayouts.contains(where: { $0.id == layoutID }) {
            return layoutID
        }
        return cycleLayouts.first?.id ?? ""
    }

    func nextLayoutID(for windowIdentity: String, layouts: [LayoutPreset]) -> String? {
        cycleLayoutID(for: windowIdentity, layouts: layouts, direction: 1)
    }

    func previousLayoutID(for windowIdentity: String, layouts: [LayoutPreset]) -> String? {
        cycleLayoutID(for: windowIdentity, layouts: layouts, direction: -1)
    }

    func cycleLayoutID(for windowIdentity: String, layouts: [LayoutPreset], direction: Int) -> String? {
        let cycleLayouts = cycleEligibleLayouts(from: layouts)
        guard !cycleLayouts.isEmpty else {
            return nil
        }

        if let currentLayoutID = windowLayoutIDs[windowIdentity],
           let currentIndex = layouts.firstIndex(where: { $0.id == currentLayoutID }) {
            var nextIndex = currentIndex
            repeat {
                nextIndex = (nextIndex + direction + layouts.count) % layouts.count
                if layouts[nextIndex].includeInLayoutIndex {
                    return layouts[nextIndex].id
                }
            } while nextIndex != currentIndex
            return nil
        }

        if direction >= 0 {
            return cycleLayouts.first?.id
        }
        return cycleLayouts.last?.id
    }

    func triggerSlot(containing point: CGPoint, slots: [ResolvedTriggerSlot]) -> ResolvedTriggerSlot? {
        slots.last { slot in
            slot.hitTestFrames.contains { $0.contains(point) }
        }
    }

    func layoutPreset(for layoutID: String, in layouts: [LayoutPreset]) -> LayoutPreset? {
        layouts.first(where: { $0.id == layoutID })
    }

    private func cycleEligibleLayouts(from layouts: [LayoutPreset]) -> [LayoutPreset] {
        layouts.filter(\.includeInLayoutIndex)
    }

    private func resolveOverlappingHitTestFrames(in slots: [ResolvedTriggerSlot]) -> [ResolvedTriggerSlot] {
        slots.enumerated().map { index, slot in
            var hitTestFrames = [slot.triggerFrame]
            for laterSlot in slots.suffix(from: index + 1) {
                hitTestFrames = subtract(hitTestFrames, excluding: laterSlot.triggerFrame)
                if hitTestFrames.isEmpty {
                    break
                }
            }

            return ResolvedTriggerSlot(
                layoutID: slot.layoutID,
                triggerFrame: slot.triggerFrame,
                hitTestFrames: hitTestFrames,
                targetFrame: slot.targetFrame
            )
        }
    }

    private func subtract(_ frames: [CGRect], excluding excludedFrame: CGRect) -> [CGRect] {
        frames.flatMap { subtract($0, excluding: excludedFrame) }
    }

    private func subtract(_ frame: CGRect, excluding excludedFrame: CGRect) -> [CGRect] {
        guard frame.intersects(excludedFrame) else {
            return [frame]
        }

        let intersection = frame.intersection(excludedFrame)
        guard !intersection.isNull, !intersection.isEmpty else {
            return [frame]
        }

        if intersection.equalTo(frame) {
            return []
        }

        var remainingFrames: [CGRect] = []

        if intersection.maxY < frame.maxY {
            remainingFrames.append(
                CGRect(
                    x: frame.minX,
                    y: intersection.maxY,
                    width: frame.width,
                    height: frame.maxY - intersection.maxY
                )
            )
        }

        if intersection.minY > frame.minY {
            remainingFrames.append(
                CGRect(
                    x: frame.minX,
                    y: frame.minY,
                    width: frame.width,
                    height: intersection.minY - frame.minY
                )
            )
        }

        if intersection.minX > frame.minX {
            remainingFrames.append(
                CGRect(
                    x: frame.minX,
                    y: intersection.minY,
                    width: intersection.minX - frame.minX,
                    height: intersection.height
                )
            )
        }

        if intersection.maxX < frame.maxX {
            remainingFrames.append(
                CGRect(
                    x: intersection.maxX,
                    y: intersection.minY,
                    width: frame.maxX - intersection.maxX,
                    height: intersection.height
                )
            )
        }

        return remainingFrames.filter { !$0.isEmpty && !$0.isNull && $0.width > 0 && $0.height > 0 }
    }

    private func trimRecordedLayoutIDsIfNeeded() {
        while recentWindowIdentities.count > CacheLimit.recentWindowCount {
            let removedIdentity = recentWindowIdentities.removeFirst()
            windowLayoutIDs[removedIdentity] = nil
        }
    }

    private func triggerFrame(
        for region: TriggerRegion,
        columns: Int,
        rows: Int,
        screenFrame: CGRect,
        usableFrame: CGRect,
        gap: Double
    ) -> CGRect? {
        switch region {
        case let .screen(selection):
            return frame(
                for: selection,
                columns: columns,
                rows: rows,
                in: usableFrame
            )
            .insetBy(dx: gap, dy: gap)
            .integral
        case let .menuBar(selection):
            return menuBarFrame(
                for: selection,
                segments: rows,
                screenFrame: screenFrame,
                usableFrame: usableFrame,
                gap: gap
            )
        }
    }

    private func menuBarFrame(
        for selection: MenuBarSelection,
        segments: Int,
        screenFrame: CGRect,
        usableFrame: CGRect,
        gap: Double
    ) -> CGRect {
        let menuBarHeight = max(screenFrame.maxY - usableFrame.maxY, 24)
        let barFrame = CGRect(
            x: screenFrame.minX,
            y: screenFrame.maxY - menuBarHeight,
            width: screenFrame.width,
            height: menuBarHeight
        )
        let segmentWidth = barFrame.width / CGFloat(max(segments, 1))
        return CGRect(
            x: barFrame.minX + CGFloat(selection.x) * segmentWidth,
            y: barFrame.minY,
            width: CGFloat(selection.w) * segmentWidth,
            height: barFrame.height
        )
        .insetBy(dx: gap, dy: gap)
        .integral
    }
}
