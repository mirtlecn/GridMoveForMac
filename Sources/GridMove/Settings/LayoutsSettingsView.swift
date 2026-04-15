import AppKit
import SwiftUI

struct LayoutsSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    private let gridEditorHeight: CGFloat = 340

    var body: some View {
        HSplitView {
            SettingsCard(title: "Layouts") {
                VStack(alignment: .leading, spacing: 12) {
                    List(selection: Binding(
                        get: { viewModel.selectedLayoutID },
                        set: { viewModel.selectLayout(id: $0) }
                    )) {
                        ForEach(viewModel.configuration.layouts) { layout in
                            Text(layout.name)
                                .tag(Optional(layout.id))
                        }
                        .onMove(perform: viewModel.moveLayouts)
                    }
                    .frame(minWidth: 230)

                    HStack {
                        Button("+") { viewModel.addLayout() }
                        Button("-") { viewModel.removeSelectedLayout() }
                    }
                }
            }
            .frame(minWidth: 260, idealWidth: 280, maxWidth: 320)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let draft = viewModel.layoutDraft {
                        SettingsCard(title: "Details") {
                            VStack(alignment: .leading, spacing: 14) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Name")
                                        .foregroundStyle(.secondary)
                                    TextField(
                                        "Layout Name",
                                        text: Binding(
                                            get: { viewModel.layoutDraft?.name ?? "" },
                                            set: { newValue in
                                                viewModel.updateLayoutDraft { $0.name = newValue.isEmpty ? $0.name : newValue }
                                            }
                                        )
                                    )
                                    .textFieldStyle(.roundedBorder)
                                }

                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Columns")
                                            .foregroundStyle(.secondary)
                                        TextField(
                                            "12",
                                            text: Binding(
                                                get: { String(viewModel.layoutDraft?.gridColumns ?? 12) },
                                                set: { newValue in
                                                    viewModel.updateLayoutDraft {
                                                        $0.gridColumns = max(1, Int(newValue) ?? $0.gridColumns)
                                                    }
                                                }
                                            )
                                        )
                                        .frame(width: 96)
                                        .textFieldStyle(.roundedBorder)
                                    }

                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Rows")
                                            .foregroundStyle(.secondary)
                                        TextField(
                                            "6",
                                            text: Binding(
                                                get: { String(viewModel.layoutDraft?.gridRows ?? 6) },
                                                set: { newValue in
                                                    viewModel.updateLayoutDraft {
                                                        $0.gridRows = max(1, Int(newValue) ?? $0.gridRows)
                                                    }
                                                }
                                            )
                                        )
                                        .frame(width: 96)
                                        .textFieldStyle(.roundedBorder)
                                    }
                                }
                            }
                        }

                        SettingsCard(title: "Window Layout") {
                            GridSelectionEditorRepresentable(
                                columns: draft.gridColumns,
                                rows: draft.gridRows,
                                selection: Binding(
                                    get: { viewModel.layoutDraft?.windowSelection ?? draft.windowSelection },
                                    set: { newSelection in
                                        viewModel.updateLayoutDraft { $0.windowSelection = newSelection }
                                    }
                                ),
                                selectionColor: .controlAccentColor
                            )
                            .frame(height: gridEditorHeight)
                        }

                        SettingsCard(title: "Trigger Area") {
                            GridSelectionEditorRepresentable(
                                columns: draft.gridColumns,
                                rows: draft.gridRows,
                                selection: Binding(
                                    get: { viewModel.layoutDraft?.triggerSelection ?? draft.triggerSelection },
                                    set: { newSelection in
                                        viewModel.updateLayoutDraft { $0.triggerSelection = newSelection }
                                    }
                                ),
                                selectionColor: .systemOrange
                            )
                            .frame(height: gridEditorHeight)
                        }

                        HStack {
                            Spacer()
                            Button(viewModel.resetArmed ? "Confirm?" : "Reset") {
                                viewModel.resetLayoutDraft()
                            }
                            .tint(viewModel.resetArmed ? .red : nil)

                            Button("Save") {
                                viewModel.saveLayoutDraft()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } else {
                        SettingsCard(title: "Layouts") {
                            Text("Select a layout to edit.")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(minWidth: 620)
        }
        .padding(20)
    }
}
