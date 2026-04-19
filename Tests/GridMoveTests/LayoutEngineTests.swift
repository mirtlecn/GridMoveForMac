import Foundation
import Testing
@testable import GridMove

@Test func defaultLayoutsMatchAgreedSelections() async throws {
    let layouts = AppConfiguration.defaultValue.layouts

    #expect(layouts.count == 11)
    #expect(layouts.map(\.id) == (1 ... 11).map { "layout-\($0)" })
    #expect(layouts.map(\.name) == [
        "Left 1/3",
        "Left 1/2",
        "Left 2/3",
        "Center",
        "Right 2/3",
        "Right 1/2",
        "Right 1/3",
        "Right 1/3 top",
        "Right 1/3 bottom",
        "Full",
        "Full (menu bar)",
    ])
    #expect(layouts[0].windowSelection == GridSelection(x: 0, y: 0, w: 4, h: 6))
    #expect(layouts[0].triggerRegion == .screen(GridSelection(x: 0, y: 0, w: 1, h: 6)))
    #expect(layouts[3].windowSelection == GridSelection(x: 3, y: 1, w: 6, h: 4))
    #expect(layouts[3].triggerRegion == .screen(GridSelection(x: 5, y: 1, w: 2, h: 5)))
    #expect(layouts[7].windowSelection == GridSelection(x: 8, y: 0, w: 4, h: 3))
    #expect(layouts[7].triggerRegion == .screen(GridSelection(x: 11, y: 0, w: 1, h: 2)))
    #expect(layouts[9].windowSelection == GridSelection(x: 0, y: 0, w: 12, h: 6))
    #expect(layouts[9].triggerRegion == .screen(GridSelection(x: 5, y: 0, w: 2, h: 1)))
    #expect(layouts[10].windowSelection == GridSelection(x: 0, y: 0, w: 12, h: 6))
    #expect(layouts[10].triggerRegion == .menuBar(MenuBarSelection(x: 0, w: 6)))
    #expect(layouts[10].includeInLayoutIndex == false)
    #expect(layouts[10].includeInMenu == false)
}

@Test func layoutFrameUsesTopOriginCoordinates() async throws {
    let engine = LayoutEngine()
    let preset = AppConfiguration.defaultValue.layouts[7]
    let usableFrame = CGRect(x: 0, y: 0, width: 1200, height: 600)

    let frame = try #require(engine.frame(for: preset, in: usableFrame))

    #expect(frame.origin.x == 800)
    #expect(frame.origin.y == 300)
    #expect(frame.size.width == 400)
    #expect(frame.size.height == 300)
}

@Test func layoutFrameShrinksByConfiguredLayoutGap() async throws {
    let engine = LayoutEngine()
    let preset = AppConfiguration.defaultValue.layouts[1]
    let usableFrame = CGRect(x: 0, y: 0, width: 1200, height: 600)

    let frame = try #require(engine.frame(for: preset, in: usableFrame, layoutGap: 10))

    #expect(frame.origin.x == 10)
    #expect(frame.origin.y == 10)
    #expect(frame.size.width == 580)
    #expect(frame.size.height == 580)
}

@Test func coordinateConversionsRoundTripBetweenQuartzAndAppKit() async throws {
    let mainDisplayHeight: CGFloat = 900
    let appKitPoint = CGPoint(x: 320, y: 640)
    let appKitRect = CGRect(x: 800, y: 450, width: 400, height: 300)

    let quartzPoint = Geometry.quartzPoint(fromAppKitPoint: appKitPoint, mainDisplayHeight: mainDisplayHeight)
    let quartzRect = Geometry.quartzRect(fromAppKitRect: appKitRect, mainDisplayHeight: mainDisplayHeight)

    #expect(Geometry.appKitPoint(fromQuartzPoint: quartzPoint, mainDisplayHeight: mainDisplayHeight) == appKitPoint)
    #expect(Geometry.appKitRect(fromQuartzRect: quartzRect, mainDisplayHeight: mainDisplayHeight) == appKitRect)
    #expect(quartzRect.origin.y == 150)
}

