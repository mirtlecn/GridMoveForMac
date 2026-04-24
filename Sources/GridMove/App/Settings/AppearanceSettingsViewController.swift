import AppKit

@MainActor
final class AppearanceSettingsViewController: NSViewController {
    private let prototypeState: SettingsPrototypeState
    private let actionHandler: any SettingsActionHandling

    private let previewView = AppearancePreviewView()
    private let showHighlightCheckbox = makeCheckboxRow(title: "")
    private let fillOpacityControl = AppearanceSliderControl()
    private let strokeWidthControl = AppearanceStepperControl(minValue: 0, maxValue: 24, unit: "pt")
    private let strokeColorControl = AppearanceColorControl()
    private let layoutGapControl = AppearanceStepperControl(minValue: 0, maxValue: 24, unit: "pt")
    private let triggerHighlightModePopupButton = NSPopUpButton()
    private let triggerFillOpacityControl = AppearanceSliderControl()
    private let triggerGapControl = AppearanceStepperControl(minValue: 0, maxValue: 24, unit: "pt")
    private let triggerStrokeWidthControl = AppearanceStepperControl(minValue: 0, maxValue: 24, unit: "pt")
    private let triggerStrokeColorControl = AppearanceColorControl()

    init(prototypeState: SettingsPrototypeState, actionHandler: any SettingsActionHandling) {
        self.prototypeState = prototypeState
        self.actionHandler = actionHandler
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        configureControls()

        let contentStackView = makeSettingsPageStackView()
        previewView.translatesAutoresizingMaskIntoConstraints = false
        previewView.widthAnchor.constraint(equalToConstant: 420).isActive = true
        previewView.heightAnchor.constraint(equalToConstant: 260).isActive = true
        contentStackView.addArrangedSubview(makeCenteredContainer(for: previewView))

        let inlineTabsView = SettingsInlineTabsView(
            tabs: [
                SettingsInlineTab(
                    title: UICopy.settingsWindowAreaSectionTitle,
                    contentView: makeInlineTabContent(rows: [
                        makeCenteredLabeledControlRow(label: UICopy.settingsWindowGapLabel, control: layoutGapControl),
                        makeCenteredLabeledControlRow(label: UICopy.settingsHighlightWindowAreaTitle, control: showHighlightCheckbox),
                        makeCenteredLabeledControlRow(label: UICopy.settingsFillOpacityLabel, control: fillOpacityControl),
                        makeCenteredLabeledControlRow(label: UICopy.settingsStrokeWidthLabel, control: strokeWidthControl),
                        makeCenteredLabeledControlRow(label: UICopy.settingsStrokeColorLabel, control: strokeColorControl),
                    ])
                ),
                SettingsInlineTab(
                    title: UICopy.settingsTriggerAreaSectionTitle,
                    contentView: makeInlineTabContent(rows: [
                        makeCenteredLabeledControlRow(label: UICopy.settingsTriggerGapLabel, control: triggerGapControl),
                        makeCenteredLabeledControlRow(label: UICopy.settingsHighlightTriggerAreaTitle, control: triggerHighlightModePopupButton),
                        makeCenteredLabeledControlRow(label: UICopy.settingsFillOpacityLabel, control: triggerFillOpacityControl),
                        makeCenteredLabeledControlRow(label: UICopy.settingsStrokeWidthLabel, control: triggerStrokeWidthControl),
                        makeCenteredLabeledControlRow(label: UICopy.settingsStrokeColorLabel, control: triggerStrokeColorControl),
                    ])
                ),
            ]
        )
        contentStackView.addArrangedSubview(makeFullWidthContainer(for: inlineTabsView))
        view = makeSettingsPageContainerView(contentView: contentStackView)
        title = UICopy.settingsAppearanceTabTitle

        syncFromState()
        observePrototypeState()
    }

