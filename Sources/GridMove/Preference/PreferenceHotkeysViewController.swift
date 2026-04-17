import AppKit

@MainActor
final class PreferenceHotkeysViewController: NSViewController {
    private let viewModel: PreferenceViewModel
    private let leftColumnStackView = NSStackView()
    private let rightColumnStackView = NSStackView()

    init(viewModel: PreferenceViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        title = UICopy.hotkeysSectionTitle
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var rowCountForTesting: Int {
        viewModel.hotkeyRows.count
    }

    override func loadView() {
        let rootView = NSView()
        configureColumnStack(leftColumnStackView)
        configureColumnStack(rightColumnStackView)

        let columnsStackView = NSStackView(views: [leftColumnStackView, rightColumnStackView])
        columnsStackView.orientation = .horizontal
        columnsStackView.alignment = .top
        columnsStackView.distribution = .fillEqually
        columnsStackView.spacing = 76
        columnsStackView.translatesAutoresizingMaskIntoConstraints = false
        rootView.addSubview(columnsStackView)
        NSLayoutConstraint.activate([
            columnsStackView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 56),
            columnsStackView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -56),
            columnsStackView.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 42),
            columnsStackView.bottomAnchor.constraint(lessThanOrEqualTo: rootView.bottomAnchor, constant: -42),
        ])

        view = rootView
        reloadFromViewModel()
    }

    func reloadFromViewModel() {
        rebuildPrimaryColumns()
    }

    private func configureColumnStack(_ stackView: NSStackView) {
        stackView.orientation = .vertical
        stackView.alignment = .trailing
        stackView.spacing = 14
    }

    private func rebuildPrimaryColumns() {
        clearArrangedSubviews(in: leftColumnStackView)
        clearArrangedSubviews(in: rightColumnStackView)

        let groups = viewModel.hotkeyGroups
        let splitIndex = Int(ceil(Double(groups.count) / 2.0))
        let leftGroups = Array(groups.prefix(splitIndex))
        let rightGroups = Array(groups.dropFirst(splitIndex))

        for group in leftGroups {
            leftColumnStackView.addArrangedSubview(makePrimaryRowView(for: group))
        }

        for group in rightGroups {
            rightColumnStackView.addArrangedSubview(makePrimaryRowView(for: group))
        }
    }

    private func makePrimaryRowView(for group: PreferenceViewModel.HotkeyGroup) -> NSView {
        PreferencePrimaryHotkeyRowView(
            title: viewModel.hotkeyGridTitle(for: group.action),
            action: group.action,
            shortcut: group.primaryRow.shortcut,
            configuration: viewModel.configuration,
            onShortcutChange: { [weak self] shortcut in
                self?.viewModel.updateHotkeyShortcut(id: group.primaryRow.id, shortcut: shortcut)
                self?.reloadFromViewModel()
            }
        )
    }

    private func clearArrangedSubviews(in stackView: NSStackView) {
        stackView.arrangedSubviews.forEach { arrangedSubview in
            stackView.removeArrangedSubview(arrangedSubview)
            arrangedSubview.removeFromSuperview()
        }
    }
}

@MainActor
private final class PreferencePrimaryHotkeyRowView: NSView {
    init(
        title: String,
        action: HotkeyAction,
        shortcut: KeyboardShortcut?,
        configuration: AppConfiguration,
        onShortcutChange: @escaping (KeyboardShortcut?) -> Void
    ) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let actionLabel = NSTextField(labelWithString: title)
        actionLabel.font = NSFont.systemFont(ofSize: 15, weight: .medium)
        actionLabel.alignment = .right
        actionLabel.lineBreakMode = .byTruncatingTail
        actionLabel.translatesAutoresizingMaskIntoConstraints = false
        actionLabel.widthAnchor.constraint(equalToConstant: 150).isActive = true