@Test func triggerSlotsUseLayoutSpecificSelections() async throws {
    let engine = LayoutEngine()
    let configuration = AppConfiguration.defaultValue
    let screenFrame = CGRect(x: 0, y: 0, width: 1800, height: 930)
    let usableFrame = CGRect(x: 0, y: 0, width: 1800, height: 900)

    let slots = engine.resolveTriggerSlots(
        screenFrame: screenFrame,
        usableFrame: usableFrame,
        layouts: configuration.layouts,
        triggerGap: Double(configuration.appearance.triggerGap)
    )
    let firstSlot = try #require(slots.first(where: { $0.layoutID == "layout-1" }))
    let fullscreenSlot = try #require(slots.first(where: { $0.layoutID == "layout-10" }))
    let menuBarSlot = try #require(slots.first(where: { $0.layoutID == "layout-11" }))

    #expect(firstSlot.layoutID == "layout-1")
    #expect(firstSlot.triggerFrame.origin.x == 0)
    #expect(firstSlot.triggerFrame.origin.y == 0)
    #expect(firstSlot.triggerFrame.size.width == 150)
    #expect(firstSlot.triggerFrame.size.height == 900)

    #expect(fullscreenSlot.layoutID == "layout-10")
    #expect(fullscreenSlot.triggerFrame.origin.x == 750)
    #expect(fullscreenSlot.triggerFrame.origin.y == 750)
    #expect(fullscreenSlot.triggerFrame.size.width == 300)
    #expect(fullscreenSlot.triggerFrame.size.height == 150)

    #expect(menuBarSlot.triggerFrame.origin.x == 0)
    #expect(menuBarSlot.triggerFrame.origin.y == 900)
    #expect(menuBarSlot.triggerFrame.size.width == 1800)
    #expect(menuBarSlot.triggerFrame.size.height == 30)
}

@Test func layoutCyclingFollowsCurrentUiOrder() async throws {
    let engine = LayoutEngine()
    let layouts = AppConfiguration.defaultValue.layouts

    engine.recordLayoutID("layout-10", for: "window-a")
    engine.recordLayoutID("layout-2", for: "window-b")
    engine.recordLayoutID("layout-11", for: "window-c")

    #expect(engine.nextLayoutID(for: "window-a", layouts: layouts) == "layout-1")
    #expect(engine.previousLayoutID(for: "window-a", layouts: layouts) == "layout-9")
    #expect(engine.nextLayoutID(for: "window-b", layouts: layouts) == "layout-3")
    #expect(engine.previousLayoutID(for: "window-new", layouts: layouts) == "layout-10")
    #expect(engine.nextLayoutID(for: "window-c", layouts: layouts) == "layout-1")
}

@Test func layoutCyclingUsesReorderedLayoutList() async throws {
    let engine = LayoutEngine()
    var configuration = AppConfiguration.defaultValue
    configuration.moveLayout(id: "layout-2", to: configuration.layouts.count)

    engine.recordLayoutID("layout-2", for: "window-a")

    #expect(configuration.layouts.map(\.id) == [
        "layout-1",
        "layout-3",
        "layout-4",
        "layout-5",
        "layout-6",
        "layout-7",
        "layout-8",
        "layout-9",
        "layout-10",
        "layout-11",
        "layout-2",
    ])
    #expect(engine.nextLayoutID(for: "window-a", layouts: configuration.layouts) == "layout-1")
    #expect(engine.previousLayoutID(for: "window-a", layouts: configuration.layouts) == "layout-10")
}

@Test func triggerSlotPrefersLaterDeclaredOverlap() async throws {
    let engine = LayoutEngine()
    let layouts = [
        LayoutPreset(
            id: "layout-a",
            name: "Fullscreen",
            gridColumns: 12,
            gridRows: 6,
            windowSelection: GridSelection(x: 0, y: 0, w: 12, h: 6),
            triggerRegion: .screen(GridSelection(x: 0, y: 0, w: 12, h: 6)),
            includeInLayoutIndex: true
        ),
        LayoutPreset(
            id: "layout-b",
            name: "Left 1/2",
            gridColumns: 12,
            gridRows: 6,
            windowSelection: GridSelection(x: 0, y: 0, w: 6, h: 6),
            triggerRegion: .screen(GridSelection(x: 0, y: 0, w: 6, h: 6)),
            includeInLayoutIndex: true
        ),
    ]

    let slots = engine.resolveTriggerSlots(
        screenFrame: CGRect(x: 0, y: 0, width: 1200, height: 630),
        usableFrame: CGRect(x: 0, y: 0, width: 1200, height: 600),
        layouts: layouts,
        triggerGap: 0
    )

    let matchedSlot = try #require(engine.triggerSlot(containing: CGPoint(x: 100, y: 100), slots: slots))
    #expect(matchedSlot.layoutID == "layout-b")
}