    private func configureControls() {
        showHighlightCheckbox.target = self
        showHighlightCheckbox.action = #selector(handleShowHighlightToggle(_:))

        fillOpacityControl.onPreviewChanged = { [weak self] value in
            self?.updatePreview { configuration in
                configuration.appearance.highlightFillOpacity = value
            }
        }
        fillOpacityControl.onValueCommitted = { [weak self] value in
            self?.applyMutation { configuration in
                configuration.appearance.highlightFillOpacity = value
            }
        }
        strokeWidthControl.onValueChanged = { [weak self] value in
            self?.applyMutation { configuration in
                configuration.appearance.highlightStrokeWidth = value
            }
        }
        strokeColorControl.onPreviewChanged = { [weak self] color in
            guard let rgbaColor = Self.makeRGBAColor(from: color) else {
                return
            }
            self?.updatePreview { configuration in
                configuration.appearance.highlightStrokeColor = rgbaColor
            }
        }
        strokeColorControl.onColorCommitted = { [weak self] color in
            guard let rgbaColor = Self.makeRGBAColor(from: color) else {
                return
            }
            self?.applyMutation { configuration in
                configuration.appearance.highlightStrokeColor = rgbaColor
            }
        }
        layoutGapControl.onValueChanged = { [weak self] value in
            self?.applyMutation { configuration in
                configuration.appearance.layoutGap = value
            }
        }

        triggerHighlightModePopupButton.controlSize = .small
        triggerHighlightModePopupButton.addItems(withTitles: [
            UICopy.settingsAllValue,
            UICopy.settingsCurrentValue,
            UICopy.settingsNoneValue,
        ])
        triggerHighlightModePopupButton.target = self
        triggerHighlightModePopupButton.action = #selector(handleTriggerHighlightModeChange(_:))

        triggerFillOpacityControl.onPreviewChanged = { [weak self] value in
            self?.updatePreview { configuration in
                configuration.appearance.triggerFillOpacity = value
            }
        }
        triggerFillOpacityControl.onValueCommitted = { [weak self] value in
            self?.applyMutation { configuration in
                configuration.appearance.triggerFillOpacity = value
            }
        }

        triggerGapControl.onValueChanged = { [weak self] value in
            self?.applyMutation { configuration in
                configuration.appearance.triggerGap = value
            }
        }
        triggerStrokeWidthControl.onValueChanged = { [weak self] value in
            self?.applyMutation { configuration in
                configuration.appearance.triggerStrokeWidth = value
            }
        }
        triggerStrokeColorControl.onPreviewChanged = { [weak self] color in
            guard let rgbaColor = Self.makeRGBAColor(from: color) else {
                return
            }
            self?.updatePreview { configuration in
                configuration.appearance.triggerStrokeColor = rgbaColor
            }
        }
        triggerStrokeColorControl.onColorCommitted = { [weak self] color in
            guard let rgbaColor = Self.makeRGBAColor(from: color) else {
                return
            }
            self?.applyMutation { configuration in
                configuration.appearance.triggerStrokeColor = rgbaColor
            }
        }
    }

