import SwiftUI

struct HotkeysSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section {
                Text("To change a shortcut, double-click the key combination, then type a new shortcut.")
                    .foregroundStyle(.secondary)

                hotkeyList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 2)
        .background(Color(nsColor: .windowBackgroundColor))
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .controlSize(.small)
    }

    private var hotkeyList: some View {
        VStack(spacing: 0) {
            SettingsListContainer(minHeight: 300, maxHeight: 500) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.hotkeyItems) { binding in
                        SettingsSelectableListRow(isSelected: viewModel.selectedHotkeyBindingID == binding.id) {
                            HotkeyBindingRow(
                                binding: binding,
                                options: viewModel.hotkeyActionOptions,
                                onChange: viewModel.replaceBinding(_:),
                                onSelect: { viewModel.selectedHotkeyBindingID = binding.id }
                            )
                        }
                        .onTapGesture {
                            viewModel.selectedHotkeyBindingID = binding.id
                        }

                        if binding.id != viewModel.hotkeyItems.last?.id {
                            Divider()
                                .padding(.leading, 36)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            SettingsListFooterBar {
                SettingsMiniActionButton(systemImage: "plus") {
                    viewModel.addHotkeyBinding()
                }

                SettingsMiniActionButton(systemImage: "minus") {
                    viewModel.deleteSelectedHotkeyBinding()
                }
                .disabled(viewModel.selectedHotkeyBindingID == nil)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
        )
    }
}

private struct HotkeyBindingRow: View {
    let binding: ShortcutBinding
    let options: [(String, HotkeyAction)]
    let onChange: (ShortcutBinding) -> Void
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Toggle(
                "",
                isOn: Binding(
                    get: { binding.isEnabled },
                    set: { isEnabled in
                        var updatedBinding = binding
                        updatedBinding.isEnabled = isEnabled
                        onChange(updatedBinding)
                    }
                )
            )
            .toggleStyle(.checkbox)
            .labelsHidden()

            Picker(
                "",
                selection: Binding(
                    get: { binding.action },
                    set: { newAction in
                        var updatedBinding = binding
                        updatedBinding.action = newAction
                        onChange(updatedBinding)
                    }
                )
            ) {
                ForEach(options, id: \.0) { option in
                    Text(option.0).tag(option.1)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)

            ShortcutRecorderRepresentable(
                shortcut: Binding(
                    get: { binding.shortcut },
                    set: { newShortcut in
                        var updatedBinding = binding
                        updatedBinding.shortcut = newShortcut
                        onChange(updatedBinding)
                    }
                )
            )
            .frame(width: 140, height: 24)
            .onTapGesture(count: 2, perform: onSelect)
        }
        .font(.body)
    }
}