@Test func triggerSlotOverlapIsRemovedFromEarlierHitTestRegions() async throws {
    let engine = LayoutEngine()
    let layouts = [
        LayoutPreset(
            id: "layout-a",
            name: "Fullscreen",
            gridColumns: 12,
            gridRows: 6,
            windowSelection: GridSelection(x: 0, y: 0, w: 12, h: 6),
            triggerRegion: .screen(GridSelection(x: 0, y: 0, w: 12, h: 6)),
            includeInLayoutIndex: true
        ),
        LayoutPreset(
            id: "layout-b",
            name: "Left 1/2",
            gridColumns: 12,
            gridRows: 6,
            windowSelection: GridSelection(x: 0, y: 0, w: 6, h: 6),
            triggerRegion: .screen(GridSelection(x: 0, y: 0, w: 6, h: 6)),
            includeInLayoutIndex: true
        ),
    ]

    let slots = engine.resolveTriggerSlots(
        screenFrame: CGRect(x: 0, y: 0, width: 1200, height: 630),
        usableFrame: CGRect(x: 0, y: 0, width: 1200, height: 600),
        layouts: layouts,
        triggerGap: 0
    )

    let fullscreenSlot = try #require(slots.first(where: { $0.layoutID == "layout-a" }))
    let leftHalfSlot = try #require(slots.first(where: { $0.layoutID == "layout-b" }))

    #expect(fullscreenSlot.hitTestFrames.allSatisfy { !$0.contains(CGPoint(x: 100, y: 100)) })
    #expect(fullscreenSlot.hitTestFrames.contains { $0.contains(CGPoint(x: 900, y: 100)) })
    #expect(leftHalfSlot.hitTestFrames == [leftHalfSlot.triggerFrame])
}

@Test func triggerSlotsSkipLayoutsWhoseTargetFrameCollapsesAfterApplyingLayoutGap() async throws {
    let engine = LayoutEngine()
    let layouts = [
        LayoutPreset(
            id: "layout-a",
            name: "Left half",
            gridColumns: 12,
            gridRows: 6,
            windowSelection: GridSelection(x: 0, y: 0, w: 6, h: 6),
            triggerRegion: .screen(GridSelection(x: 0, y: 0, w: 6, h: 6)),
            includeInLayoutIndex: true
        ),
    ]

    let slots = engine.resolveTriggerSlots(
        screenFrame: CGRect(x: 0, y: 0, width: 120, height: 60),
        usableFrame: CGRect(x: 0, y: 0, width: 120, height: 60),
        layouts: layouts,
        triggerGap: 0,
        layoutGap: 40
    )

    #expect(slots.isEmpty)
}

@Test func targetDisplayIDFollowsMonitorTargetingRules() async throws {
    #expect(
        LayoutGroupResolver.targetDisplayID(
            for: .all,
            currentDisplayID: "main",
            mainDisplayID: "main",
            availableDisplayIDs: ["main", "other"]
        ) == "main"
    )
    #expect(
        LayoutGroupResolver.targetDisplayID(
            for: .main,
            currentDisplayID: "other",
            mainDisplayID: "main",
            availableDisplayIDs: ["main", "other"]
        ) == "main"
    )
    #expect(
        LayoutGroupResolver.targetDisplayID(
            for: .displays(["12345", "67890"]),
            currentDisplayID: "12345",
            mainDisplayID: "99999",
            availableDisplayIDs: ["12345", "67890"]
        ) == "12345"
    )
    #expect(
        LayoutGroupResolver.targetDisplayID(
            for: .displays(["99999", "67890", "12345"]),
            currentDisplayID: "main",
            mainDisplayID: "main",
            availableDisplayIDs: ["12345", "67890"]
        ) == "67890"
    )
    #expect(
        LayoutGroupResolver.targetDisplayID(
            for: .displays(["99999"]),
            currentDisplayID: "main",
            mainDisplayID: "main",
            availableDisplayIDs: ["12345", "67890"]
        ) == nil
    )
}

@Test func layoutGroupResolverUsesGlobalIndexedOrderWithinActiveGroup() async throws {
    var configuration = AppConfiguration.defaultValue
    configuration.general.activeLayoutGroup = AppConfiguration.fullscreenGroupName

    #expect(LayoutGroupResolver.entry(at: 1, configuration: configuration)?.layout.name == "Fullscreen main")
    #expect(LayoutGroupResolver.entry(at: 2, configuration: configuration)?.layout.name == "Main left 1/2")
    #expect(LayoutGroupResolver.entry(at: 3, configuration: configuration)?.layout.name == "Main right 1/2")
    #expect(LayoutGroupResolver.entry(at: 4, configuration: configuration)?.layout.name == "Fullscreen other")
    #expect(LayoutGroupResolver.entry(at: 5, configuration: configuration) == nil)
}

