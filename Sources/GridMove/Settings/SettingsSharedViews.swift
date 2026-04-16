import AppKit
import SwiftUI

struct DirectHotkeyRow: View {
    let binding: ShortcutBinding
    let options: [(String, HotkeyAction)]
    let onChange: (ShortcutBinding) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 16) {
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
            .frame(width: 240, height: 32)

            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
        .padding(.vertical, 4)
    }
}

struct CycleHotkeyRow: View {
    let binding: ShortcutBinding
    let onChange: (ShortcutBinding) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Text(binding.action == .cyclePrevious ? "Apply Previous Layout" : "Apply Next Layout")
                .foregroundStyle(.primary)
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
            .frame(width: 240, height: 32)

            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
        .padding(.vertical, 4)
    }
}

struct SectionHeaderRow: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

struct LabeledSliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 130, alignment: .leading)
            Slider(value: $value, in: range)
            Text(String(format: "%.2f", value))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 44, alignment: .trailing)
        }
    }
}

struct LabeledNumberFieldRow: View {
    let title: String
    @Binding var value: Double

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 130, alignment: .leading)
            TextField(
                "",
                text: Binding(
                    get: { String(format: "%.1f", value) },
                    set: { newValue in
                        value = Double(newValue) ?? value
                    }
                )
            )
            .textFieldStyle(.roundedBorder)
            .frame(width: 90)
        }
    }
}

