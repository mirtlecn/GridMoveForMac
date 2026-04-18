import AppKit
import Testing
@testable import GridMove

@MainActor
struct AppearanceSettingsViewControllerTests {
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
        controller.setTriggerOpacityForTesting(0.35)
        controller.setTriggerGapForTesting(3)

        #expect(state.configuration.appearance.renderWindowHighlight == false)
        #expect(state.configuration.appearance.highlightFillOpacity == 0.25)
        #expect(state.configuration.appearance.highlightStrokeWidth == 6)
        #expect(state.configuration.appearance.layoutGap == 4)
        #expect(state.configuration.appearance.renderTriggerAreas == true)
        #expect(state.configuration.appearance.triggerOpacity == 0.35)
        #expect(state.configuration.appearance.triggerGap == 3)
        #expect(controller.previewConfigurationForTesting.appearance.triggerOpacity == 0.35)
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
        reloadedConfiguration.appearance.triggerOpacity = 0.4

        state.reload(from: reloadedConfiguration)

        #expect(controller.previewConfigurationForTesting.appearance.renderTriggerAreas == true)
        #expect(controller.previewConfigurationForTesting.appearance.triggerOpacity == 0.4)
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

        controller.setTriggerOpacityForTesting(0.4)

        #expect(state.configuration.appearance.triggerOpacity == AppConfiguration.defaultValue.appearance.triggerOpacity)
        #expect(
            controller.previewConfigurationForTesting.appearance.triggerOpacity
                == AppConfiguration.defaultValue.appearance.triggerOpacity
        )
    }
}
