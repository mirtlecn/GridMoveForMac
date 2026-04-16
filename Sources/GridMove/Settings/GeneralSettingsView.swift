import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section {
                Toggle(
                    isOn: Binding(
                        get: { viewModel.configuration.general.isEnabled },
                        set: { viewModel.updateGeneralEnabled($0) }
                    )
                ) {
                    SettingsDescriptionLabel(
                        title: UICopy.enableTitle,
                        subtitle: UICopy.enableSubtitle
                    )
                }
            }

            Section(UICopy.pressAndDragSectionTitle) {
                Toggle(
                    isOn: Binding(
                        get: { viewModel.configuration.dragTriggers.enableMiddleMouseDrag },
                        set: { viewModel.updateDragTriggers(enableMiddleMouseDrag: $0) }
                    )
                ) {
                    SettingsDescriptionLabel(
                        title: UICopy.middleMouseTitle,
                        subtitle: UICopy.middleMouseSubtitle
                    )
                }
                .controlSize(.mini)

                VStack(alignment: .leading, spacing: 6) {
                    Toggle(
                        isOn: Binding(
                            get: { viewModel.configuration.dragTriggers.enableModifierLeftMouseDrag },
                            set: { viewModel.updateDragTriggers(enableModifierLeftMouseDrag: $0) }
                        )
                    ) {
                        SettingsDescriptionLabel(
                            title: UICopy.modifierLeftMouseTitle,
                            subtitle: UICopy.modifierLeftMouseSubtitle
                        )
                    }
                    .controlSize(.mini)

                    SettingsActionList {
                        List(selection: $viewModel.selectedModifierGroupID) {
                            ForEach(viewModel.modifierGroupItems) { item in
                                Text(item.title)
                                    .font(.footnote)
                                    .tag(item.id)
                            }
                        }
                        .environment(\.defaultMinListRowHeight, 24)
                        .frame(minHeight: 84, maxHeight: 104)
                    } actions: {
                        Button {
                            viewModel.modifierGroupSheetPresented = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.plain)

                        if viewModel.selectedModifierGroupID != nil {
                            Button {
                                viewModel.removeSelectedModifierGroup()
                            } label: {
                                Image(systemName: "minus")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .opacity(viewModel.configuration.dragTriggers.enableModifierLeftMouseDrag ? 1 : 0.5)
                    .allowsHitTesting(viewModel.configuration.dragTriggers.enableModifierLeftMouseDrag)
                }
            }
            .disabled(!viewModel.configuration.general.isEnabled)

            Section(UICopy.excludedWindowsSectionTitle) {
                SettingsActionList {
                    Table(viewModel.excludedWindowItems, selection: $viewModel.selectedExcludedWindowID) {
                        TableColumn(UICopy.valueColumnTitle) { item in
                            Text(item.value)
                                .font(.footnote)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .width(min: 280)

                        TableColumn(UICopy.typeColumnTitle) { item in
                            Text(item.kind.columnTitle)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .width(min: 120, max: 160)
                    }
                    .frame(minHeight: 144, maxHeight: 176)
                } actions: {
                    Button {
                        viewModel.openExcludedWindowSheet()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.plain)

                    if viewModel.selectedExcludedWindowID != nil {
                        Button {
                            viewModel.removeSelectedExcludedWindow()
                        } label: {
                            Image(systemName: "minus")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 2)
        .background(Color(nsColor: .windowBackgroundColor))
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .controlSize(.small)
    }
}

private struct SettingsDescriptionLabel: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.body.weight(.medium))
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct SettingsActionList<Content: View, Actions: View>: View {
    @ViewBuilder let content: Content
    @ViewBuilder let actions: Actions

    var body: some View {
        VStack(spacing: 0) {
            content

            HStack(spacing: 10) {
                actions
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .font(.body)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
        )
    }
}