    private func observePrototypeState() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePrototypeStateDidChange(_:)),
            name: .settingsPrototypeStateDidChange,
            object: prototypeState
        )
    }

    private func syncFromState() {
        let configuration = prototypeState.configuration
        let appearance = configuration.appearance

        showHighlightCheckbox.state = appearance.renderWindowHighlight ? .on : .off
        fillOpacityControl.setValue(appearance.highlightFillOpacity)
        strokeWidthControl.setValue(appearance.highlightStrokeWidth)
        strokeColorControl.setColor(appearance.highlightStrokeColor.nsColor)
        layoutGapControl.setValue(appearance.effectiveLayoutGap)

        triggerHighlightModePopupButton.selectItem(withTitle: title(for: appearance.triggerHighlightMode))
        triggerFillOpacityControl.setValue(appearance.triggerFillOpacity)
        triggerGapControl.setValue(appearance.triggerGap)
        triggerStrokeWidthControl.setValue(appearance.triggerStrokeWidth)
        triggerStrokeColorControl.setColor(appearance.triggerStrokeColor.nsColor)

        previewView.updateConfiguration(configuration)
    }

    @objc
    private func handlePrototypeStateDidChange(_ notification: Notification) {
        syncFromState()
    }

    private func applyMutation(_ mutate: (inout AppConfiguration) -> Void) {
        _ = prototypeState.applyImmediateMutation(using: actionHandler, mutate)
    }

    private func updatePreview(_ mutate: (inout AppConfiguration) -> Void) {
        var previewConfiguration = prototypeState.configuration
        mutate(&previewConfiguration)
        previewView.updateConfiguration(previewConfiguration)
    }

    @objc
    private func handleShowHighlightToggle(_ sender: NSButton) {
        applyMutation { configuration in
            configuration.appearance.renderWindowHighlight = sender.state == .on
        }
    }

    @objc
    private func handleTriggerHighlightModeChange(_ sender: NSPopUpButton) {
        applyMutation { configuration in
            configuration.appearance.triggerHighlightMode = self.selectedTriggerHighlightMode()
        }
    }

    private func selectedTriggerHighlightMode() -> TriggerHighlightMode {
        switch triggerHighlightModePopupButton.selectedItem?.title {
        case UICopy.settingsAllValue:
            return .all
        case UICopy.settingsCurrentValue:
            return .current
        default:
            return .none
        }
    }

    private func title(for mode: TriggerHighlightMode) -> String {
        switch mode {
        case .all:
            return UICopy.settingsAllValue
        case .current:
            return UICopy.settingsCurrentValue
        case .none:
            return UICopy.settingsNoneValue
        }
    }

    private static func makeRGBAColor(from color: NSColor) -> RGBAColor? {
        guard let deviceColor = color.usingColorSpace(.deviceRGB) else {
            return nil
        }

        return RGBAColor(
            red: Double(deviceColor.redComponent),
            green: Double(deviceColor.greenComponent),
            blue: Double(deviceColor.blueComponent),
            alpha: Double(deviceColor.alphaComponent)
        )
    }
}

@MainActor
private final class AppearanceSliderControl: NSView {
    var onPreviewChanged: ((Double) -> Void)?
    var onValueCommitted: ((Double) -> Void)?

    private let slider = NSSlider(value: 0, minValue: 0, maxValue: 1, target: nil, action: nil)
    private let valueLabel = makeValueLabel("0%")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        slider.controlSize = .small
        slider.target = self
        slider.action = #selector(handleSliderChanged(_:))
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.widthAnchor.constraint(equalToConstant: 160).isActive = true

        let stackView = makeHorizontalGroup(spacing: 10)
        stackView.alignment = .centerY
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(slider)
        stackView.addArrangedSubview(valueLabel)
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func setValue(_ value: Double) {
        slider.doubleValue = value
        valueLabel.stringValue = Self.percentageString(value)
    }

    @objc
    private func handleSliderChanged(_ sender: NSSlider) {
        let value = sender.doubleValue
        valueLabel.stringValue = Self.percentageString(value)
        onPreviewChanged?(value)

        let eventType = NSApp.currentEvent?.type
        if eventType != .leftMouseDragged {
            onValueCommitted?(value)
        }
    }

    private static func percentageString(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}

@MainActor
private final class AppearanceStepperControl: NSView {
    var onValueChanged: ((Int) -> Void)?

    private let valueControl: SettingsIntegerStepperControl
    private let unitLabel: NSTextField

    init(minValue: Int, maxValue: Int, unit: String) {
        valueControl = SettingsIntegerStepperControl(value: minValue, minValue: minValue, maxValue: maxValue)
        unitLabel = makeFieldLabel(unit)
        super.init(frame: .zero)
        valueControl.onValueChanged = { [weak self] value in
            self?.onValueChanged?(value)
        }

        let stackView = makeHorizontalGroup(spacing: 8)
        stackView.alignment = .centerY
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(valueControl)
        stackView.addArrangedSubview(unitLabel)
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func setValue(_ value: Int) {
        valueControl.setValue(value)
    }
}

@MainActor
private final class AppearanceColorControl: NSView {
    var onPreviewChanged: ((NSColor) -> Void)?
    var onColorCommitted: ((NSColor) -> Void)?

    private let colorWell = NSColorWell()
    private var pendingColor: NSColor?
    private var isObservingColorPanelClose = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        colorWell.target = self
        colorWell.action = #selector(handleColorChanged(_:))
        colorWell.translatesAutoresizingMaskIntoConstraints = false
        colorWell.widthAnchor.constraint(equalToConstant: 44).isActive = true
        colorWell.heightAnchor.constraint(equalToConstant: 22).isActive = true
        addSubview(colorWell)

