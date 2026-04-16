import AppKit

@MainActor
final class OnboardingWindowController: NSWindowController {
    private let onRequestAccessibility: () -> Void

    init(onRequestAccessibility: @escaping () -> Void) {
        self.onRequestAccessibility = onRequestAccessibility

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = UICopy.onboardingWindowTitle
        super.init(window: window)
        buildInterface()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    private func buildInterface() {
        guard let contentView = window?.contentView else {
            return
        }

        let titleLabel = NSTextField(labelWithString: UICopy.onboardingTitle)
        titleLabel.font = .boldSystemFont(ofSize: 18)

        let bodyLabel = NSTextField(wrappingLabelWithString: UICopy.onboardingBody)
        bodyLabel.textColor = .secondaryLabelColor

        let requestButton = NSButton(title: UICopy.requestAccessibilityAccess, target: self, action: #selector(requestAccessibility))
        let openSettingsButton = NSButton(title: UICopy.openAccessibilitySettings, target: self, action: #selector(openAccessibilitySettings))

        let buttonRow = NSStackView(views: [requestButton, openSettingsButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 12

        let stack = NSStackView(views: [titleLabel, bodyLabel, buttonRow])
        stack.orientation = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -24),
        ])
    }

    @objc private func requestAccessibility() {
        onRequestAccessibility()
    }

    @objc private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