@Test func layoutGroupResolverTargetsDisplayCompatibleWithSelectedSet() async throws {
    var configuration = AppConfiguration.defaultValue
    configuration.general.activeLayoutGroup = AppConfiguration.fullscreenGroupName

    let fullscreenMainEntry = try #require(LayoutGroupResolver.entry(at: 1, configuration: configuration))
    let fullscreenOtherEntry = try #require(LayoutGroupResolver.entry(at: 4, configuration: configuration))

    #expect(
        LayoutGroupResolver.targetDisplayID(
            for: fullscreenMainEntry,
            currentDisplayID: "other",
            mainDisplayID: "main",
            availableDisplayIDs: ["main", "other"],
            configuration: configuration
        ) == "main"
    )
    #expect(
        LayoutGroupResolver.targetDisplayID(
            for: fullscreenOtherEntry,
            currentDisplayID: "main",
            mainDisplayID: "main",
            availableDisplayIDs: ["main", "other"],
            configuration: configuration
        ) == "other"
    )
    #expect(
        LayoutGroupResolver.targetDisplayID(
            for: fullscreenOtherEntry,
            currentDisplayID: "other",
            mainDisplayID: "main",
            availableDisplayIDs: ["main", "other"],
            configuration: configuration
        ) == "other"
    )

    configuration.general.activeLayoutGroup = AppConfiguration.defaultGroupName
    let builtInEntry = try #require(LayoutGroupResolver.entry(at: 1, configuration: configuration))
    #expect(
        LayoutGroupResolver.targetDisplayID(
            for: builtInEntry,
            currentDisplayID: "main",
            mainDisplayID: "main",
            availableDisplayIDs: ["main", "other"],
            configuration: configuration
        ) == "main"
    )
}

@Test func layoutGroupResolverKeepsOtherScreenWithinFallbackAllSetAcrossThreeDisplays() async throws {
    var configuration = AppConfiguration.defaultValue
    configuration.general.activeLayoutGroup = AppConfiguration.fullscreenGroupName
    let fullscreenOtherEntry = try #require(LayoutGroupResolver.entry(at: 4, configuration: configuration))

    #expect(
        LayoutGroupResolver.targetDisplayID(
            for: fullscreenOtherEntry,
            currentDisplayID: "main",
            mainDisplayID: "main",
            availableDisplayIDs: ["main", "other-a", "other-b"],
            configuration: configuration
        ) == "other-a"
    )
    #expect(
        LayoutGroupResolver.targetDisplayID(
            for: fullscreenOtherEntry,
            currentDisplayID: "other-b",
            mainDisplayID: "main",
            availableDisplayIDs: ["main", "other-a", "other-b"],
            configuration: configuration
        ) == "other-b"
    )
}

@Test func layoutGroupResolverDoesNotReuseDisplayOwnedByExplicitSetWhenApplyingFallbackAllLayout() async throws {
    let explicitLayout = LayoutPreset(
        id: "layout-explicit",
        name: "Explicit",
        gridColumns: 12,
        gridRows: 6,
        windowSelection: GridSelection(x: 0, y: 0, w: 12, h: 6),
        triggerRegion: nil,
        includeInLayoutIndex: true
    )
    let fallbackLayout = LayoutPreset(
        id: "layout-fallback",
        name: "Fallback",
        gridColumns: 12,
        gridRows: 6,
        windowSelection: GridSelection(x: 0, y: 0, w: 12, h: 6),
        triggerRegion: nil,
        includeInLayoutIndex: true
    )
    let configuration = AppConfiguration(
        general: .init(
            isEnabled: true,
            launchAtLogin: true,
            excludedBundleIDs: [],
            excludedWindowTitles: [],
            activeLayoutGroup: "mixed",
            mouseButtonNumber: 3
        ),
        appearance: AppConfiguration.defaultValue.appearance,
        dragTriggers: AppConfiguration.defaultValue.dragTriggers,
        hotkeys: .init(bindings: []),
        layoutGroups: [
            LayoutGroup(
                name: "mixed",
                includeInGroupCycle: true,
                sets: [
                    LayoutSet(monitor: .displays(["other-a"]), layouts: [explicitLayout]),
                    LayoutSet(monitor: .all, layouts: [fallbackLayout]),
                ]
            ),
        ],
        monitors: [:]
    )
    let fallbackEntry = try #require(LayoutGroupResolver.entry(for: "layout-fallback", configuration: configuration))

    #expect(
        LayoutGroupResolver.targetDisplayID(
            for: fallbackEntry,
            currentDisplayID: "other-a",
            mainDisplayID: "main",
            availableDisplayIDs: ["main", "other-a", "other-b"],
            configuration: configuration
        ) == "main"
    )
}

