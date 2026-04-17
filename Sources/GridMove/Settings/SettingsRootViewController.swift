import AppKit

@MainActor
final class SettingsRootViewController: NSViewController {
    private var currentController: NSViewController?

    override func loadView() {
        view = NSView()
    }

    func showSection(_ section: SettingsViewModel.Section) {
        let nextController = makeViewController(for: section)
        transition(to: nextController)
    }

    private func makeViewController(for section: SettingsViewModel.Section) -> NSViewController {
        switch section {
        case .general:
            return GeneralSettingsMockViewController()
        case .layouts:
            return PlaceholderSettingsViewController(
                title: UICopy.layoutsSectionTitle,
                message: "Layouts will move into the native settings shell after the General direction is approved."
            )
        case .appearance:
            return PlaceholderSettingsViewController(
                title: UICopy.appearanceSectionTitle,
                message: "Appearance will move into the native settings shell after the General direction is approved."
            )
        case .hotkeys:
            return PlaceholderSettingsViewController(
                title: UICopy.hotkeysSectionTitle,
                message: "Hotkeys will move into the native settings shell after the General direction is approved."
            )
        case .about:
            return PlaceholderSettingsViewController(
                title: UICopy.aboutSectionTitle,
                message: "About will be reconnected after the first-pass native General page is approved."
            )
        }
    }

    private func transition(to nextController: NSViewController) {
        let previousController = currentController
        currentController = nextController

        addChild(nextController)
        nextController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(nextController.view)

        NSLayoutConstraint.activate([
            nextController.view.topAnchor.constraint(equalTo: view.topAnchor),
            nextController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            nextController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            nextController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        previousController?.view.removeFromSuperview()
        previousController?.removeFromParent()
    }
}

private final class PlaceholderSettingsViewController: NSViewController {
    private let titleText: String
    private let message: String

    init(title: String, message: String) {
        titleText = title
        self.message = message
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()

        let titleLabel = NSTextField(labelWithString: titleText)
        titleLabel.font = .systemFont(ofSize: 24, weight: .semibold)

        let messageLabel = NSTextField(wrappingLabelWithString: message)
        messageLabel.font = .systemFont(ofSize: 13)
        messageLabel.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [titleLabel, messageLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 36),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 36),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -36),
        ])
    }
}
