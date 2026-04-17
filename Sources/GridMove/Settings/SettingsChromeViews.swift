import SwiftUI

struct SettingsSidebarRowLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
    }
}

struct SettingsPreviewConfigurationPage<Preview: View, Controls: View>: View {
    let preview: Preview
    let controls: Controls

    init(
        @ViewBuilder preview: () -> Preview,
        @ViewBuilder controls: () -> Controls
    ) {
        self.preview = preview()
        self.controls = controls()
    }

    var body: some View {
        VStack(spacing: 0) {
            preview
                .frame(maxWidth: 780, alignment: .leading)
                .padding(24)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    controls
                }
                .frame(maxWidth: 780, alignment: .leading)
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct SettingsListActions<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 8) {
            content
            Spacer()
        }
        .controlSize(.small)
    }
}

struct SettingsSheetContainer<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding(20)
        .frame(minWidth: 420)
    }
}

struct AboutSettingsView: View {
    private var appVersion: String {
        if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           !version.isEmpty {
            return version
        }
        return "0.1.1"
    }

    var body: some View {
        Form {
            Section {
                LabeledContent(UICopy.version, value: appVersion)
            }
        }
        .formStyle(.grouped)
        .controlSize(.small)
    }
}
