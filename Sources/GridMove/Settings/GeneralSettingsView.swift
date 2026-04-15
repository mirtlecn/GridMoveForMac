import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("General")
                    .font(.system(size: 28, weight: .bold))

                SettingsPageSection(title: nil) {
                    SettingsSwitchRow(
                        title: "Enable",
                        subtitle: "Allow drag triggers, layout hotkeys, and command line layout actions.",
                        isOn: Binding(
                            get: { viewModel.configuration.general.isEnabled },
                            set: { viewModel.updateGeneralEnabled($0) }
                        )
                    )
                }

                SettingsPageSection(title: "Press And Drag") {
                    VStack(alignment: .leading, spacing: 18) {
                        SettingsSwitchRow(
                            title: "Middle Mouse",
                            subtitle: "Press middle mouse for a short time to activate the grid.",
                            isOn: Binding(
                                get: { viewModel.configuration.dragTriggers.enableMiddleMouseDrag },
                                set: { viewModel.updateDragTriggers(enableMiddleMouseDrag: $0) }
                            )
                        )

                        Divider()

                        VStack(alignment: .leading, spacing: 14) {
                            SettingsSwitchRow(
                                title: "Modifier + Left Mouse",
                                subtitle: "Hold pre-set modifier, then press left mouse to activate.",
                                isOn: Binding(
                                    get: { viewModel.configuration.dragTriggers.enableModifierLeftMouseDrag },
                                    set: { viewModel.updateDragTriggers(enableModifierLeftMouseDrag: $0) }
                                )
                            )

                            SettingsListContainer(minHeight: 104, maxHeight: 128) {
                                ForEach(viewModel.modifierGroupItems) { item in
                                    SettingsSelectableListRow(isSelected: viewModel.selectedModifierGroupID == item.id) {
                                        Text(item.title)
                                            .font(.system(size: 15))
                                    }
                                    .onTapGesture {
                                        viewModel.selectedModifierGroupID = item.id
                                    }
                                }
                            }
                            .disabled(!viewModel.configuration.dragTriggers.enableModifierLeftMouseDrag)

                            HStack(spacing: 8) {
                                SettingsMiniActionButton(systemImage: "plus") {
                                    viewModel.modifierGroupSheetPresented = true
                                }

                                if viewModel.selectedModifierGroupID != nil {
                                    SettingsMiniActionButton(systemImage: "minus") {
                                        viewModel.removeSelectedModifierGroup()
                                    }
                                }
                            }
                        }
                    }
                }
                .disabled(!viewModel.configuration.general.isEnabled)

                SettingsPageSection(title: "Excluded Windows") {
                    SettingsListContainer(minHeight: 140, maxHeight: 180) {
                        ForEach(viewModel.excludedWindowItems) { item in
                            SettingsSelectableListRow(isSelected: viewModel.selectedExcludedWindowID == item.id) {
                                Text(item.value)
                                    .textSelection(.enabled)
                                    .font(.system(size: 15))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(item.kind.columnTitle)
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                            .onTapGesture {
                                viewModel.selectedExcludedWindowID = item.id
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        SettingsMiniActionButton(systemImage: "plus") {
                            viewModel.openExcludedWindowSheet()
                        }

                        if viewModel.selectedExcludedWindowID != nil {
                            SettingsMiniActionButton(systemImage: "minus") {
                                viewModel.removeSelectedExcludedWindow()
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 26)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}
