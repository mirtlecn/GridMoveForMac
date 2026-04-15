import Foundation
import Testing
@testable import GridMove

@Test func defaultLayoutsMatchAgreedSelections() async throws {
    let layouts = AppConfiguration.defaultValue.layouts

    #expect(layouts.count == 10)
    #expect(layouts.map(\.id) == (1 ... 10).map { "layout-\($0)" })
    #expect(layouts.map(\.name) == [
        "Left 1/3",
        "Left 1/2",
        "Left 2/3",
        "Center",
        "Right 2/3",
        "Right 1/2",
        "Right 1/3",
        "Right 1/3 Top",
        "Right 1/3 Bottom",
        "Fill all screen",
    ])
    #expect(layouts[0].windowSelection == GridSelection(x: 0, y: 0, w: 4, h: 6))
    #expect(layouts[0].triggerSelection == GridSelection(x: 0, y: 0, w: 2, h: 6))
    #expect(layouts[3].windowSelection == GridSelection(x: 3, y: 1, w: 6, h: 4))
    #expect(layouts[3].triggerSelection == GridSelection(x: 5, y: 2, w: 2, h: 2))
    #expect(layouts[7].windowSelection == GridSelection(x: 8, y: 0, w: 4, h: 3))
    #expect(layouts[7].triggerSelection == GridSelection(x: 10, y: 0, w: 2, h: 2))
    #expect(layouts[9].windowSelection == GridSelection(x: 0, y: 0, w: 12, h: 6))
    #expect(layouts[9].triggerSelection == GridSelection(x: 5, y: 0, w: 2, h: 2))
}

@Test func layoutFrameUsesTopOriginCoordinates() async throws {
    let engine = LayoutEngine()
    let preset = AppConfiguration.defaultValue.layouts[7]
    let usableFrame = CGRect(x: 0, y: 0, width: 1200, height: 600)

    let frame = engine.frame(for: preset, in: usableFrame)

    #expect(frame.origin.x == 800)
    #expect(frame.origin.y == 300)
    #expect(frame.size.width == 400)
    #expect(frame.size.height == 300)
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
    let usableFrame = CGRect(x: 0, y: 0, width: 1800, height: 900)

    let slots = engine.resolveTriggerSlots(in: usableFrame, configuration: configuration)
    let firstSlot = try #require(slots.first)
    let fullscreenSlot = try #require(slots.last)

    #expect(firstSlot.layoutID == "layout-1")
    #expect(firstSlot.triggerFrame.origin.x == 2)
    #expect(firstSlot.triggerFrame.origin.y == 2)
    #expect(firstSlot.triggerFrame.size.width == 296)
    #expect(firstSlot.triggerFrame.size.height == 896)

    #expect(fullscreenSlot.layoutID == "layout-10")
    #expect(fullscreenSlot.triggerFrame.origin.x == 752)
    #expect(fullscreenSlot.triggerFrame.origin.y == 602)
    #expect(fullscreenSlot.triggerFrame.size.width == 296)
    #expect(fullscreenSlot.triggerFrame.size.height == 296)
}

@Test func layoutCyclingFollowsCurrentUiOrder() async throws {
    let engine = LayoutEngine()
    let layouts = AppConfiguration.defaultValue.layouts

    engine.recordLayoutID("layout-10", for: "window-a")
    engine.recordLayoutID("layout-2", for: "window-b")

    #expect(engine.nextLayoutID(for: "window-a", layouts: layouts) == "layout-1")
    #expect(engine.previousLayoutID(for: "window-a", layouts: layouts) == "layout-9")
    #expect(engine.nextLayoutID(for: "window-b", layouts: layouts) == "layout-3")
    #expect(engine.previousLayoutID(for: "window-new", layouts: layouts) == "layout-10")
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
        "layout-2",
    ])
    #expect(engine.nextLayoutID(for: "window-a", layouts: configuration.layouts) == "layout-1")
    #expect(engine.previousLayoutID(for: "window-a", layouts: configuration.layouts) == "layout-10")
}
