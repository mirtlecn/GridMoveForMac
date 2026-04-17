import AppKit

@MainActor
final class PreferenceAboutViewController: NSViewController {
    private let versionValue: String
    private let buildValue: String

    init() {
        versionValue = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.1"
        buildValue = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? versionValue
        super.init(nibName: nil, bundle: nil)
        title = UICopy.aboutSectionTitle
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let rootView = NSView()

        let titleLabel = NSTextField(labelWithString: UICopy.appName)
        titleLabel.font = NSFont.systemFont(ofSize: 28, weight: .semibold)

        let versionRow = makeInfoRow(title: UICopy.version, value: versionValue)
        let buildRow = makeInfoRow(title: UICopy.build, value: buildValue)

        let stackView = NSStackView(views: [titleLabel, versionRow, buildRow])
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false

        rootView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 32),
            stackView.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 32),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: rootView.trailingAnchor, constant: -32),
        ])

        view = rootView
    }

    private func makeInfoRow(title: String, value: String) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor

        let valueLabel = NSTextField(labelWithString: value)
        valueLabel.font = NSFont.systemFont(ofSize: 13)

        let stackView = NSStackView(views: [titleLabel, valueLabel])
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 4
        return stackView
    }
}
