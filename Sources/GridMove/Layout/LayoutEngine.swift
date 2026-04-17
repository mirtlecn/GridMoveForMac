import AppKit
import Foundation

struct ResolvedTriggerSlot: Equatable {
    let layoutID: String
    let triggerFrame: CGRect
    let targetFrame: CGRect
}

final class LayoutEngine {
    private enum CacheLimit {
        static let recentWindowCount = 10
    }

    private var windowLayoutIDs: [String: String] = [:]
    private var recentWindowIdentities: [String] = []

    func frame(for preset: LayoutPreset, on screen: NSScreen) -> CGRect {
        frame(for: preset, in: screen.visibleFrame)
    }

    func frame(for preset: LayoutPreset, in usableFrame: CGRect) -> CGRect {
        frame(
            for: preset.windowSelection,
            columns: preset.gridColumns,
            rows: preset.gridRows,
            in: usableFrame
        )
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

    func resolveTriggerSlots(on screen: NSScreen, configuration: AppConfiguration) -> [ResolvedTriggerSlot] {
        resolveTriggerSlots(
            screenFrame: screen.frame,
            usableFrame: screen.visibleFrame,
            configuration: configuration
        )
    }

    func resolveTriggerSlots(in usableFrame: CGRect, configuration: AppConfiguration) -> [ResolvedTriggerSlot] {
        resolveTriggerSlots(screenFrame: usableFrame, usableFrame: usableFrame, configuration: configuration)
    }

    func resolveTriggerSlots(
        screenFrame: CGRect,
        usableFrame: CGRect,
        configuration: AppConfiguration
    ) -> [ResolvedTriggerSlot] {
        configuration.layouts.map { preset in
            let triggerFrame = triggerFrame(
                for: preset,
                screenFrame: screenFrame,
                usableFrame: usableFrame,
                gap: configuration.appearance.triggerGap
            )

            return ResolvedTriggerSlot(
                layoutID: preset.id,
                triggerFrame: triggerFrame,
                targetFrame: frame(for: preset, in: usableFrame)
            )
        }
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
                if layouts[nextIndex].includeInCycle {
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
        slots.first { $0.triggerFrame.contains(point) }
    }

    func layoutPreset(for layoutID: String, in configuration: AppConfiguration) -> LayoutPreset? {
        configuration.layouts.first(where: { $0.id == layoutID })
    }

    private func cycleEligibleLayouts(from layouts: [LayoutPreset]) -> [LayoutPreset] {
        layouts.filter(\.includeInCycle)
    }

    private func trimRecordedLayoutIDsIfNeeded() {
        while recentWindowIdentities.count > CacheLimit.recentWindowCount {
            let removedIdentity = recentWindowIdentities.removeFirst()
            windowLayoutIDs[removedIdentity] = nil
        }
    }

    private func triggerFrame(
        for preset: LayoutPreset,
        screenFrame: CGRect,
        usableFrame: CGRect,
        gap: Double
    ) -> CGRect {
        switch preset.triggerRegion {
        case let .screen(selection):
            return frame(
                for: selection,
                columns: preset.gridColumns,
                rows: preset.gridRows,
                in: usableFrame
            )
            .insetBy(dx: gap, dy: gap)
            .integral
        case let .menuBar(selection):
            return menuBarFrame(
                for: selection,
                segments: preset.gridRows,
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
