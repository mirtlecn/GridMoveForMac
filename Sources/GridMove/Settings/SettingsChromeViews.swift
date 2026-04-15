import SwiftUI

struct SettingsWindowTrafficLightsView: View {
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(red: 1.0, green: 0.37, blue: 0.33))
                .frame(width: 12, height: 12)
            Circle()
                .fill(Color(red: 1.0, green: 0.74, blue: 0.18))
                .frame(width: 12, height: 12)
            Circle()
                .fill(Color(red: 0.17, green: 0.8, blue: 0.33))
                .frame(width: 12, height: 12)
        }
    }
}

struct SettingsSidebarTabButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 18)

                Text(title)
                    .font(.system(size: 16, weight: .semibold))

                Spacer()
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct SettingsPageSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))

            VStack(alignment: .leading, spacing: 14) {
                content
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
    }
}

struct SettingsMiniActionButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 14, height: 14)
                .padding(8)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

struct SettingsSheetContainer<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            content
        }
        .padding(24)
        .frame(minWidth: 520)
    }
}

struct AboutSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("About")
                .font(.system(size: 28, weight: .bold))

            SettingsPageSection(title: "About") {
                Text("About content will be added later.")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(28)
    }
}
