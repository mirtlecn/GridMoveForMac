import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct LayoutsSettingsView: View {
    enum LayoutEditorTab: String, CaseIterable, Identifiable {
        case windowOverlay
        case triggerOverlay

        var id: String { rawValue }

        var title: String {
            switch self {
            case .windowOverlay:
                return "Window Overlay"
            case .triggerOverlay:
                return "Trigger Overlay"
            }
        }
    }

    @ObservedObject var viewModel: SettingsViewModel
    @State private var draggedLayoutID: String?
    @State private var selectedTab: LayoutEditorTab = .windowOverlay

    var body: some View {
        Group {
            switch viewModel.layoutPageMode {
            case .list:
                listPage
            case .detail:
                detailPage
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var listPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Layouts")
                    .font(.title.weight(.semibold))

            SettingsGroupedRows {
                ForEach(viewModel.layoutItems) { item in
                    LayoutListRow(
                        title: item.title,
                        onOpen: { viewModel.openLayoutDetail(id: item.id) }
                        )
                        .onDrag {
                            draggedLayoutID = item.id
                            return NSItemProvider(object: item.id as NSString)
                        }
                        .onDrop(
                            of: [UTType.text],
                            delegate: LayoutListDropDelegate(
                                targetID: item.id,
                                draggedLayoutID: $draggedLayoutID,
                                moveLayout: viewModel.moveLayout(id:before:)
                            )
                        )

                        if item.id != viewModel.layoutItems.last?.id {
                            Divider()
                                .padding(.leading, 18)
                        }
                    }
                }

                HStack {
                    Spacer()
                    Button("Add Layout") {
                        viewModel.addLayout()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, 22)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .onDrop(of: [UTType.text], isTargeted: nil) { _ in
            draggedLayoutID = nil
            return false
        }
    }

    private var detailPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let draft = viewModel.layoutDraft {
                    layoutInfoSection(draft: draft)

                    Picker("", selection: $selectedTab) {
                        ForEach(LayoutEditorTab.allCases) { tab in
                            Text(tab.title).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: .infinity)

                    previewSection(draft: draft)

                    HStack(spacing: 10) {
                        Button(viewModel.layoutDeleteArmed ? "Confirm Delete" : "Delete") {
                            viewModel.deleteSelectedLayout()
                        }
                        .buttonStyle(.bordered)
                        .tint(viewModel.layoutDeleteArmed ? .red : nil)
                        .disabled(!viewModel.canDeleteSelectedLayout)

                        Spacer()

                        Button("Save") {
                            viewModel.saveLayoutDraft()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!viewModel.hasUnsavedLayoutChanges)
                    }
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, 22)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    private func layoutInfoSection(draft: LayoutPreset) -> some View {
        SettingsGroupedRows {
            SettingsGroupedRow {
                layoutToggleRow(
                    title: "Include in Cycle",
                    isOn: Binding(
                        get: { viewModel.layoutDraft?.includeInCycle ?? draft.includeInCycle },
                        set: { isOn in
                            viewModel.updateLayoutDraft { $0.includeInCycle = isOn }
                        }
                    )
                )
            }

            Divider()

            SettingsGroupedRow {
                layoutTextFieldRow(
                    title: "Name",
                    placeholder: "Optional Name",
                    text: Binding(
                        get: { viewModel.layoutDraft?.name ?? draft.name },
                        set: { newValue in
                            viewModel.updateLayoutDraft { $0.name = newValue }
                        }
                    )
                )
            }

            Divider()

            SettingsGroupedRow {
                layoutGridRow(
                    columns: Binding(
                        get: { String(viewModel.layoutDraft?.gridColumns ?? draft.gridColumns) },
                        set: { newValue in
                            viewModel.updateLayoutDraft {
                                $0.gridColumns = max(1, Int(newValue) ?? $0.gridColumns)
                            }
                        }
                    ),
                    rows: Binding(
                        get: { String(viewModel.layoutDraft?.gridRows ?? draft.gridRows) },
                        set: { newValue in
                            viewModel.updateLayoutDraft {
                                $0.gridRows = max(1, Int(newValue) ?? $0.gridRows)
                            }
                        }
                    )
                )
            }
        }
    }

    private func previewSection(draft: LayoutPreset) -> some View {
        SettingsPageSection(title: nil) {
            Group {
                switch selectedTab {
                case .windowOverlay:
                    InteractiveGridPreview(
                        columns: draft.gridColumns,
                        rows: draft.gridRows,
                        selection: Binding(
                            get: { viewModel.layoutDraft?.windowSelection ?? draft.windowSelection },
                            set: { newSelection in
                                viewModel.updateLayoutDraft { $0.windowSelection = newSelection }
                            }
                        ),
                        style: GridPreviewOverlayStyle(
                            strokeColor: Color(viewModel.configuration.appearance.highlightStrokeColor.nsColor),
                            fillOpacity: viewModel.configuration.appearance.highlightFillOpacity,
                            strokeWidth: viewModel.configuration.appearance.highlightStrokeWidth
                        )
                    )
                case .triggerOverlay:
                    InteractiveTriggerRegionPreview(
                        columns: draft.gridColumns,
                        rows: draft.gridRows,
                        triggerRegion: Binding(
                            get: { viewModel.layoutDraft?.triggerRegion ?? draft.triggerRegion },
                            set: { newRegion in
                                viewModel.updateLayoutDraft { $0.triggerRegion = newRegion }
                            }
                        ),
                        style: GridPreviewOverlayStyle(
                            strokeColor: Color(viewModel.configuration.appearance.triggerStrokeColor.nsColor),
                            fillOpacity: min(max(viewModel.configuration.appearance.triggerOpacity * 0.45, 0.08), 0.35),
                            strokeWidth: 2
                        )
                    )
                }
            }
            .frame(height: 320)
        }
    }

    private func layoutToggleRow(title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.body)

            Spacer(minLength: 12)

            Toggle("", isOn: isOn)
                .labelsHidden()
        }
    }

    private func layoutTextFieldRow(title: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 16) {
            Text(title)
                .font(.body)
                .frame(width: 96, alignment: .leading)

            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func layoutGridRow(columns: Binding<String>, rows: Binding<String>) -> some View {
        HStack(spacing: 16) {
            Text("Grid")
                .font(.body)
                .frame(width: 96, alignment: .leading)

            TextField("12", text: columns)
                .textFieldStyle(.roundedBorder)
                .frame(width: 72)

            Text("x")
                .font(.body)
                .foregroundStyle(.secondary)

            TextField("6", text: rows)
                .textFieldStyle(.roundedBorder)
                .frame(width: 72)

            Spacer(minLength: 0)
        }
    }
}

private struct LayoutListRow: View {
    let title: String
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer(minLength: 12)

            Button(action: onOpen) {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .frame(width: 14, height: 14)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
    }
}

private struct LayoutListDropDelegate: DropDelegate {
    let targetID: String
    @Binding var draggedLayoutID: String?
    let moveLayout: (String, String) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        draggedLayoutID != nil
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let draggedLayoutID else {
            return false
        }

        moveLayout(draggedLayoutID, targetID)
        self.draggedLayoutID = nil
        return true
    }

    func dropExited(info: DropInfo) {
        if !info.hasItemsConforming(to: [UTType.text]) {
            draggedLayoutID = nil
        }
    }
}
