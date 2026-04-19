import AppKit

@MainActor
final class AboutSettingsViewController: NSViewController {
    private enum AboutLink {
        static let authorURLString = "https://github.com/mirtlecn"
        static let projectURLString = "https://github.com/mirtlecn/GridMoveForMac"
    }

    private let prototypeState: SettingsPrototypeState
    private let actionHandler: any SettingsActionHandling

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
        let contentStackView = makeSettingsPageStackView()
        contentStackView.addArrangedSubview(makeSectionTitleLabel(UICopy.appName))
        contentStackView.addArrangedSubview(
            makeLabeledViewGrid(rows: [
                (UICopy.settingsVersionLabel, makeValueLabel(currentVersionString())),
                (UICopy.settingsAuthorLabel, makeAuthorLinkButton()),
                (UICopy.settingsLinkLabel, makeProjectLinkButton()),
                (UICopy.settingsConfigFolderLabel, makeConfigFolderButton()),
            ])
        )
        contentStackView.addArrangedSubview(
            makeSettingsSection(
                title: UICopy.settingsAdvancedSectionTitle,
                rows: [makeAdvancedButtonsRow()]
            )
        )

        view = makeSettingsPageContainerView(contentView: contentStackView)
        title = UICopy.settingsAboutTabTitle
    }

    private func currentVersionString() -> String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let buildVersion = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String
        return Self.formattedVersionString(shortVersion: shortVersion, buildVersion: buildVersion)
    }

    nonisolated static func formattedVersionString(shortVersion: String?, buildVersion: String?) -> String {
        switch (shortVersion, buildVersion) {
        case let (shortVersion?, buildVersion?) where !shortVersion.isEmpty && !buildVersion.isEmpty:
            return "\(shortVersion)(\(buildVersion))"
        case let (shortVersion?, _) where !shortVersion.isEmpty:
            return shortVersion
        case let (_, buildVersion?) where !buildVersion.isEmpty:
            return buildVersion
        default:
            return "Development build"
        }
    }

    private func currentAuthorString() -> String {
        guard let copyright = Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String,
              !copyright.isEmpty else {
            return "Mirtle"
        }

        if let range = copyright.range(of: "Created by ") {
            let authorSegment = copyright[range.upperBound...]
            if let endIndex = authorSegment.firstIndex(of: "(") {
                let author = authorSegment[..<endIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                if !author.isEmpty {
                    return author
                }
            }

            let author = authorSegment.trimmingCharacters(in: .whitespacesAndNewlines)
            if !author.isEmpty {
                return author
            }
        }

        return copyright
    }

    private func makeAuthorLinkButton() -> NSButton {
        makeLinkButton(
            title: currentAuthorString(),
            accessibilityDescription: UICopy.settingsAuthorLabel,
            action: #selector(handleAuthorLink(_:))
        )
    }

    private func makeProjectLinkButton() -> NSButton {
        makeLinkButton(
            title: AboutLink.projectURLString,
            accessibilityDescription: UICopy.settingsLinkLabel,
            action: #selector(handleProjectLink(_:))
        )
    }

    private func makeConfigFolderButton() -> NSButton {
        let button = NSButton(title: UICopy.settingsOpenButtonTitle, target: self, action: #selector(handleOpenConfigFolder(_:)))
        button.isBordered = false
        button.image = NSImage(
            systemSymbolName: "arrow.up.forward.app",
            accessibilityDescription: UICopy.settingsConfigFolderLabel
        )
        button.imagePosition = .imageTrailing
        button.contentTintColor = .linkColor
        button.setButtonType(.momentaryPushIn)
        return button
    }

    private func makeAdvancedButtonsRow() -> NSView {
        let reloadButton = NSButton(title: UICopy.reloadConfigMenuTitle, target: self, action: #selector(handleReloadConfiguration(_:)))
        reloadButton.bezelStyle = .rounded

        let restoreButton = NSButton(title: UICopy.settingsRestoreSettingsButtonTitle, target: self, action: #selector(handleRestoreSettings(_:)))
        restoreButton.bezelStyle = .rounded

        let row = makeHorizontalGroup(spacing: 8)
        row.addArrangedSubview(reloadButton)
        row.addArrangedSubview(restoreButton)
        row.addArrangedSubview(NSView())
        return row
    }

    private func makeLinkButton(title: String, accessibilityDescription: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.isBordered = false
        button.image = NSImage(
            systemSymbolName: "arrow.up.right.square",
            accessibilityDescription: accessibilityDescription
        )
        button.imagePosition = .imageTrailing
        button.contentTintColor = .linkColor
        button.setButtonType(.momentaryPushIn)
        return button
    }

    @objc
    private func handleAuthorLink(_ sender: NSButton) {
        guard let url = URL(string: AboutLink.authorURLString) else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    @objc
    private func handleProjectLink(_ sender: NSButton) {
        guard let url = URL(string: AboutLink.projectURLString) else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    @objc
    private func handleOpenConfigFolder(_ sender: NSButton) {
        _ = actionHandler.openConfigurationDirectory()
    }

    @objc
    private func handleReloadConfiguration(_ sender: NSButton) {
        guard let reloadedConfiguration = actionHandler.reloadConfiguration() else {
            return
        }

        prototypeState.reload(from: reloadedConfiguration)
    }

    @objc
    private func handleRestoreSettings(_ sender: NSButton) {
        presentRestoreConfirmation()
    }

    private func presentRestoreConfirmation() {
        let alert = NSAlert()
        alert.messageText = UICopy.settingsRestoreSettingsButtonTitle
        alert.informativeText = UICopy.settingsRestoreSettingsConfirmationMessage
        alert.alertStyle = .warning
        alert.addButton(withTitle: UICopy.settingsRestoreSettingsButtonTitle)
        alert.addButton(withTitle: UICopy.settingsCancelButtonTitle)

        if let window = view.window {
            alert.beginSheetModal(for: window) { [weak self] response in
                guard response == .alertFirstButtonReturn else {
                    return
                }
                self?.performRestoreSettings()
            }
            return
        }

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }
        performRestoreSettings()
    }

    private func performRestoreSettings() {
        guard let restoredConfiguration = actionHandler.restoreDefaultConfiguration() else {
            return
        }

        prototypeState.reload(from: restoredConfiguration)
    }
}

extension AboutSettingsViewController {
    func reloadForTesting() {
        handleReloadConfiguration(NSButton())
    }

    func restoreForTesting() {
        performRestoreSettings()
    }
}
