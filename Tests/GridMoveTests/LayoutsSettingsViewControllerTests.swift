import AppKit
import Testing
@testable import GridMove

@MainActor
struct LayoutsSettingsViewControllerTests {
    @Test func movingLayoutInsideSelectedSetReordersOnlyThatSet() async throws {
        let controller = LayoutsSettingsViewController()

        #expect(
            controller.moveLayoutForTesting(
                id: "layout-14",
                groupName: AppConfiguration.fullscreenGroupName,
                setIndex: 0,
                toLocalIndex: 1
            ) == true
        )

        #expect(
            controller.layoutTitlesForTesting(
                groupName: AppConfiguration.fullscreenGroupName,
                setIndex: 0
            ) == ["Fullscreen main", "Main right 1/2", "Main left 1/2", "Fullscreen main (menu bar)"]
        )
        #expect(
            controller.layoutTitlesForTesting(
                groupName: AppConfiguration.fullscreenGroupName,
                setIndex: 1
            ) == ["Fullscreen other", "Fullscreen other (menu bar)"]
        )
    }

    @Test func movingLayoutIntoDifferentSetIsRejected() async throws {
        let controller = LayoutsSettingsViewController()

        #expect(
            controller.moveLayoutForTesting(
                id: "layout-14",
                groupName: AppConfiguration.fullscreenGroupName,
                setIndex: 1,
                toLocalIndex: 0
            ) == false
        )

        #expect(
            controller.layoutTitlesForTesting(
                groupName: AppConfiguration.fullscreenGroupName,
                setIndex: 0
            ) == ["Fullscreen main", "Main left 1/2", "Main right 1/2", "Fullscreen main (menu bar)"]
        )
        #expect(
            controller.layoutTitlesForTesting(
                groupName: AppConfiguration.fullscreenGroupName,
                setIndex: 1
            ) == ["Fullscreen other", "Fullscreen other (menu bar)"]
        )
    }
}
