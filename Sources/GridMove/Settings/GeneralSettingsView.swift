import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("General")
                    .font(.system(size: 34, weight: .bold))

                SettingsPageSection(title: "Enable") {
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

                            List(selection: $viewModel.selectedModifierGroupID) {
                                ForEach(viewModel.modifierGroupItems) { item in
                                    Text(item.title)
                                        .tag(Optional(item.id))
                                }
                            }
                            .listStyle(.inset(alternatesRowBackgrounds: false))
                            .frame(minHeight: 104, maxHeight: 128)
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
                    List(selection: $viewModel.selectedExcludedWindowID) {
                        ForEach(viewModel.excludedWindowItems) { item in
                            HStack(spacing: 12) {
                                Text(item.value)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(item.kind.columnTitle)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(Optional(item.id))
                        }
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: false))
                    .frame(minHeight: 140, maxHeight: 180)

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
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}
