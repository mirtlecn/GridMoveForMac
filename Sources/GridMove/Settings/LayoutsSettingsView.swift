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
                return UICopy.windowOverlayTitle
            case .triggerOverlay:
                return UICopy.triggerOverlayTitle
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
    }

    private var listPage: some View {
        VStack {
            List {
                Section {
                    ForEach(viewModel.layoutItems) { item in
                        LayoutListRow(
                            item: item,
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
                    }
                }
            }
            .frame(maxWidth: 780, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
        .listStyle(.bordered(alternatesRowBackgrounds: false))
        .onDrop(of: [UTType.text], isTargeted: nil) { _ in
            draggedLayoutID = nil
            return false
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(UICopy.addLayout) {
                    viewModel.addLayout()
                }
            }
        }
    }

    private var detailPage: some View {
        Form {
            if let draft = viewModel.layoutDraft {
                Section {
                    Toggle(
                        UICopy.includeInCycle,
                        isOn: Binding(
                            get: { viewModel.layoutDraft?.includeInCycle ?? draft.includeInCycle },
                            set: { isOn in
                                viewModel.updateLayoutDraft { $0.includeInCycle = isOn }
                            }
                        )
                    )

                    LabeledContent(UICopy.name) {
                        TextField(
                            UICopy.optionalName,
                            text: Binding(
                                get: { viewModel.layoutDraft?.name ?? draft.name },
                                set: { newValue in
                                    viewModel.updateLayoutDraft { $0.name = newValue }
                                }
                            )
                        )
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 240)
                    }

                    LabeledContent(UICopy.grid) {
                        HStack(spacing: 8) {
                            TextField(
                                "12",
                                text: Binding(
                                    get: { String(viewModel.layoutDraft?.gridColumns ?? draft.gridColumns) },
                                    set: { newValue in
                                        viewModel.updateLayoutDraft {
                                            $0.gridColumns = max(1, Int(newValue) ?? $0.gridColumns)
                                        }
                                    }
                                )
                            )
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 72)

                            Text("x")
                                .foregroundStyle(.secondary)

                            TextField(
                                "6",
                                text: Binding(
                                    get: { String(viewModel.layoutDraft?.gridRows ?? draft.gridRows) },
                                    set: { newValue in
                                        viewModel.updateLayoutDraft {
                                            $0.gridRows = max(1, Int(newValue) ?? $0.gridRows)
                                        }
                                    }
                                )
                            )
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 72)
                        }
                    }
                }

                Section {
                    Picker("", selection: $selectedTab) {
                        ForEach(LayoutEditorTab.allCases) { tab in
                            Text(tab.title).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(selectedTab.title) {
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

                Section {
                    HStack(spacing: 10) {
                        Button(viewModel.layoutDeleteArmed ? UICopy.confirmDelete : UICopy.delete) {
                            viewModel.deleteSelectedLayout()
                        }
                        .disabled(!viewModel.canDeleteSelectedLayout)

                        Spacer()

                        Button(UICopy.save) {
                            viewModel.saveLayoutDraft()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!viewModel.hasUnsavedLayoutChanges)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .controlSize(.small)
        .frame(maxWidth: 780, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct LayoutListRow: View {
    let item: SettingsViewModel.LayoutListItem
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                LayoutListIconView(isIncludedInCycle: item.includeInCycle)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name.isEmpty ? item.displayID : item.name)
                        .foregroundStyle(.primary)

                    Text(item.subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct LayoutListIconView: View {
    let isIncludedInCycle: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.quaternary)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.separator.opacity(0.6), lineWidth: 1)
                }

            Image(systemName: "rectangle.split.3x1")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isIncludedInCycle ? Color.accentColor : Color.secondary)
        }
        .frame(width: 32, height: 32)
        .accessibilityHidden(true)
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
