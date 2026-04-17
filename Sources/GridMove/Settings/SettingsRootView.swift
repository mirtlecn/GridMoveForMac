import SwiftUI

struct SettingsRootView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Group {
            switch viewModel.selectedSection {
            case .general:
                GeneralSettingsMockView()
            case .layouts:
                SettingsPlaceholderView(
                    title: UICopy.layoutsSectionTitle,
                    message: "Layouts will move into the new native settings shell after the General direction is approved."
                )
            case .appearance:
                SettingsPlaceholderView(
                    title: UICopy.appearanceSectionTitle,
                    message: "Appearance will reuse the native settings shell after the General direction is approved."
                )
            case .hotkeys:
                SettingsPlaceholderView(
                    title: UICopy.hotkeysSectionTitle,
                    message: "Hotkeys will move back in after the native shell and General layout are locked."
                )
            case .about:
                SettingsPlaceholderView(
                    title: UICopy.aboutSectionTitle,
                    message: "About stays minimal and will be reconnected after the first-pass settings shell is approved."
                )
            }
        }
        .frame(minWidth: 860, minHeight: 620)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct SettingsPlaceholderView: View {
    let title: String
    let message: String

    var body: some View {
        Form {
            Section {
                Text(title)
                    .font(.headline)

                Text(message)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
    }
}
