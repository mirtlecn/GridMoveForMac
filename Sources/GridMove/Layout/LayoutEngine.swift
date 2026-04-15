import AppKit
import Foundation

struct ResolvedTriggerSlot: Equatable {
    let layoutID: String
    let triggerFrame: CGRect
    let targetFrame: CGRect
}

final class LayoutEngine {
    private var windowLayoutIDs: [String: String] = [:]

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
        resolveTriggerSlots(in: screen.visibleFrame, configuration: configuration)
    }

    func resolveTriggerSlots(in usableFrame: CGRect, configuration: AppConfiguration) -> [ResolvedTriggerSlot] {
        configuration.layouts.map { preset in
            let triggerFrame = frame(
                for: preset.triggerSelection,
                columns: preset.gridColumns,
                rows: preset.gridRows,
                in: usableFrame
            ).insetBy(dx: configuration.appearance.triggerGap, dy: configuration.appearance.triggerGap).integral

            return ResolvedTriggerSlot(
                layoutID: preset.id,
                triggerFrame: triggerFrame,
                targetFrame: frame(for: preset, in: usableFrame)
            )
        }
    }

    func recordLayoutID(_ layoutID: String, for windowIdentity: String) {
        windowLayoutIDs[windowIdentity] = layoutID
    }

    func removeWindow(identity: String) {
        windowLayoutIDs[identity] = nil
    }

    func currentLayoutID(for windowIdentity: String, layouts: [LayoutPreset]) -> String {
        if let layoutID = windowLayoutIDs[windowIdentity], layouts.contains(where: { $0.id == layoutID }) {
            return layoutID
        }
        return layouts.first?.id ?? ""
    }

    func nextLayoutID(for windowIdentity: String, layouts: [LayoutPreset]) -> String? {
        cycleLayoutID(for: windowIdentity, layouts: layouts, direction: 1)
    }

    func previousLayoutID(for windowIdentity: String, layouts: [LayoutPreset]) -> String? {
        cycleLayoutID(for: windowIdentity, layouts: layouts, direction: -1)
    }

    func cycleLayoutID(for windowIdentity: String, layouts: [LayoutPreset], direction: Int) -> String? {
        guard !layouts.isEmpty else {
            return nil
        }

        let currentLayoutID = currentLayoutID(for: windowIdentity, layouts: layouts)
        let currentIndex = layouts.firstIndex(where: { $0.id == currentLayoutID }) ?? 0
        let nextIndex = (currentIndex + direction + layouts.count) % layouts.count
        return layouts[nextIndex].id
    }

    func triggerSlot(containing point: CGPoint, slots: [ResolvedTriggerSlot]) -> ResolvedTriggerSlot? {
        slots.first { $0.triggerFrame.contains(point) }
    }

    func layoutPreset(for layoutID: String, in configuration: AppConfiguration) -> LayoutPreset? {
        configuration.layouts.first(where: { $0.id == layoutID })
    }
}
