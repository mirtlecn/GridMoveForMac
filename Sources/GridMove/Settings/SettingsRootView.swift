import SwiftUI

struct SettingsRootView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var selectedTab: SettingsPrototypeTab = .general

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .underPageBackgroundColor),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    SettingsPrototypeHeader(
                        title: UICopy.settingsWindowTitle,
                        subtitle: "Previewing a simpler settings window before wiring real behavior."
                    )

                    SettingsPrototypeTabs(selectedTab: $selectedTab)

                    currentPage
                }
                .frame(maxWidth: 800, alignment: .leading)
                .padding(.horizontal, 32)
                .padding(.top, 32)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .scrollIndicators(.never)
        }
        .frame(minWidth: 860, minHeight: 660)
    }

    @ViewBuilder
    private var currentPage: some View {
        switch selectedTab {
        case .general:
            SettingsPrototypeGeneralView(
                initialConfiguration: viewModel.configuration,
                modifierGroupItems: viewModel.modifierGroupItems.map(\.title),
                excludedWindowItems: viewModel.excludedWindowItems.map {
                    .init(title: $0.value, detail: $0.kind.columnTitle)
                }
            )
        case .layouts:
            SettingsPrototypePlaceholderPage(
                title: UICopy.layoutsSectionTitle,
                message: "Layouts will move to a simpler list and sheet editor after the General design is approved."
            )
        case .appearance:
            SettingsPrototypePlaceholderPage(
                title: UICopy.appearanceSectionTitle,
                message: "Appearance will keep the preview-first layout, but use the same card language as General."
            )
        case .hotkeys:
            SettingsPrototypePlaceholderPage(
                title: UICopy.hotkeysSectionTitle,
                message: "Hotkeys will become a lighter card-based list after the overall shell is locked."
            )
        case .about:
            SettingsPrototypePlaceholderPage(
                title: UICopy.aboutSectionTitle,
                message: "About will stay minimal and use the same spacing, typography, and card treatment."
            )
        }
    }
}

private enum SettingsPrototypeTab: String, CaseIterable, Identifiable {
    case general
    case layouts
    case appearance
    case hotkeys
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:
            return UICopy.generalSectionTitle
        case .layouts:
            return UICopy.layoutsSectionTitle
        case .appearance:
            return UICopy.appearanceSectionTitle
        case .hotkeys:
            return UICopy.hotkeysSectionTitle
        case .about:
            return UICopy.aboutSectionTitle
        }
    }
}