        NSLayoutConstraint.activate([
            colorWell.leadingAnchor.constraint(equalTo: leadingAnchor),
            colorWell.trailingAnchor.constraint(equalTo: trailingAnchor),
            colorWell.topAnchor.constraint(equalTo: topAnchor),
            colorWell.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    deinit {
        if isObservingColorPanelClose {
            NotificationCenter.default.removeObserver(self)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func setColor(_ color: NSColor) {
        colorWell.color = color
        pendingColor = nil
    }

    @objc
    private func handleColorChanged(_ sender: NSColorWell) {
        pendingColor = sender.color
        onPreviewChanged?(sender.color)
        startObservingColorPanelClose()
    }

    private func startObservingColorPanelClose() {
        guard isObservingColorPanelClose == false else {
            return
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleColorPanelWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: NSColorPanel.shared
        )
        isObservingColorPanelClose = true
    }

    @objc
    private func handleColorPanelWillClose(_ notification: Notification) {
        if let pendingColor {
            onColorCommitted?(pendingColor)
        }
        pendingColor = nil

        if isObservingColorPanelClose {
            NotificationCenter.default.removeObserver(
                self,
                name: NSWindow.willCloseNotification,
                object: NSColorPanel.shared
            )
            isObservingColorPanelClose = false
        }
    }
}

extension AppearanceSettingsViewController {
    func setRenderWindowHighlightForTesting(_ isEnabled: Bool) {
        showHighlightCheckbox.state = isEnabled ? .on : .off
        handleShowHighlightToggle(showHighlightCheckbox)
    }

    func setHighlightFillOpacityForTesting(_ value: Double) {
        fillOpacityControl.onPreviewChanged?(value)
        fillOpacityControl.onValueCommitted?(value)
    }

    func previewHighlightFillOpacityForTesting(_ value: Double) {
        fillOpacityControl.onPreviewChanged?(value)
    }

    func commitHighlightFillOpacityForTesting(_ value: Double) {
        fillOpacityControl.onValueCommitted?(value)
    }

    func setHighlightStrokeWidthForTesting(_ value: Int) {
        strokeWidthControl.onValueChanged?(value)
    }

    func previewHighlightStrokeColorForTesting(_ color: NSColor) {
        strokeColorControl.onPreviewChanged?(color)
    }

    func commitHighlightStrokeColorForTesting(_ color: NSColor) {
        strokeColorControl.onColorCommitted?(color)
    }

    func setLayoutGapForTesting(_ value: Int) {
        layoutGapControl.onValueChanged?(value)
    }

    func setTriggerHighlightModeForTesting(_ mode: TriggerHighlightMode) {
        triggerHighlightModePopupButton.selectItem(withTitle: title(for: mode))
        handleTriggerHighlightModeChange(triggerHighlightModePopupButton)
    }

    func setTriggerFillOpacityForTesting(_ value: Double) {
        triggerFillOpacityControl.onPreviewChanged?(value)
        triggerFillOpacityControl.onValueCommitted?(value)
    }

    func setTriggerGapForTesting(_ value: Int) {
        triggerGapControl.onValueChanged?(value)
    }

    func setTriggerStrokeWidthForTesting(_ value: Int) {
        triggerStrokeWidthControl.onValueChanged?(value)
    }

    func previewTriggerStrokeColorForTesting(_ color: NSColor) {
        triggerStrokeColorControl.onPreviewChanged?(color)
    }

    func commitTriggerStrokeColorForTesting(_ color: NSColor) {
        triggerStrokeColorControl.onColorCommitted?(color)
    }

    var previewResolvedSlotsForTesting: [ResolvedTriggerSlot] {
        previewView.resolvedSlotsForTesting
    }

    var previewHighlightFrameForTesting: CGRect? {
        previewView.highlightFrameForTesting
    }

    var previewConfigurationForTesting: AppConfiguration {
        previewView.configurationForTesting
    }

    static func makeRGBAColorForTesting(_ color: NSColor) -> RGBAColor? {
        makeRGBAColor(from: color)
    }
}