struct ModifierGroupSheetView: View {
    let onConfirm: ([ModifierKey]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedKeys = Set<ModifierKey>()

    var body: some View {
        SettingsSheetContainer {
            HStack(alignment: .center, spacing: 14) {
                ForEach(ModifierKey.allCases, id: \.self) { key in
                    Toggle(
                        key.displayName,
                        isOn: Binding(
                            get: { selectedKeys.contains(key) },
                            set: { isEnabled in
                                if isEnabled {
                                    selectedKeys.insert(key)
                                } else {
                                    selectedKeys.remove(key)
                                }
                            }
                        )
                    )
                    .toggleStyle(.checkbox)
                    .font(.body)
                }
            }

            HStack(spacing: 10) {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                Button("Add") {
                    onConfirm(ModifierKey.allCases.filter { selectedKeys.contains($0) })
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(selectedKeys.isEmpty)
            }
        }
    }
}

struct ExcludedWindowSheetView: View {
    let onConfirm: (SettingsViewModel.EntryKind, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var kind: SettingsViewModel.EntryKind = .bundleID
    @State private var value = ""

    var body: some View {
        SettingsSheetContainer {
            HStack(alignment: .center, spacing: 14) {
                Picker("", selection: $kind) {
                    ForEach([SettingsViewModel.EntryKind.bundleID, .windowTitle]) { entryKind in
                        Text(entryKind.columnTitle).tag(entryKind)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 150)

                Text("Is")
                    .foregroundStyle(.secondary)

                TextField("", text: $value)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 10) {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                Button("Add") {
                    onConfirm(kind, value)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text(title)
                .font(.headline)
        }
        .controlSize(.large)
    }
}

struct SettingsSwitchRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.vertical, 2)
    }
}

struct GridSelectionEditorRepresentable: NSViewRepresentable {
    var columns: Int
    var rows: Int
    @Binding var selection: GridSelection
    var selectionColor: NSColor
    var showsGridBackground = true
    var showsSelection = true

    func makeNSView(context: Context) -> GridSelectionEditorView {
        let view = GridSelectionEditorView(columns: columns, rows: rows)
        view.selectionColor = selectionColor
        view.showsGridBackground = showsGridBackground
        view.showsSelection = showsSelection
        view.onSelectionChanged = { nextSelection in
            selection = GridSelection(x: nextSelection.x, y: nextSelection.y, w: nextSelection.w, h: nextSelection.h)
        }
        return view
    }

    func updateNSView(_ nsView: GridSelectionEditorView, context: Context) {
        nsView.columns = columns
        nsView.rows = rows
        nsView.selectionColor = selectionColor
        nsView.showsGridBackground = showsGridBackground
        nsView.showsSelection = showsSelection
        nsView.selection = CellSelection(x: selection.x, y: selection.y, w: selection.w, h: selection.h)
        nsView.onSelectionChanged = { nextSelection in
            selection = GridSelection(x: nextSelection.x, y: nextSelection.y, w: nextSelection.w, h: nextSelection.h)
        }
    }
}

struct TriggerRegionEditorRepresentable: NSViewRepresentable {
    var columns: Int
    var rows: Int
    @Binding var triggerRegion: TriggerRegion
    var selectionColor: NSColor
    var showsGridBackground = true
    var showsSelection = true

    func makeNSView(context: Context) -> TriggerRegionEditorView {
        let view = TriggerRegionEditorView(columns: columns, rows: rows)
        view.selectionColor = selectionColor
        view.showsGridBackground = showsGridBackground
        view.showsSelection = showsSelection
        view.onTriggerRegionChanged = { nextRegion in
            triggerRegion = nextRegion
        }
        return view
    }

    func updateNSView(_ nsView: TriggerRegionEditorView, context: Context) {
        nsView.columns = columns
        nsView.rows = rows
        nsView.selectionColor = selectionColor
        nsView.showsGridBackground = showsGridBackground
        nsView.showsSelection = showsSelection
        nsView.triggerRegion = triggerRegion
        nsView.onTriggerRegionChanged = { nextRegion in
            triggerRegion = nextRegion
        }
    }
}

struct ShortcutRecorderRepresentable: NSViewRepresentable {
    @Binding var shortcut: KeyboardShortcut?

    func makeNSView(context: Context) -> ShortcutRecorderControl {
        let control = ShortcutRecorderControl()
        control.shortcut = shortcut
        control.onShortcutChange = { nextShortcut in
            shortcut = nextShortcut
        }
        return control
    }

    func updateNSView(_ nsView: ShortcutRecorderControl, context: Context) {
        nsView.shortcut = shortcut
        nsView.onShortcutChange = { nextShortcut in
            shortcut = nextShortcut
        }
    }
}

struct GridPreviewOverlayStyle {
    let strokeColor: Color
    let fillOpacity: Double
    let strokeWidth: CGFloat
}

struct GridPreviewOverlayItem: Identifiable {
    let id: String
    let region: TriggerRegion
    let style: GridPreviewOverlayStyle
}

private struct FixedAspectPreviewFrame<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { geometry in
            let fittedRect = fittedPreviewRect(in: geometry.size)

            ZStack {
                content
                    .frame(width: fittedRect.width, height: fittedRect.height)
                    .position(x: fittedRect.midX, y: fittedRect.midY)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func fittedPreviewRect(in size: CGSize) -> CGRect {
        let bounds = CGRect(origin: .zero, size: size)
        let targetAspectRatio = PreviewDisplayMetrics.totalPreviewAspectRatio
        guard bounds.width > 0, bounds.height > 0, targetAspectRatio > 0 else {
            return bounds
        }

        let availableAspectRatio = bounds.width / bounds.height
        let fittedSize: CGSize
        if availableAspectRatio > targetAspectRatio {
            fittedSize = CGSize(width: bounds.height * targetAspectRatio, height: bounds.height)
        } else {
            fittedSize = CGSize(width: bounds.width, height: bounds.width / targetAspectRatio)
        }

        return CGRect(
            x: (bounds.width - fittedSize.width) / 2,
            y: (bounds.height - fittedSize.height) / 2,
            width: fittedSize.width,
            height: fittedSize.height
        )
    }
}

struct SharedGridPreview: View {
    let columns: Int
    let rows: Int
    let overlays: [GridPreviewOverlayItem]

    var body: some View {
        FixedAspectPreviewFrame {
            SharedGridPreviewContent(columns: columns, rows: rows, overlays: overlays)
        }
    }
}

struct InteractiveGridPreview: View {
    let columns: Int
    let rows: Int
    @Binding var selection: GridSelection
    let style: GridPreviewOverlayStyle
    var additionalOverlays: [GridPreviewOverlayItem] = []

    var body: some View {
        FixedAspectPreviewFrame {
            ZStack {
                SharedGridPreviewContent(
                    columns: columns,
                    rows: rows,
                    overlays: [
                        GridPreviewOverlayItem(id: "selection", region: .screen(selection), style: style),
                    ] + additionalOverlays
                )
                GridSelectionEditorRepresentable(
                    columns: columns,
                    rows: rows,
                    selection: $selection,
                    selectionColor: NSColor(style.strokeColor),
                    showsGridBackground: false,
                    showsSelection: false
                )
            }
        }
    }
}

struct InteractiveTriggerRegionPreview: View {
    let columns: Int
    let rows: Int
    @Binding var triggerRegion: TriggerRegion
    let style: GridPreviewOverlayStyle
    var additionalOverlays: [GridPreviewOverlayItem] = []

    var body: some View {
        FixedAspectPreviewFrame {
            ZStack {
                SharedGridPreviewContent(
                    columns: columns,
                    rows: rows,
                    overlays: [
                        GridPreviewOverlayItem(id: "trigger", region: triggerRegion, style: style),
                    ] + additionalOverlays
                )
                TriggerRegionEditorRepresentable(
                    columns: columns,
                    rows: rows,
                    triggerRegion: $triggerRegion,
                    selectionColor: NSColor(style.strokeColor),
                    showsGridBackground: false,
                    showsSelection: false
                )
            }
        }
    }
}

private struct SharedGridPreviewContent: View {
    let columns: Int
    let rows: Int
    let overlays: [GridPreviewOverlayItem]

    var body: some View {
        GeometryReader { geometry in
            let previewGeometry = GridPreviewGeometry(
                columns: columns,
                rows: rows,
                bounds: geometry.frame(in: .local),
                outerPadding: GridPreviewGeometry.defaultOuterPadding
            )
            let menuBarIconSize = max(8, previewGeometry.menuBarRect.height * 0.42)
            let menuBarTextSize = max(8, previewGeometry.menuBarRect.height * 0.34)
            let menuBarHorizontalPadding = max(8, previewGeometry.menuBarRect.height * 0.38)

            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(PreviewPalette.previewBackground)

                RoundedRectangle(cornerRadius: 10)
                    .fill(PreviewPalette.menuBarBackground)
                    .overlay {
                        HStack(spacing: 0) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: menuBarIconSize, weight: .semibold))
                                .foregroundStyle(PreviewPalette.menuBarForeground)

                            Spacer(minLength: 0)

                            Text("12:00")
                                .font(.system(size: menuBarTextSize, weight: .semibold, design: .rounded))
                                .foregroundStyle(PreviewPalette.menuBarForeground)
                        }
                        .padding(.horizontal, menuBarHorizontalPadding)
                    }
                    .frame(width: previewGeometry.menuBarRect.width, height: previewGeometry.menuBarRect.height)
                    .position(x: previewGeometry.menuBarRect.midX, y: previewGeometry.menuBarRect.midY)

                ForEach(0 ..< rows, id: \.self) { segment in
                    let segmentRect = previewGeometry.menuBarSegmentRect(segment: segment)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(PreviewPalette.menuBarSegmentFill)
                        .frame(width: segmentRect.width, height: segmentRect.height)
                        .position(x: segmentRect.midX, y: segmentRect.midY)
                }

                ForEach(0 ..< rows, id: \.self) { row in
                    ForEach(0 ..< columns, id: \.self) { column in
                        let cellRect = previewGeometry.cellRect(column: column, row: row)
                        RoundedRectangle(cornerRadius: 8)
                            .fill(cellFillColor(column: column, row: row))
                            .frame(width: cellRect.width, height: cellRect.height)
                            .position(x: cellRect.midX, y: cellRect.midY)
                    }
                }

                RoundedRectangle(cornerRadius: 16)
                    .stroke(PreviewPalette.canvasBorder, lineWidth: 1)
                    .frame(width: previewGeometry.canvasRect.width, height: previewGeometry.canvasRect.height)
                    .position(x: previewGeometry.canvasRect.midX, y: previewGeometry.canvasRect.midY)

                ForEach(Array(overlays.enumerated()), id: \.element.id) { _, overlay in
                    overlayView(for: overlay, geometry: previewGeometry)
                }
            }
        }
    }

