import SwiftUI

struct HotkeysSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section {
                Text(UICopy.hotkeysHelpText)
                    .foregroundStyle(.secondary)

                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        List(selection: $viewModel.selectedHotkeyBindingID) {
                            ForEach(viewModel.hotkeyItems) { binding in
                                HotkeyBindingRow(
                                    binding: binding,
                                    options: viewModel.hotkeyActionOptions,
                                    onChange: viewModel.replaceBinding(_:),
                                    onSelect: { viewModel.selectedHotkeyBindingID = binding.id }
                                )
                                .tag(binding.id)
                            }
                        }
                        .frame(minHeight: 300, maxHeight: 500)

                        SettingsListActions {
                            Button {
                                viewModel.addHotkeyBinding()
                            } label: {
                                Label(UICopy.add, systemImage: "plus")
                                    .labelStyle(.iconOnly)
                            }

                            Button {
                                viewModel.deleteSelectedHotkeyBinding()
                            } label: {
                                Label(UICopy.delete, systemImage: "minus")
                                    .labelStyle(.iconOnly)
                            }
                            .disabled(viewModel.selectedHotkeyBindingID == nil)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .controlSize(.small)
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
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }
}
