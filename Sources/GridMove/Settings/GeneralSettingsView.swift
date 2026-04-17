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

                VStack(alignment: .leading, spacing: 12) {
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

                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            List(selection: $viewModel.selectedModifierGroupID) {
                                ForEach(viewModel.modifierGroupItems) { item in
                                    Text(item.title)
                                        .tag(item.id)
                                }
                            }
                            .frame(minHeight: 96, maxHeight: 120)

                            SettingsListActions {
                                addButton(action: { viewModel.modifierGroupSheetPresented = true })

                                if viewModel.selectedModifierGroupID != nil {
                                    removeButton(action: viewModel.removeSelectedModifierGroup)
                                }
                            }
                        }
                    }
                    .disabled(!viewModel.configuration.dragTriggers.enableModifierLeftMouseDrag)
                }
            }
            .disabled(!viewModel.configuration.general.isEnabled)

            Section(UICopy.excludedWindowsSectionTitle) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Table(viewModel.excludedWindowItems, selection: $viewModel.selectedExcludedWindowID) {
                            TableColumn(UICopy.valueColumnTitle) { item in
                                Text(item.value)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .width(min: 280)

                            TableColumn(UICopy.typeColumnTitle) { item in
                                Text(item.kind.columnTitle)
                                    .foregroundStyle(.secondary)
                            }
                            .width(min: 120, max: 160)
                        }
                        .frame(minHeight: 150, maxHeight: 190)

                        SettingsListActions {
                            addButton(action: viewModel.openExcludedWindowSheet)

                            if viewModel.selectedExcludedWindowID != nil {
                                removeButton(action: viewModel.removeSelectedExcludedWindow)
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .controlSize(.small)
    }

    private func addButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(UICopy.add, systemImage: "plus")
                .labelStyle(.iconOnly)
        }
    }

    private func removeButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(UICopy.delete, systemImage: "minus")
                .labelStyle(.iconOnly)
        }
    }
}

private struct SettingsDescriptionLabel: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
