import AppKit

struct SettingsInlineTab {
    let title: String
    let contentView: NSView
}

@MainActor
private final class SettingsInlineTabPanelView: NSVisualEffectView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        updateLayerAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateLayerAppearance()
    }

    private func updateLayerAppearance() {
        material = .underWindowBackground
        blendingMode = .withinWindow
        state = .followsWindowActiveState
        layer?.cornerRadius = SettingsLayoutMetrics.inlineTabPanelCornerRadius
        layer?.masksToBounds = true
        layer?.borderWidth = 0
    }
}

@MainActor
private final class SettingsInlineTabBridgeView: NSVisualEffectView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        updateLayerAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateLayerAppearance()
    }

    private func updateLayerAppearance() {
        material = .underWindowBackground
        blendingMode = .withinWindow
        state = .followsWindowActiveState
        layer?.cornerRadius = SettingsLayoutMetrics.inlineTabPanelCornerRadius
        layer?.masksToBounds = true
    }
}

@MainActor
final class SettingsInlineTabsView: NSView {
    private let segmentedControl: NSSegmentedControl
    private let contentStackView = makeVerticalGroup(spacing: 0)
    private let contentBackgroundView = SettingsInlineTabPanelView()
    private let segmentedBridgeView = SettingsInlineTabBridgeView()
    private let tabViews: [NSView]
    var onSelectionChanged: ((Int) -> Void)?

    init(tabs: [SettingsInlineTab], selectedIndex: Int = 0) {
        self.tabViews = tabs.map(\.contentView)
        self.segmentedControl = NSSegmentedControl(
            labels: tabs.map(\.title),
            trackingMode: .selectOne,
            target: nil,
            action: nil
        )
        super.init(frame: .zero)

        segmentedControl.segmentStyle = .rounded
        segmentedControl.selectedSegment = max(0, min(selectedIndex, tabs.count - 1))
        segmentedControl.target = self
        segmentedControl.action = #selector(handleSegmentChange(_:))
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false

        segmentedBridgeView.translatesAutoresizingMaskIntoConstraints = false
        contentBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentBackgroundView.addSubview(contentStackView)
        addSubview(contentBackgroundView)
        addSubview(segmentedBridgeView)
        addSubview(segmentedControl)

        NSLayoutConstraint.activate([
            contentBackgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentBackgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentBackgroundView.topAnchor.constraint(equalTo: segmentedControl.centerYAnchor),
            contentBackgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
            segmentedBridgeView.leadingAnchor.constraint(equalTo: segmentedControl.leadingAnchor, constant: -SettingsLayoutMetrics.inlineTabBridgeHorizontalInset),
            segmentedBridgeView.trailingAnchor.constraint(equalTo: segmentedControl.trailingAnchor, constant: SettingsLayoutMetrics.inlineTabBridgeHorizontalInset),
            segmentedBridgeView.topAnchor.constraint(equalTo: segmentedControl.topAnchor, constant: -SettingsLayoutMetrics.inlineTabBridgeVerticalInset),
            segmentedBridgeView.bottomAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: SettingsLayoutMetrics.inlineTabBridgeVerticalInset),
            segmentedControl.centerXAnchor.constraint(equalTo: centerXAnchor),
            segmentedControl.topAnchor.constraint(equalTo: topAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: contentBackgroundView.leadingAnchor, constant: SettingsLayoutMetrics.inlineTabPanelInsets.left),
            contentStackView.trailingAnchor.constraint(lessThanOrEqualTo: contentBackgroundView.trailingAnchor, constant: -SettingsLayoutMetrics.inlineTabPanelInsets.right),
            contentStackView.topAnchor.constraint(equalTo: contentBackgroundView.topAnchor, constant: SettingsLayoutMetrics.inlineTabPanelInsets.top),
            contentStackView.bottomAnchor.constraint(equalTo: contentBackgroundView.bottomAnchor, constant: -SettingsLayoutMetrics.inlineTabPanelInsets.bottom),
        ])

        for (index, tabView) in tabViews.enumerated() {
            tabView.isHidden = index != segmentedControl.selectedSegment
            contentStackView.addArrangedSubview(tabView)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    @objc
    private func handleSegmentChange(_ sender: NSSegmentedControl) {
        for (index, tabView) in tabViews.enumerated() {
            tabView.isHidden = index != sender.selectedSegment
        }
        onSelectionChanged?(sender.selectedSegment)
    }
}
