import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("General")
                    .font(.system(size: 26, weight: .bold))

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
                    VStack(alignment: .leading, spacing: 16) {
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

                            VStack(spacing: 0) {
                                SettingsListContainer(minHeight: 96, maxHeight: 120) {
                                    ForEach(Array(viewModel.modifierGroupItems.enumerated()), id: \.element.id) { offset, item in
                                        VStack(spacing: 0) {
                                            SettingsSelectableListRow(isSelected: viewModel.selectedModifierGroupID == item.id) {
                                                Text(item.title)
                                                    .font(.system(size: 15))
                                            }
                                            .onTapGesture {
                                                viewModel.selectedModifierGroupID = item.id
                                            }

                                            if offset < viewModel.modifierGroupItems.count - 1 {
                                                Divider()
                                                    .padding(.leading, 14)
                                            }
                                        }
                                    }
                                }
                                SettingsListFooterBar {
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
                            .disabled(!viewModel.configuration.dragTriggers.enableModifierLeftMouseDrag)
                        }
                    }
                }
                .disabled(!viewModel.configuration.general.isEnabled)

                SettingsPageSection(title: "Excluded Windows") {
                    VStack(spacing: 0) {
                        SettingsListContainer(minHeight: 160, maxHeight: 200) {
                            SettingsTableHeaderRow(
                                leadingTitle: "Value",
                                trailingTitle: "Type"
                            )

                            ForEach(Array(viewModel.excludedWindowItems.enumerated()), id: \.element.id) { offset, item in
                                VStack(spacing: 0) {
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

                                    if offset < viewModel.excludedWindowItems.count - 1 {
                                        Divider()
                                            .padding(.leading, 14)
                                    }
                                }
                            }
                        }

                        SettingsListFooterBar {
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
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}
