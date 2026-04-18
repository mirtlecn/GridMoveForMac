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
        controller.setRenderTriggerAreasForTesting(true)
        controller.setTriggerGapForTesting(3)

        #expect(state.configuration.appearance.renderWindowHighlight == false)
        #expect(state.configuration.appearance.highlightFillOpacity == 0.25)
        #expect(state.configuration.appearance.highlightStrokeWidth == 6)
        #expect(state.configuration.appearance.layoutGap == 4)
        #expect(state.configuration.appearance.renderTriggerAreas == true)
        #expect(state.configuration.appearance.triggerGap == 3)
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

    @Test func appearancePreviewUsesBuiltInCenterTriggerSample() async throws {
        var configuration = AppConfiguration.defaultValue
        configuration.appearance.renderTriggerAreas = true
        let state = SettingsPrototypeState(configuration: configuration)
        let recorder = TestSettingsActionRecorder()
        let controller = AppearanceSettingsViewController(
            prototypeState: state,
            actionHandler: recorder.makeActionHandler()
        )
        controller.loadViewIfNeeded()

        let previewSlots = controller.previewResolvedSlotsForTesting
        let previewSlot = try #require(previewSlots.first)
        let sampleLayout = try #require(AppConfiguration.defaultLayouts.first(where: { $0.id == "layout-4" }))
        let expectedSlot = try #require(
            LayoutEngine().resolveTriggerSlots(
                screenFrame: SettingsPreviewSupport.referenceScreenFrame,
                usableFrame: SettingsPreviewSupport.referenceUsableFrame,
                layouts: [sampleLayout],
                triggerGap: Double(configuration.appearance.triggerGap),
                layoutGap: configuration.appearance.effectiveLayoutGap
            ).first
        )

        #expect(previewSlots.count == 1)
        #expect(previewSlot.layoutID == "layout-4")
        #expect(previewSlot.triggerFrame == expectedSlot.triggerFrame)
        #expect(controller.previewHighlightFrameForTesting == expectedSlot.targetFrame)
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
        reloadedConfiguration.appearance.renderTriggerAreas = true

        state.reload(from: reloadedConfiguration)

        #expect(controller.previewConfigurationForTesting.appearance.renderTriggerAreas == true)
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
