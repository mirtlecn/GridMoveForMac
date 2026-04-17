import AppKit

@MainActor
final class PreferencePlaceholderViewController: NSViewController {
    private let displayTitle: String
    private let message: String

    init(title: String, message: String) {
        self.displayTitle = title
        self.message = message
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let container = NSView()
        container.wantsLayer = true

        let titleLabel = NSTextField(labelWithString: displayTitle)
        titleLabel.font = NSFont.systemFont(ofSize: 24, weight: .semibold)

        let messageLabel = NSTextField(wrappingLabelWithString: message)
        messageLabel.font = NSFont.systemFont(ofSize: 13)
        messageLabel.textColor = .secondaryLabelColor
        messageLabel.maximumNumberOfLines = 0

        let stackView = NSStackView(views: [titleLabel, messageLabel])
        stackView.orientation = NSUserInterfaceLayoutOrientation.vertical
        stackView.alignment = NSLayoutConstraint.Attribute.leading
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 32),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -32),
            stackView.topAnchor.constraint(equalTo: container.topAnchor, constant: 32),
        ])

        view = container
    }
}
