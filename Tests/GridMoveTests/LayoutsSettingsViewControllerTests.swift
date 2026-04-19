import AppKit
import Testing
@testable import GridMove

@MainActor
struct LayoutsSettingsViewControllerTests {
    private func makeController(
        configuration: AppConfiguration = .defaultValue
    ) -> (controller: LayoutsSettingsViewController, state: SettingsPrototypeState, recorder: TestSettingsActionRecorder) {
        let recorder = TestSettingsActionRecorder()
        let state = SettingsPrototypeState(configuration: configuration)
        let controller = LayoutsSettingsViewController(
            prototypeState: state,
            actionHandler: recorder.makeActionHandler()
        )
        _ = controller.view
        return (controller, state, recorder)
    }

    @Test func movingLayoutInsideSelectedSetReordersOnlyThatSet() async throws {
        let (controller, _, _) = makeController()

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
        let (controller, _, _) = makeController()

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

    @Test func protectedGroupCannotBeRemovedAndShowsTooltip() async throws {
        let (controller, _, _) = makeController()

        controller.selectGroupForTesting(named: AppConfiguration.defaultGroupName)

        #expect(controller.removeButtonEnabledForTesting == false)
        #expect(controller.removeButtonToolTipForTesting == UICopy.settingsProtectedGroupTooltip)
    }

    @Test func layoutsTreeInitiallyExpandsOnlyActiveGroup() async throws {
        var configuration = AppConfiguration.defaultValue
        configuration.general.activeLayoutGroup = AppConfiguration.fullscreenGroupName
        let (controller, _, _) = makeController(configuration: configuration)

        #expect(controller.expandedGroupNamesForTesting == [AppConfiguration.fullscreenGroupName])
        #expect(controller.expandedSetCountForTesting(groupName: AppConfiguration.fullscreenGroupName) == 2)
        #expect(controller.selectedGroupNameForTesting == AppConfiguration.fullscreenGroupName)
    }

    @Test func saveButtonTracksLayoutsDraftChangesAndCommit() async throws {
        let (controller, state, recorder) = makeController()

        #expect(controller.saveButtonEnabledForTesting == false)
        #expect(controller.saveButtonUsesDefaultActionStyleForTesting == false)

        state.applyLayoutsMutation { configuration in
            configuration.general.activeLayoutGroup = AppConfiguration.fullscreenGroupName
        }

        #expect(controller.saveButtonEnabledForTesting == true)
        #expect(controller.saveButtonUsesDefaultActionStyleForTesting == true)

        controller.saveLayoutsForTesting()

        #expect(recorder.savedLayoutsCandidates.last?.general.activeLayoutGroup == AppConfiguration.fullscreenGroupName)
        #expect(controller.saveButtonEnabledForTesting == false)
        #expect(controller.saveButtonUsesDefaultActionStyleForTesting == false)
    }

    @Test func addGroupAppendsProtectedFalseGroupWithEmptyAllMonitorSet() async throws {
        let (controller, _, _) = makeController()

        controller.selectGroupForTesting(named: AppConfiguration.defaultGroupName)
        controller.addActionForTesting()

        let groups = controller.draftConfigurationForTesting.layoutGroups
        let newGroup = try #require(groups.last)
        #expect(newGroup.name == "Group 1")
        #expect(newGroup.includeInGroupCycle == false)
        #expect(newGroup.protect == false)
        #expect(newGroup.sets.count == 1)
        #expect(newGroup.sets[0].monitor == .all)
        #expect(newGroup.sets[0].layouts.isEmpty)
        #expect(controller.selectedGroupNameForTesting == "Group 1")
    }

    @Test func addMonitorSetUsesNextLegalMonitorBinding() async throws {
        let (controller, _, _) = makeController()

        controller.selectSetForTesting(groupName: AppConfiguration.defaultGroupName, setIndex: 0)
        controller.addActionForTesting()

        let group = try #require(
            controller.draftConfigurationForTesting.layoutGroups.first(where: { $0.name == AppConfiguration.defaultGroupName })
        )
        #expect(group.sets.count == 2)
        #expect(group.sets[1].monitor == .main)
        #expect(group.sets[1].layouts.isEmpty)
    }

