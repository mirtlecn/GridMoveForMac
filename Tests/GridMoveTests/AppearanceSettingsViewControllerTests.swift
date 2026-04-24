import AppKit
import Testing
@testable import GridMove

@MainActor
struct AppearanceSettingsViewControllerTests {
    @Test func settingsIntegerFormatterRejectsFractionalAndAlphabeticInput() async throws {
        let formatter = SettingsIntegerFormatter()
        var newEditingString: NSString?
        var errorDescription: NSString?

        #expect(
            formatter.isPartialStringValid(
                "12",
                newEditingString: &newEditingString,
                errorDescription: &errorDescription
            ) == true
        )
        #expect(
            formatter.isPartialStringValid(
                "1.5",
                newEditingString: &newEditingString,
                errorDescription: &errorDescription
            ) == false
        )
        #expect(
            formatter.isPartialStringValid(
                "abc",
                newEditingString: &newEditingString,
                errorDescription: &errorDescription
            ) == false
        )
    }

    @Test func windowHighlightStrokeWidthIsDisabledAtZero() async throws {
        var appearance = AppConfiguration.defaultValue.appearance
        appearance.highlightStrokeWidth = 0

        #expect(SettingsPreviewSupport.windowHighlightStrokeWidth(for: appearance) == nil)

        appearance.highlightStrokeWidth = 3
        #expect(SettingsPreviewSupport.windowHighlightStrokeWidth(for: appearance) == 3)
    }

    @Test func appearanceSettingsWritesRealConfigurationFieldsAndUpdatesPreview() async throws {
        let state = SettingsPrototypeState(configuration: .defaultValue)
        let recorder = TestSettingsActionRecorder()
        let controller = AppearanceSettingsViewController(
            prototypeState: state,
            actionHandler: recorder.makeActionHandler()
        )
        controller.loadViewIfNeeded()

        controller.setRenderWindowHighlightForTesting(false)
        controller.setHighlightFillOpacityForTesting(0.25)
        controller.setHighlightStrokeWidthForTesting(6)
        controller.setLayoutGapForTesting(4)
        controller.setTriggerHighlightModeForTesting(.all)
        controller.setTriggerFillOpacityForTesting(0.18)
        controller.setTriggerGapForTesting(3)
        controller.setTriggerStrokeWidthForTesting(5)

        #expect(state.configuration.appearance.renderWindowHighlight == false)
        #expect(state.configuration.appearance.highlightFillOpacity == 0.25)
        #expect(state.configuration.appearance.highlightStrokeWidth == 6)
        #expect(state.configuration.appearance.layoutGap == 4)
        #expect(state.configuration.appearance.triggerHighlightMode == .all)
        #expect(state.configuration.appearance.triggerFillOpacity == 0.18)
        #expect(state.configuration.appearance.triggerGap == 3)
        #expect(state.configuration.appearance.triggerStrokeWidth == 5)
        #expect(controller.previewConfigurationForTesting.appearance.highlightFillOpacity == 0.25)
    }

    @Test func appearanceFillOpacityPreviewChangesBeforePersisting() async throws {
        let state = SettingsPrototypeState(configuration: .defaultValue)
        let recorder = TestSettingsActionRecorder()
        let controller = AppearanceSettingsViewController(
            prototypeState: state,
            actionHandler: recorder.makeActionHandler()
        )
        controller.loadViewIfNeeded()

        controller.previewHighlightFillOpacityForTesting(0.42)
        #expect(controller.previewConfigurationForTesting.appearance.highlightFillOpacity == 0.42)
        #expect(state.configuration.appearance.highlightFillOpacity == AppConfiguration.defaultValue.appearance.highlightFillOpacity)

        controller.commitHighlightFillOpacityForTesting(0.42)
        #expect(state.configuration.appearance.highlightFillOpacity == 0.42)
    }

    @Test func appearanceStrokeColorPreviewChangesBeforePersisting() async throws {
        let state = SettingsPrototypeState(configuration: .defaultValue)
        let recorder = TestSettingsActionRecorder()
        let controller = AppearanceSettingsViewController(
            prototypeState: state,
            actionHandler: recorder.makeActionHandler()
        )
        controller.loadViewIfNeeded()

        let previewColor = NSColor.systemRed
        controller.previewHighlightStrokeColorForTesting(previewColor)

        #expect(
            controller.previewConfigurationForTesting.appearance.highlightStrokeColor
                == AppearanceSettingsViewController.makeRGBAColorForTesting(previewColor)
        )
        #expect(
            state.configuration.appearance.highlightStrokeColor
                == AppConfiguration.defaultValue.appearance.highlightStrokeColor
        )

        controller.commitHighlightStrokeColorForTesting(previewColor)
        #expect(
            state.configuration.appearance.highlightStrokeColor
                == AppearanceSettingsViewController.makeRGBAColorForTesting(previewColor)
        )
    }

    @Test func appearancePreviewUsesIndependentWindowAndTriggerSamples() async throws {
        var configuration = AppConfiguration.defaultValue
        configuration.appearance.triggerHighlightMode = .all
        let state = SettingsPrototypeState(configuration: configuration)
        let recorder = TestSettingsActionRecorder()
        let controller = AppearanceSettingsViewController(
            prototypeState: state,
            actionHandler: recorder.makeActionHandler()
        )
        controller.loadViewIfNeeded()

        let previewSlots = controller.previewResolvedSlotsForTesting
        let previewSlot = try #require(previewSlots.first)
        let triggerSampleLayout = LayoutPreset(
            id: "preview-trigger-layout",
            name: "Preview trigger",
            gridColumns: SettingsPreviewSupport.defaultPreviewColumns,
            gridRows: SettingsPreviewSupport.defaultPreviewRows,
            windowSelection: GridSelection(x: 3, y: 1, w: 6, h: 4),
            triggerRegions: [.screen(GridSelection(x: 5, y: 0, w: 2, h: 6))],
            includeInLayoutIndex: false,
            includeInMenu: false
        )
        let windowSampleLayout = LayoutPreset(
            id: "preview-window-layout",
            name: "Preview window",
            gridColumns: SettingsPreviewSupport.defaultPreviewColumns,
            gridRows: SettingsPreviewSupport.defaultPreviewRows,
            windowSelection: GridSelection(x: 3, y: 1, w: 6, h: 4),
            triggerRegions: [],
            includeInLayoutIndex: false,
            includeInMenu: false
        )
        let expectedSlot = try #require(
            LayoutEngine().resolveTriggerSlots(
                screenFrame: SettingsPreviewSupport.referenceScreenFrame,
                usableFrame: SettingsPreviewSupport.referenceUsableFrame,
                layouts: [triggerSampleLayout],
                triggerGap: Double(configuration.appearance.triggerGap),
                layoutGap: configuration.appearance.effectiveLayoutGap
            ).first
        )
        let expectedHighlightFrame = try #require(
            LayoutEngine().frame(
                for: windowSampleLayout,
                in: SettingsPreviewSupport.referenceUsableFrame,
                layoutGap: configuration.appearance.effectiveLayoutGap
            )
        )

        #expect(previewSlots.count == 1)
        #expect(previewSlot.layoutID == "preview-trigger-layout")
        #expect(previewSlot.triggerFrame == expectedSlot.triggerFrame)
        #expect(controller.previewHighlightFrameForTesting == expectedHighlightFrame)
    }

    @Test func appearancePreviewRefreshesAfterReload() async throws {
        let state = SettingsPrototypeState(configuration: .defaultValue)
        let recorder = TestSettingsActionRecorder()
        let controller = AppearanceSettingsViewController(
            prototypeState: state,
            actionHandler: recorder.makeActionHandler()
        )
        controller.loadViewIfNeeded()

        var reloadedConfiguration = AppConfiguration.defaultValue
        reloadedConfiguration.appearance.triggerHighlightMode = .all

        state.reload(from: reloadedConfiguration)

        #expect(controller.previewConfigurationForTesting.appearance.triggerHighlightMode == .all)
        #expect(controller.previewConfigurationForTesting.appearance.highlightFillOpacity == reloadedConfiguration.appearance.highlightFillOpacity)
    }

    @Test func appearanceSettingsRollBackAfterFailedApply() async throws {
        let state = SettingsPrototypeState(configuration: .defaultValue)
        let recorder = TestSettingsActionRecorder()
        recorder.applySucceeds = false
        let controller = AppearanceSettingsViewController(
            prototypeState: state,
            actionHandler: recorder.makeActionHandler()
        )
        controller.loadViewIfNeeded()

        controller.setHighlightFillOpacityForTesting(0.4)

        #expect(state.configuration.appearance.highlightFillOpacity == AppConfiguration.defaultValue.appearance.highlightFillOpacity)
        #expect(
            controller.previewConfigurationForTesting.appearance.highlightFillOpacity
                == AppConfiguration.defaultValue.appearance.highlightFillOpacity
        )
    }
}
