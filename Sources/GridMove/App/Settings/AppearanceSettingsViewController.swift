import AppKit

@MainActor
final class AppearanceSettingsViewController: NSViewController {
    override func loadView() {
        let configuration = AppConfiguration.defaultValue

        let contentStackView = makeSettingsPageStackView()

        let previewView = AppearancePreviewView(configuration: configuration)
        previewView.translatesAutoresizingMaskIntoConstraints = false
        previewView.widthAnchor.constraint(equalToConstant: 420).isActive = true
        previewView.heightAnchor.constraint(equalToConstant: 260).isActive = true
        contentStackView.addArrangedSubview(makeCenteredContainer(for: previewView))

        let inlineTabsView = SettingsInlineTabsView(
            tabs: [
                SettingsInlineTab(
                    title: UICopy.settingsWindowHighlightSectionTitle,
                    contentView: makeInlineTabContent(rows: [
                        makeLabeledControlRow(
                            label: UICopy.settingsShowHighlightTitle,
                            control: makeReadonlyCheckboxControl(isOn: configuration.appearance.renderWindowHighlight)
                        ),
                        makeLabeledControlRow(
                            label: UICopy.settingsFillOpacityLabel,
                            control: makeReadonlySliderControl(
                                value: configuration.appearance.highlightFillOpacity,
                                minValue: 0,
                                maxValue: 1,
                                displayValue: percentageString(configuration.appearance.highlightFillOpacity)
                            )
                        ),
                        makeLabeledControlRow(
                            label: UICopy.settingsStrokeWidthLabel,
                            control: makeNumericStepperControl(
                                value: configuration.appearance.highlightStrokeWidth,
                                unit: "pt",
                                minValue: 0,
                                maxValue: 24
                            )
                        ),
                        makeLabeledControlRow(
                            label: UICopy.settingsStrokeColorLabel,
                            control: makeReadonlyColorControl(color: configuration.appearance.highlightStrokeColor.nsColor)
                        ),
                        makeLabeledControlRow(
                            label: UICopy.settingsLayoutGapLabel,
                            control: makeNumericStepperControl(
                                value: configuration.appearance.effectiveLayoutGap,
                                unit: "pt",
                                minValue: 0,
                                maxValue: 24
                            )
                        ),
                    ])
                ),
                SettingsInlineTab(
                    title: UICopy.settingsTriggerOverlaySectionTitle,
                    contentView: makeInlineTabContent(rows: [
                        makeLabeledControlRow(
                            label: UICopy.settingsShowOverlayTitle,
                            control: makeReadonlyCheckboxControl(isOn: configuration.appearance.renderTriggerAreas)
                        ),
                        makeLabeledControlRow(
                            label: UICopy.settingsFillOpacityLabel,
                            control: makeReadonlySliderControl(
                                value: configuration.appearance.triggerOpacity,
                                minValue: 0,
                                maxValue: 1,
                                displayValue: percentageString(configuration.appearance.triggerOpacity)
                            )
                        ),
                        makeLabeledControlRow(
                            label: UICopy.settingsGapLabel,
                            control: makeNumericStepperControl(
                                value: configuration.appearance.triggerGap,
                                unit: "pt",
                                minValue: 0,
                                maxValue: 24
                            )
                        ),
                        makeLabeledControlRow(
                            label: UICopy.settingsStrokeColorLabel,
                            control: makeReadonlyColorControl(color: configuration.appearance.triggerStrokeColor.nsColor)
                        ),
                    ])
                ),
            ]
        )
        contentStackView.addArrangedSubview(makeFullWidthContainer(for: inlineTabsView))
        view = makeSettingsPageContainerView(contentView: contentStackView)
        title = UICopy.settingsAppearanceTabTitle
    }

    private func makeReadonlySliderControl(value: Double, minValue: Double, maxValue: Double, displayValue: String) -> NSView {
        let slider = NSSlider(value: value, minValue: minValue, maxValue: maxValue, target: nil, action: nil)
        slider.controlSize = .small
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.widthAnchor.constraint(equalToConstant: 160).isActive = true

        let valueLabel = makeValueLabel(displayValue)

        let stackView = makeHorizontalGroup(spacing: 10)
        stackView.alignment = .centerY
        stackView.addArrangedSubview(slider)
        stackView.addArrangedSubview(valueLabel)
        return stackView
    }

    private func makeReadonlyCheckboxControl(isOn: Bool) -> NSButton {
        let checkbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
        checkbox.state = isOn ? .on : .off
        return checkbox
    }

    private func makeReadonlyColorControl(color: NSColor) -> NSColorWell {
        let colorWell = NSColorWell()
        colorWell.color = color
        colorWell.widthAnchor.constraint(equalToConstant: 44).isActive = true
        colorWell.heightAnchor.constraint(equalToConstant: 22).isActive = true
        return colorWell
    }

    private func percentageString(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}
