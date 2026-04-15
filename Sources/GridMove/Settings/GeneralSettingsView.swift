import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsCard(title: "General") {
                    SettingsSwitchRow(
                        title: "Enable",
                        subtitle: "Allow drag triggers, layout hotkeys, and command line layout actions.",
                        isOn: Binding(
                            get: { viewModel.configuration.general.isEnabled },
                            set: { viewModel.updateGeneralEnabled($0) }
                        )
                    )
                }

                HStack(alignment: .top, spacing: 20) {
                    exclusionCard(
                        title: "Excluded Bundle IDs",
                        values: viewModel.configuration.general.excludedBundleIDs,
                        onAdd: { viewModel.requestEntry(.bundleID) },
                        onDelete: viewModel.removeBundleID(at:)
                    )
                    exclusionCard(
                        title: "Excluded Window Titles",
                        values: viewModel.configuration.general.excludedWindowTitles,
                        onAdd: { viewModel.requestEntry(.windowTitle) },
                        onDelete: viewModel.removeWindowTitle(at:)
                    )
                }

                SettingsCard(title: "Drag Triggers") {
                    VStack(alignment: .leading, spacing: 16) {
                        SettingsSwitchRow(
                            title: "Enable Middle Mouse Drag",
                            subtitle: "Hold the middle mouse button to activate the drag grid.",
                            isOn: Binding(
                                get: { viewModel.configuration.dragTriggers.enableMiddleMouseDrag },
                                set: { viewModel.updateDragTriggers(enableMiddleMouseDrag: $0) }
                            )
                        )

                        SettingsSwitchRow(
                            title: "Enable Modifier + Left Mouse Drag",
                            subtitle: "Use a configured modifier group with the left mouse button.",
                            isOn: Binding(
                                get: { viewModel.configuration.dragTriggers.enableModifierLeftMouseDrag },
                                set: { viewModel.updateDragTriggers(enableModifierLeftMouseDrag: $0) }
                            )
                        )

                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(viewModel.configuration.dragTriggers.modifierGroups.enumerated()), id: \.offset) { index, group in
                                HStack(spacing: 12) {
                                    Text(group.map(\.displayName).joined(separator: " + "))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Button("Delete") {
                                        viewModel.removeModifierGroup(at: index)
                                    }
                                }
                            }
                        }

                        Button("Add Modifier Group") {
                            viewModel.modifierGroupSheetPresented = true
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private func exclusionCard(
        title: String,
        values: [String],
        onAdd: @escaping () -> Void,
        onDelete: @escaping (Int) -> Void
    ) -> some View {
        SettingsCard(title: title) {
            VStack(alignment: .leading, spacing: 12) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        if values.isEmpty {
                            Text("No items")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                                HStack(spacing: 12) {
                                    Text(value)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Button("Delete") {
                                        onDelete(index)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 180, maxHeight: 220)

                Button("+ Add") {
                    onAdd()
                }
            }
        }
    }
}
