import Foundation
import Testing
@testable import GridMove

private func makeTestLayout(
    id: String,
    name: String,
    includeInLayoutIndex: Bool = true
) -> LayoutPreset {
    LayoutPreset(
        id: id,
        name: name,
        gridColumns: 12,
        gridRows: 6,
        windowSelection: GridSelection(x: 0, y: 0, w: 6, h: 6),
        triggerRegion: nil,
        includeInLayoutIndex: includeInLayoutIndex
    )
}

@Test func hotkeyPrototypeSlotsUseMaximumIndexedLayoutCountAcrossGroupsAndActiveGroupTargets() async throws {
    var configuration = AppConfiguration.defaultValue
    configuration.layoutGroups = [
        LayoutGroup(
            name: "built-in",
            includeInGroupCycle: true,
            sets: [
                LayoutSet(
                    monitor: .main,
                    layouts: [
                        makeTestLayout(id: "layout-a", name: "Alpha"),
                        makeTestLayout(id: "layout-b", name: ""),
                    ]
                )
            ]
        ),
        LayoutGroup(
            name: "work",
            includeInGroupCycle: true,
            sets: [
                LayoutSet(
                    monitor: .main,
                    layouts: [
                        makeTestLayout(id: "layout-c", name: "One"),
                        makeTestLayout(id: "layout-d", name: "Two"),
                        makeTestLayout(id: "layout-e", name: "Three"),
                        makeTestLayout(id: "layout-f", name: "Four"),
                    ]
                )
            ]
        ),
    ]
    configuration.general.activeLayoutGroup = "built-in"

    let slots = HotkeyPrototypeSlot.makePrototypeSlots(configuration: configuration)
    let layoutSlots = slots.filter {
        if case .applyLayoutByIndex = $0.action {
            return true
        }
        return false
    }

    #expect(layoutSlots.count == 4)
    #expect(layoutSlots[0].title == UICopy.settingsApplyLayoutSlotTitle(1))
    #expect(layoutSlots[0].currentTarget == "Alpha")
    #expect(layoutSlots[1].title == UICopy.settingsApplyLayoutSlotTitle(2))
    #expect(layoutSlots[1].currentTarget == UICopy.settingsApplyLayoutSlotTitle(2))
    #expect(layoutSlots[2].title == UICopy.settingsApplyLayoutSlotTitle(3))
    #expect(layoutSlots[2].currentTarget == UICopy.settingsApplyLayoutSlotTitle(3))
}

@Test func appearanceConfigurationDecodesIntegerGapAndStrokeButKeepsOpacityAsDouble() async throws {
    let json = """
    {
      "renderTriggerAreas": false,
      "triggerOpacity": 20,
      "triggerGap": 2,
      "triggerStrokeColor": "#007AFF33",
      "layoutGap": 1,
      "renderWindowHighlight": true,
      "highlightFillOpacity": 8,
      "highlightStrokeWidth": 3,
      "highlightStrokeColor": "#FFFFFFEB"
    }
    """

    let data = try #require(json.data(using: .utf8))
    let settings = try JSONDecoder().decode(AppearanceConfiguration.self, from: data)

    #expect(settings.triggerOpacity == 0.2)
    #expect(settings.triggerGap == 2)
    #expect(settings.highlightFillOpacity == 0.08)
    #expect(settings.highlightStrokeWidth == 3)
}
