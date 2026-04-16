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

                    VStack(alignment: .leading, spacing: 8) {
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

                        SettingsActionList {
                            List(selection: $viewModel.selectedModifierGroupID) {
                                ForEach(viewModel.modifierGroupItems) { item in
                                    Text(item.title)
                                        .tag(item.id)
                                }
                            }
                            .environment(\.defaultMinListRowHeight, 28)
                            .frame(minHeight: 92, maxHeight: 118)
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
                    }
                    .disabled(!viewModel.configuration.dragTriggers.enableModifierLeftMouseDrag)
                }
                .disabled(!viewModel.configuration.general.isEnabled)

                Section("Excluded Windows") {
                    SettingsActionList {
                        Table(viewModel.excludedWindowItems, selection: $viewModel.selectedExcludedWindowID) {
                            TableColumn("Value") { item in
                                Text(item.value)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .width(min: 280)

                            TableColumn("Type") { item in
                                Text(item.kind.columnTitle)
                                    .foregroundStyle(.secondary)
                            }
                            .width(min: 120, max: 160)
                        }
                        .frame(minHeight: 150, maxHeight: 190)
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
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .controlSize(.small)
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
            .font(.body.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
        )
    }
}
