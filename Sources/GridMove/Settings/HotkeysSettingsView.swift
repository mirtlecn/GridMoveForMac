import SwiftUI

struct HotkeysSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        List {
            Section {
                Text("Select a shortcut field, then press a new key combination.")
                    .foregroundStyle(.secondary)
            }

            Section("Direct Actions") {
                ForEach(viewModel.directBindings) { binding in
                    DirectHotkeyRow(
                        binding: binding,
                        options: viewModel.directActionOptions,
                        onChange: viewModel.replaceBinding(_:),
                        onDelete: { viewModel.deleteBinding(binding.id) }
                    )
                }

                Button("Add Direct Action") {
                    viewModel.addDirectActionBinding()
                }
            }

            Section("Cycle Actions") {
                SectionHeaderRow(title: "Previous Layout")
                ForEach(viewModel.previousCycleBindings) { binding in
                    CycleHotkeyRow(
                        binding: binding,
                        onChange: viewModel.replaceBinding(_:),
                        onDelete: { viewModel.deleteBinding(binding.id) }
                    )
                }

                Button("Add Previous Shortcut") {
                    viewModel.addPreviousCycleBinding()
                }

                SectionHeaderRow(title: "Next Layout")
                ForEach(viewModel.nextCycleBindings) { binding in
                    CycleHotkeyRow(
                        binding: binding,
                        onChange: viewModel.replaceBinding(_:),
                        onDelete: { viewModel.deleteBinding(binding.id) }
                    )
                }

                Button("Add Next Shortcut") {
                    viewModel.addNextCycleBinding()
                }
            }
        }
        .listStyle(.inset)
    }
}