    private func cellFillColor(column: Int, row: Int) -> Color {
        (row + column).isMultiple(of: 2) ? PreviewPalette.primaryCellFill : PreviewPalette.secondaryCellFill
    }

    private func overlayView(for overlay: GridPreviewOverlayItem, geometry: GridPreviewGeometry) -> some View {
        let overlayRect = overlayRect(for: overlay.region, geometry: geometry)

        return RoundedRectangle(cornerRadius: 12)
            .fill(overlay.style.strokeColor.opacity(overlay.style.fillOpacity))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(overlay.style.strokeColor, lineWidth: overlay.style.strokeWidth)
            )
            .frame(width: overlayRect.width, height: overlayRect.height)
            .position(x: overlayRect.midX, y: overlayRect.midY)
    }

    private func overlayRect(for region: TriggerRegion, geometry: GridPreviewGeometry) -> CGRect {
        switch region {
        case let .screen(selection):
            return geometry.selectionRect(selection)
        case let .menuBar(selection):
            return geometry.menuBarSelectionRect(selection)
        }
    }
}

private enum PreviewPalette {
    static let previewBackground = Color(red: 0.18, green: 0.18, blue: 0.19)
    static let menuBarBackground = Color(red: 0.23, green: 0.23, blue: 0.24)
    static let menuBarForeground = Color.white.opacity(0.74)
    static let menuBarSegmentFill = Color.white.opacity(0.08)
    static let primaryCellFill = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let secondaryCellFill = Color(red: 0.24, green: 0.24, blue: 0.25)
    static let canvasBorder = Color.white.opacity(0.28)
}
