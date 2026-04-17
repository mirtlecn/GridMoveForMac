import SwiftUI

struct SettingsSidebarRowLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .frame(width: 16)

            Text(title)
                .lineLimit(1)
        }
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
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity, alignment: .top)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    controls
                }
                .frame(maxWidth: 780, alignment: .leading)
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct SettingsFormSection<Content: View>: View {
    let title: String?
    @ViewBuilder let content: Content

    init(
        title: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        Form {
            if let title {
                Section(title) {
                    content
                }
            } else {
                Section {
                    content
                }
            }
        }
        .formStyle(.grouped)
        .controlSize(.small)
        .frame(maxWidth: .infinity, alignment: .leading)
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