@Test func layoutGroupResolverTargetsExplicitUUIDDisplay() async throws {
    let explicitLayout = LayoutPreset(
        id: "layout-explicit-uuid",
        name: "Explicit UUID",
        gridColumns: 12,
        gridRows: 6,
        windowSelection: GridSelection(x: 0, y: 0, w: 12, h: 6),
        triggerRegion: nil,
        includeInLayoutIndex: true
    )
    let configuration = AppConfiguration(
        general: .init(
            isEnabled: true,
            launchAtLogin: true,
            excludedBundleIDs: [],
            excludedWindowTitles: [],
            activeLayoutGroup: "uuid-only",
            mouseButtonNumber: 3
        ),
        appearance: AppConfiguration.defaultValue.appearance,
        dragTriggers: AppConfiguration.defaultValue.dragTriggers,
        hotkeys: .init(bindings: []),
        layoutGroups: [
            LayoutGroup(
                name: "uuid-only",
                includeInGroupCycle: true,
                sets: [
                    LayoutSet(monitor: .displays(["f8a3198a-7f52-4f69-9f4e-9840d7ee3da4"]), layouts: [explicitLayout]),
                ]
            ),
        ],
        monitors: ["f8a3198a-7f52-4f69-9f4e-9840d7ee3da4": "Built-in Retina Display"]
    )
    let entry = try #require(LayoutGroupResolver.entry(for: "layout-explicit-uuid", configuration: configuration))

    #expect(
        LayoutGroupResolver.targetDisplayID(
            for: entry,
            currentDisplayID: "f8a3198a-7f52-4f69-9f4e-9840d7ee3da4",
            mainDisplayID: "main",
            availableDisplayIDs: ["main", "f8a3198a-7f52-4f69-9f4e-9840d7ee3da4"],
            configuration: configuration
        ) == "f8a3198a-7f52-4f69-9f4e-9840d7ee3da4"
    )
}

@Test func configurationValidatorAllowsTwoDifferentUUIDDisplays() async throws {
    let explicitLayout = LayoutPreset(
        id: "layout-explicit-uuid",
        name: "Explicit UUID",
        gridColumns: 12,
        gridRows: 6,
        windowSelection: GridSelection(x: 0, y: 0, w: 12, h: 6),
        triggerRegion: nil,
        includeInLayoutIndex: true
    )
    let configuration = AppConfiguration(
        general: .init(
            isEnabled: true,
            launchAtLogin: true,
            excludedBundleIDs: [],
            excludedWindowTitles: [],
            activeLayoutGroup: "uuid-only",
            mouseButtonNumber: 3
        ),
        appearance: AppConfiguration.defaultValue.appearance,
        dragTriggers: AppConfiguration.defaultValue.dragTriggers,
        hotkeys: .init(bindings: []),
        layoutGroups: [
            LayoutGroup(
                name: "uuid-only",
                includeInGroupCycle: true,
                sets: [
                    LayoutSet(monitor: .displays(["f8a3198a-7f52-4f69-9f4e-9840d7ee3da4"]), layouts: [explicitLayout]),
                    LayoutSet(monitor: .displays(["9b249d3c-1111-2222-3333-444455556666"]), layouts: [explicitLayout]),
                ]
            ),
        ],
        monitors: [
            "f8a3198a-7f52-4f69-9f4e-9840d7ee3da4": "Built-in Retina Display",
            "9b249d3c-1111-2222-3333-444455556666": "DELL U2720Q",
        ]
    )

    try ConfigurationValidator.validate(configuration)
}

@Test func layoutEngineKeepsOnlyTenRecentWindowLayoutRecords() async throws {
    let engine = LayoutEngine()
    let layouts = AppConfiguration.defaultValue.layouts

    for index in 1...11 {
        engine.recordLayoutID("layout-2", for: "window-\(index)")
    }

    #expect(engine.nextLayoutID(for: "window-1", layouts: layouts) == "layout-1")
    #expect(engine.nextLayoutID(for: "window-2", layouts: layouts) == "layout-3")

    engine.recordLayoutID("layout-4", for: "window-5")

    #expect(engine.nextLayoutID(for: "window-2", layouts: layouts) == "layout-3")
    #expect(engine.nextLayoutID(for: "window-5", layouts: layouts) == "layout-5")
}
