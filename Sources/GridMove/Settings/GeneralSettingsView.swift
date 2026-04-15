import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("General")
                .font(.largeTitle.weight(.bold))
                .padding(.horizontal, 24)
                .padding(.top, 20)

            Form {
                Section {
                    Toggle(
                        isOn: Binding(
                            get: { viewModel.configuration.general.isEnabled },
                            set: { viewModel.updateGeneralEnabled($0) }
                        )
                    ) {
                        SettingsDescriptionLabel(
                            title: "Enable",
                            subtitle: "Allow drag triggers, layout hotkeys, and command line layout actions."
                        )
                    }
                }

                Section("Press And Drag") {
                    Toggle(
                        isOn: Binding(
                            get: { viewModel.configuration.dragTriggers.enableMiddleMouseDrag },
                            set: { viewModel.updateDragTriggers(enableMiddleMouseDrag: $0) }
                        )
                    ) {
                        SettingsDescriptionLabel(
                            title: "Middle Mouse",
                            subtitle: "Press middle mouse for a short time to activate the grid."
                        )
                    }
                    .controlSize(.mini)

                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(
                            isOn: Binding(
                                get: { viewModel.configuration.dragTriggers.enableModifierLeftMouseDrag },
                                set: { viewModel.updateDragTriggers(enableModifierLeftMouseDrag: $0) }
                            )
                        ) {
                            SettingsDescriptionLabel(
                                title: "Modifier + Left Mouse",
                                subtitle: "Hold pre-set modifier, then press left mouse to activate."
                            )
                        }
                        .controlSize(.mini)

                        List(selection: $viewModel.selectedModifierGroupID) {
                            ForEach(viewModel.modifierGroupItems) { item in
                                Text(item.title)
                                    .tag(item.id)
                            }
                        }
                        .frame(minHeight: 92, maxHeight: 116)

                        HStack(spacing: 8) {
                            Button {
                                viewModel.modifierGroupSheetPresented = true
                            } label: {
                                Label("Add", systemImage: "plus")
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)

                            if viewModel.selectedModifierGroupID != nil {
                                Button {
                                    viewModel.removeSelectedModifierGroup()
                                } label: {
                                    Label("Delete", systemImage: "minus")
                                }
                                .labelStyle(.iconOnly)
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    .disabled(!viewModel.configuration.dragTriggers.enableModifierLeftMouseDrag)
                }
                .disabled(!viewModel.configuration.general.isEnabled)

                Section("Excluded Windows") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            Text("Value")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("Type")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        List(selection: $viewModel.selectedExcludedWindowID) {
                            ForEach(viewModel.excludedWindowItems) { item in
                                HStack(spacing: 12) {
                                    Text(item.value)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(item.kind.columnTitle)
                                        .foregroundStyle(.secondary)
                                }
                                .tag(item.id)
                            }
                        }
                        .frame(minHeight: 140, maxHeight: 180)

                        HStack(spacing: 8) {
                            Button {
                                viewModel.openExcludedWindowSheet()
                            } label: {
                                Label("Add", systemImage: "plus")
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)

                            if viewModel.selectedExcludedWindowID != nil {
                                Button {
                                    viewModel.removeSelectedExcludedWindow()
                                } label: {
                                    Label("Delete", systemImage: "minus")
                                }
                                .labelStyle(.iconOnly)
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct SettingsDescriptionLabel: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 1)
    }
}
