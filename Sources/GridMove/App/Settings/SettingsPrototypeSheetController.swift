import AppKit

@MainActor
protocol SettingsPrototypeSheetValidating: AnyObject {
    var isConfirmationEnabled: Bool { get }
    var onConfirmationStateChanged: (() -> Void)? { get set }
}

@MainActor
protocol SettingsPrototypeSheetDisposable: AnyObject {
    func prepareForDismissal()
}

@MainActor
final class SettingsPrototypeSheetController: NSViewController {
    private let sheetTitle: String
    private let message: String?
    private let bodyView: NSView
    private let confirmButtonTitle: String
    private let onConfirm: () -> Void
    private let confirmButton = NSButton(title: "", target: nil, action: nil)
    private weak var validatingBodyView: (any SettingsPrototypeSheetValidating)?
    private weak var disposableBodyView: (any SettingsPrototypeSheetDisposable)?

    init(
        title: String,
        message: String? = nil,
        bodyView: NSView,
        confirmButtonTitle: String,
        onConfirm: @escaping () -> Void
    ) {
        self.sheetTitle = title
        self.message = message
        self.bodyView = bodyView
        self.confirmButtonTitle = confirmButtonTitle
        self.onConfirm = onConfirm
        self.validatingBodyView = bodyView as? (any SettingsPrototypeSheetValidating)
        self.disposableBodyView = bodyView as? (any SettingsPrototypeSheetDisposable)
        super.init(nibName: nil, bundle: nil)
        preferredContentSize = NSSize(width: 420, height: 240)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        let contentStackView = makeSettingsPageStackView()
        contentStackView.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)
        contentStackView.spacing = 16
        contentStackView.addArrangedSubview(makeSheetHeaderView())

        contentStackView.addArrangedSubview(makeFullWidthContainer(for: bodyView))
        contentStackView.addArrangedSubview(makeSheetButtonsRow())
        view = makeSettingsPageContainerView(contentView: contentStackView)
        configureValidation()
    }

    private func makeSheetHeaderView() -> NSView {
        let headerStackView = makeVerticalGroup(spacing: 6)
        headerStackView.addArrangedSubview(makeSectionTitleLabel(sheetTitle))

        if let message, !message.isEmpty {
            headerStackView.addArrangedSubview(makeSecondaryLabel(message))
        }

        return headerStackView
    }

    @objc
    private func handleCancel(_ sender: NSButton) {
        disposableBodyView?.prepareForDismissal()
        dismiss(self)
    }

    @objc
    private func handleConfirm(_ sender: NSButton) {
        onConfirm()
        disposableBodyView?.prepareForDismissal()
        dismiss(self)
    }

    private func makeSheetButtonsRow() -> NSView {
        let cancelButton = NSButton(title: UICopy.settingsCancelButtonTitle, target: self, action: #selector(handleCancel(_:)))
        cancelButton.bezelStyle = .rounded

        confirmButton.title = confirmButtonTitle
        confirmButton.target = self
        confirmButton.action = #selector(handleConfirm(_:))
        confirmButton.bezelStyle = .rounded
        confirmButton.keyEquivalent = "\r"

        let row = makeHorizontalGroup(spacing: 8)
        row.addArrangedSubview(NSView())
        row.addArrangedSubview(cancelButton)
        row.addArrangedSubview(confirmButton)
        return row
    }

    private func configureValidation() {
        guard let validatingBodyView else {
            return
        }

        validatingBodyView.onConfirmationStateChanged = { [weak self, weak validatingBodyView] in
            self?.confirmButton.isEnabled = validatingBodyView?.isConfirmationEnabled ?? true
        }
        confirmButton.isEnabled = validatingBodyView.isConfirmationEnabled
    }
}