        let iconView = PreferenceHotkeyImageView(action: action, configuration: configuration)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 30).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 20).isActive = true

        let shortcutView = PreferenceShortcutPillView(
            shortcut: shortcut,
            onShortcutChange: onShortcutChange
        )
        shortcutView.translatesAutoresizingMaskIntoConstraints = false
        shortcutView.widthAnchor.constraint(equalToConstant: 224).isActive = true

        let labelStackView = NSStackView(views: [actionLabel, iconView])
        labelStackView.orientation = .horizontal
        labelStackView.alignment = .centerY
        labelStackView.spacing = 12

        let contentStackView = NSStackView(views: [labelStackView, shortcutView])
        contentStackView.orientation = .horizontal
        contentStackView.alignment = .centerY
        contentStackView.spacing = 20
        contentStackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(contentStackView)
        NSLayoutConstraint.activate([
            contentStackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentStackView.topAnchor.constraint(equalTo: topAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@MainActor
private final class PreferenceShortcutPillView: NSView {
    private var actionSleeves: [TargetActionSleeve] = []

    init(
        shortcut: KeyboardShortcut?,
        onShortcutChange: @escaping (KeyboardShortcut?) -> Void
    ) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let recorder = PreferenceShortcutRecorderControl()
        recorder.shortcut = shortcut
        recorder.onShortcutChange = onShortcutChange
        recorder.alignment = .center
        recorder.translatesAutoresizingMaskIntoConstraints = false
        recorder.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let clearButton = NSButton(title: "×", target: nil, action: nil)
        clearButton.isBordered = false
        clearButton.font = NSFont.systemFont(ofSize: 17, weight: .medium)
        clearButton.contentTintColor = .labelColor
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.isHidden = shortcut == nil
        clearButton.setContentHuggingPriority(.required, for: .horizontal)

        let clearSleeve = TargetActionSleeve { _ in
            onShortcutChange(nil)
        }
        actionSleeves.append(clearSleeve)
        clearButton.target = clearSleeve
        clearButton.action = #selector(TargetActionSleeve.invoke(_:))

        let backgroundView = PreferenceShortcutCapsuleBackgroundView()
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(recorder)

        let clearBackgroundView = PreferenceShortcutCapsuleBackgroundView()
        clearBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        clearBackgroundView.isHidden = shortcut == nil
        clearBackgroundView.addSubview(clearButton)

        let stackView = NSStackView(views: [backgroundView, clearBackgroundView])
        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stackView)

        let clearWidthConstraint = clearBackgroundView.widthAnchor.constraint(equalToConstant: 40)
        clearWidthConstraint.isActive = true

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 46),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),

            recorder.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor, constant: 18),
            recorder.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor, constant: -18),
            recorder.topAnchor.constraint(equalTo: backgroundView.topAnchor, constant: 6),
            recorder.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor, constant: -6),

            clearButton.centerXAnchor.constraint(equalTo: clearBackgroundView.centerXAnchor),
            clearButton.centerYAnchor.constraint(equalTo: clearBackgroundView.centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@MainActor
private final class PreferenceHotkeyImageView: NSImageView {
    init(action: HotkeyAction, configuration: AppConfiguration) {
        super.init(frame: .zero)
        image = PreferenceHotkeyIconCatalog.image(for: action, configuration: configuration)
        imageAlignment = .alignCenter
        imageScaling = .scaleAxesIndependently
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@MainActor
private final class PreferenceShortcutCapsuleBackgroundView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: 16, yRadius: 16)
        let gradient = NSGradient(
            starting: NSColor(calibratedWhite: 0.94, alpha: 1),
            ending: NSColor(calibratedWhite: 0.89, alpha: 1)
        )
        gradient?.draw(in: path, angle: 90)

        NSColor(calibratedWhite: 0.80, alpha: 0.7).setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}

@MainActor
private final class TargetActionSleeve: NSObject {
    private let handler: (NSControl) -> Void

    init(handler: @escaping (NSControl) -> Void) {
        self.handler = handler
    }

    @objc func invoke(_ sender: NSControl) {
        handler(sender)
    }
}