private struct SettingsPrototypeHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 32, weight: .semibold, design: .rounded))

            Text(subtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

private struct SettingsPrototypeTabs: View {
    @Binding var selectedTab: SettingsPrototypeTab

    var body: some View {
        HStack(spacing: 10) {
            ForEach(SettingsPrototypeTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.title)
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(selectedTab == tab ? Color.white : Color.primary)
                        .background {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(selectedTab == tab ? Color.accentColor : Color.white.opacity(0.62))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.white.opacity(selectedTab == tab ? 0 : 0.55), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct SettingsPrototypePlaceholderPage: View {
    let title: String
    let message: String

    var body: some View {
        SettingsPrototypeCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))

                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct SettingsPrototypeGeneralView: View {
    struct ExcludedWindowPreviewItem: Identifiable {
        let id = UUID()
        let title: String
        let detail: String
    }

    let modifierGroupItems: [String]
    let excludedWindowItems: [ExcludedWindowPreviewItem]

    @State private var isEnabled: Bool
    @State private var enableMiddleMouseDrag: Bool
    @State private var enableModifierLeftMouseDrag: Bool
    @State private var selectedModifierGroupIndex: Int
    @State private var selectedExcludedWindowIndex: Int

    init(
        initialConfiguration: AppConfiguration,
        modifierGroupItems: [String],
        excludedWindowItems: [ExcludedWindowPreviewItem]
    ) {
        self.modifierGroupItems = modifierGroupItems
        self.excludedWindowItems = excludedWindowItems
        _isEnabled = State(initialValue: initialConfiguration.general.isEnabled)
        _enableMiddleMouseDrag = State(initialValue: initialConfiguration.dragTriggers.enableMiddleMouseDrag)
        _enableModifierLeftMouseDrag = State(initialValue: initialConfiguration.dragTriggers.enableModifierLeftMouseDrag)
        _selectedModifierGroupIndex = State(initialValue: modifierGroupItems.isEmpty ? -1 : 0)
        _selectedExcludedWindowIndex = State(initialValue: excludedWindowItems.isEmpty ? -1 : 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SettingsPrototypeSectionHeader(
                eyebrow: "General",
                title: "Core controls first",
                detail: "This preview focuses on the visual system: one content column, one tab row, and one card language."
            )

            SettingsPrototypeCard {
                SettingsPrototypeToggleRow(
                    title: UICopy.enableTitle,
                    subtitle: UICopy.enableSubtitle,
                    isOn: $isEnabled
                )
            }

            SettingsPrototypeCard {
                VStack(alignment: .leading, spacing: 18) {
                    SettingsPrototypeCardTitle(title: UICopy.pressAndDragSectionTitle)

                    SettingsPrototypeToggleRow(
                        title: UICopy.middleMouseTitle,
                        subtitle: UICopy.middleMouseSubtitle,
                        isOn: $enableMiddleMouseDrag
                    )
                    .opacity(isEnabled ? 1 : 0.5)

                    SettingsPrototypeDivider()

                    VStack(alignment: .leading, spacing: 16) {
                        SettingsPrototypeToggleRow(
                            title: UICopy.modifierLeftMouseTitle,
                            subtitle: UICopy.modifierLeftMouseSubtitle,
                            isOn: $enableModifierLeftMouseDrag
                        )
                        .opacity(isEnabled ? 1 : 0.5)

                        SettingsPrototypeInsetCard {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(Array(modifierGroupItems.enumerated()), id: \.offset) { index, title in
                                    SettingsPrototypeSelectableRow(
                                        title: title,
                                        detail: nil,
                                        isSelected: selectedModifierGroupIndex == index
                                    )
                                    .onTapGesture {
                                        selectedModifierGroupIndex = index
                                    }
                                }

                                SettingsPrototypeActionBar(
                                    primaryTitle: UICopy.add,
                                    secondaryTitle: UICopy.delete,
                                    isSecondaryEnabled: selectedModifierGroupIndex >= 0
                                )
                            }
                        }
                        .opacity(isEnabled && enableModifierLeftMouseDrag ? 1 : 0.5)
                    }
                }
            }

            SettingsPrototypeCard {
                VStack(alignment: .leading, spacing: 18) {
                    SettingsPrototypeCardTitle(title: UICopy.excludedWindowsSectionTitle)

                    SettingsPrototypeInsetCard {
                        VStack(alignment: .leading, spacing: 10) {
                            if excludedWindowItems.isEmpty {
                                Text("No excluded windows yet.")
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 10)
                            } else {
                                ForEach(Array(excludedWindowItems.enumerated()), id: \.element.id) { index, item in
                                    SettingsPrototypeSelectableRow(
                                        title: item.title,
                                        detail: item.detail,
                                        isSelected: selectedExcludedWindowIndex == index
                                    )
                                    .onTapGesture {
                                        selectedExcludedWindowIndex = index
                                    }
                                }
                            }

                            SettingsPrototypeActionBar(
                                primaryTitle: UICopy.add,
                                secondaryTitle: UICopy.delete,
                                isSecondaryEnabled: selectedExcludedWindowIndex >= 0
                            )
                        }
                    }
                }
            }
        }
    }
}

private struct SettingsPrototypeSectionHeader: View {
    let eyebrow: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow.uppercased())
                .font(.system(size: 12, weight: .bold))
                .kerning(0.8)
                .foregroundStyle(.secondary)

            Text(title)
                .font(.system(size: 28, weight: .semibold, design: .rounded))

            Text(detail)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct SettingsPrototypeCardTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 22, weight: .semibold, design: .rounded))
    }
}

private struct SettingsPrototypeCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.65), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.06), radius: 28, x: 0, y: 14)
    }
}

private struct SettingsPrototypeInsetCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.035), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct SettingsPrototypeToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))

                Text(subtitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.large)
        }
    }
}

private struct SettingsPrototypeSelectableRow: View {
    let title: String
    let detail: String?
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)

                if let detail {
                    Text(detail)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.white.opacity(0.72))
        }
    }
}

private struct SettingsPrototypeActionBar: View {
    let primaryTitle: String
    let secondaryTitle: String
    let isSecondaryEnabled: Bool

    var body: some View {
        HStack(spacing: 10) {
            Button(primaryTitle) {}
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

            Button(secondaryTitle) {}
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(!isSecondaryEnabled)

            Spacer()
        }
        .padding(.top, 8)
    }
}

private struct SettingsPrototypeDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: 1)
    }
}