    @Test func addLayoutToEmptySetUsesBuiltinTemplateFour() async throws {
        let (controller, _, _) = makeController()
        let templateLayout = AppConfiguration.defaultLayouts[3]

        controller.selectSetForTesting(groupName: AppConfiguration.defaultGroupName, setIndex: 0)
        controller.addActionForTesting()
        controller.selectSetForTesting(groupName: AppConfiguration.defaultGroupName, setIndex: 1)
        controller.addActionForTesting()

        let group = try #require(
            controller.draftConfigurationForTesting.layoutGroups.first(where: { $0.name == AppConfiguration.defaultGroupName })
        )
        let layouts = group.sets[1].layouts
        let addedLayout = try #require(layouts.first)
        #expect(layouts.count == 1)
        #expect(addedLayout.name.isEmpty)
        #expect(addedLayout.gridColumns == templateLayout.gridColumns)
        #expect(addedLayout.gridRows == templateLayout.gridRows)
        #expect(addedLayout.windowSelection == templateLayout.windowSelection)
        #expect(addedLayout.triggerRegion == templateLayout.triggerRegion)
        #expect(addedLayout.includeInMenu == templateLayout.includeInMenu)
        #expect(addedLayout.includeInLayoutIndex == templateLayout.includeInLayoutIndex)
    }

    @Test func duplicateMonitorBindingsAreRejectedAndDraftStaysValid() async throws {
        let (controller, _, _) = makeController()

        controller.selectSetForTesting(groupName: AppConfiguration.defaultGroupName, setIndex: 0)
        controller.addActionForTesting()
        controller.updateSetMonitorForTesting(
            groupName: AppConfiguration.defaultGroupName,
            setIndex: 1,
            monitor: .all
        )

        let group = try #require(
            controller.draftConfigurationForTesting.layoutGroups.first(where: { $0.name == AppConfiguration.defaultGroupName })
        )
        #expect(group.sets[0].monitor == .all)
        #expect(group.sets[1].monitor == .main)
    }

    @Test func layoutGridControlsShowAndCommitValuesAboveTwentyFour() async throws {
        var configuration = AppConfiguration.defaultValue
        configuration.layoutGroups[0].sets[0].layouts[0].gridColumns = 30
        configuration.layoutGroups[0].sets[0].layouts[0].gridRows = 40
        let (controller, _, _) = makeController(configuration: configuration)

        controller.selectLayoutForTesting(id: "layout-1")

        let initialGridSize = try #require(controller.currentLayoutGridSizeValuesForTesting)
        #expect(initialGridSize.columns == 30)
        #expect(initialGridSize.rows == 40)

        controller.updateCurrentLayoutGridSizeForTesting(columns: 50, rows: 60)

        let updatedLayout = try #require(
            controller.draftConfigurationForTesting.layoutGroups[0].sets[0].layouts.first(where: { $0.id == "layout-1" })
        )
        #expect(updatedLayout.gridColumns == 50)
        #expect(updatedLayout.gridRows == 60)
    }

    @Test func activatingGroupUsesDoubleClickInsteadOfCheckbox() async throws {
        let (controller, _, recorder) = makeController()

        controller.selectGroupForTesting(named: AppConfiguration.fullscreenGroupName)
        controller.activateSelectedGroupForTesting()

        #expect(controller.activeGroupNameForTesting == AppConfiguration.fullscreenGroupName)
        #expect(controller.saveButtonEnabledForTesting == true)
        #expect(recorder.savedLayoutsCandidates.isEmpty)
    }

    @Test func windowSelectionButtonsDisableIncrementAtEffectiveBounds() async throws {
        var configuration = AppConfiguration.defaultValue
        configuration.layoutGroups[0].sets[0].layouts[0].gridColumns = 4
        configuration.layoutGroups[0].sets[0].layouts[0].gridRows = 2
        configuration.layoutGroups[0].sets[0].layouts[0].windowSelection = GridSelection(x: 0, y: 0, w: 4, h: 2)
        let (controller, _, _) = makeController(configuration: configuration)

        controller.selectLayoutForTesting(id: "layout-1")

        let buttonState = try #require(controller.currentLayoutWindowSelectionButtonStateForTesting)
        #expect(buttonState.xCanIncrement == false)
        #expect(buttonState.yCanIncrement == false)
        #expect(buttonState.widthCanIncrement == false)
        #expect(buttonState.heightCanIncrement == false)
    }

    @Test func untitledLayoutUsesNumeroFallbackTitleInTree() async throws {
        var configuration = AppConfiguration.defaultValue
        let layoutID = configuration.layoutGroups[0].sets[0].layouts[0].id
        configuration.layoutGroups[0].sets[0].layouts[0].name = ""
        let (controller, _, _) = makeController(configuration: configuration)

        #expect(controller.layoutTreeTitleForTesting(id: layoutID) == "Layout №1")
    }

    @Test func previewDragInWindowAreaCommitsWindowSelection() async throws {
        let (controller, _, _) = makeController()

        controller.selectLayoutForTesting(id: "layout-1")
        controller.selectLayoutDetailTabForTesting(1)

        #expect(controller.currentLayoutPreviewInteractionModeForTesting == .windowSelection)

        controller.simulateCurrentLayoutPreviewGridDragForTesting(
            from: SettingsPreviewGridCell(column: 1, row: 1),
            to: SettingsPreviewGridCell(column: 3, row: 2)
        )

        let updatedLayout = try #require(
            controller.draftConfigurationForTesting.layoutGroups[0].sets[0].layouts.first(where: { $0.id == "layout-1" })
        )
        #expect(updatedLayout.windowSelection == GridSelection(x: 1, y: 1, w: 3, h: 2))
    }

    @Test func previewDragInTriggerScreenAreaCommitsScreenTriggerRegion() async throws {
        let (controller, _, _) = makeController()

        controller.selectLayoutForTesting(id: "layout-1")
        controller.selectLayoutDetailTabForTesting(2)
        controller.setCurrentLayoutTriggerAreaKindForTesting(.screen)

        #expect(controller.currentLayoutPreviewInteractionModeForTesting == .triggerScreenSelection)

        controller.simulateCurrentLayoutPreviewGridDragForTesting(
            from: SettingsPreviewGridCell(column: 2, row: 0),
            to: SettingsPreviewGridCell(column: 4, row: 3)
        )

        let updatedLayout = try #require(
            controller.draftConfigurationForTesting.layoutGroups[0].sets[0].layouts.first(where: { $0.id == "layout-1" })
        )
        #expect(updatedLayout.triggerRegion == .screen(GridSelection(x: 2, y: 0, w: 3, h: 4)))
    }

    @Test func previewDragInTriggerMenuBarAreaCommitsMenuBarTriggerRegion() async throws {
        let (controller, _, _) = makeController()

        controller.selectLayoutForTesting(id: "layout-1")
        controller.selectLayoutDetailTabForTesting(2)
        controller.setCurrentLayoutTriggerAreaKindForTesting(.menuBar)

        #expect(controller.currentLayoutPreviewInteractionModeForTesting == .triggerMenuBarSelection)

        controller.simulateCurrentLayoutPreviewMenuBarDragForTesting(from: 1, to: 4)

        let updatedLayout = try #require(
            controller.draftConfigurationForTesting.layoutGroups[0].sets[0].layouts.first(where: { $0.id == "layout-1" })
        )
        #expect(updatedLayout.triggerRegion == .menuBar(MenuBarSelection(x: 1, w: 4)))
    }

    @Test func previewIsNotInteractiveOutsideWindowAreaAndEnabledTriggerKinds() async throws {
        let (controller, _, _) = makeController()
        let originalLayout = try #require(
            controller.draftConfigurationForTesting.layoutGroups[0].sets[0].layouts.first(where: { $0.id == "layout-1" })
        )

        controller.selectLayoutForTesting(id: "layout-1")
        #expect(controller.currentLayoutPreviewInteractionModeForTesting == LayoutPreviewView.InteractionMode.none)

        controller.simulateCurrentLayoutPreviewGridDragForTesting(
            from: SettingsPreviewGridCell(column: 0, row: 0),
            to: SettingsPreviewGridCell(column: 2, row: 2)
        )

        var updatedLayout = try #require(
            controller.draftConfigurationForTesting.layoutGroups[0].sets[0].layouts.first(where: { $0.id == "layout-1" })
        )
        #expect(updatedLayout.windowSelection == originalLayout.windowSelection)
        #expect(updatedLayout.triggerRegion == originalLayout.triggerRegion)

        controller.selectLayoutDetailTabForTesting(2)
        controller.setCurrentLayoutTriggerAreaKindForTesting(.none)
        #expect(controller.currentLayoutPreviewInteractionModeForTesting == LayoutPreviewView.InteractionMode.none)

        let noneTriggerLayout = try #require(
            controller.draftConfigurationForTesting.layoutGroups[0].sets[0].layouts.first(where: { $0.id == "layout-1" })
        )
        #expect(noneTriggerLayout.triggerRegion == nil)

        controller.simulateCurrentLayoutPreviewMenuBarDragForTesting(from: 0, to: 3)

        updatedLayout = try #require(
            controller.draftConfigurationForTesting.layoutGroups[0].sets[0].layouts.first(where: { $0.id == "layout-1" })
        )
        #expect(updatedLayout.triggerRegion == noneTriggerLayout.triggerRegion)
    }

    @Test func previewCursorRegionMatchesInteractiveMode() async throws {
        let (controller, _, _) = makeController()

        controller.selectLayoutForTesting(id: "layout-1")
        #expect(controller.currentLayoutPreviewInteractiveCursorRegionForTesting == LayoutPreviewView.InteractiveCursorRegion.none)

        controller.selectLayoutDetailTabForTesting(1)
        #expect(controller.currentLayoutPreviewInteractiveCursorRegionForTesting == .usableRect)

        controller.selectLayoutDetailTabForTesting(2)
        controller.setCurrentLayoutTriggerAreaKindForTesting(.screen)
        #expect(controller.currentLayoutPreviewInteractiveCursorRegionForTesting == .usableRect)

        controller.setCurrentLayoutTriggerAreaKindForTesting(.menuBar)
        #expect(controller.currentLayoutPreviewInteractiveCursorRegionForTesting == .menuBarRect)

        controller.setCurrentLayoutTriggerAreaKindForTesting(.none)
        #expect(controller.currentLayoutPreviewInteractiveCursorRegionForTesting == LayoutPreviewView.InteractiveCursorRegion.none)
    }
}
