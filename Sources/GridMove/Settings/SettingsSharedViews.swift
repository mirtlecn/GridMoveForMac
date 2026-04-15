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
            Text(binding.action == .cyclePrevious ? "Previous Layout" : "Next Layout")
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

struct TextEntrySheetView: View {
    let kind: SettingsViewModel.EntryKind
    let onConfirm: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var value = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(kind.prompt)
                .foregroundStyle(.secondary)
            TextField("", text: $value)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button(kind.confirmLabel) {
                    onConfirm(value)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}

struct ModifierGroupSheetView: View {
    let onConfirm: ([ModifierKey]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedKeys = Set<ModifierKey>()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose one or more modifier keys.")
                .foregroundStyle(.secondary)

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
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Add") {
                    onConfirm(ModifierKey.allCases.filter { selectedKeys.contains($0) })
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedKeys.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 320)
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
                .font(.system(size: 14, weight: .semibold))
        }
        .controlSize(.large)
    }
}

struct SettingsSwitchRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.medium))
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

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
    @Binding var shortcut: KeyboardShortcut

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

            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))

                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.9))
                    .overlay(alignment: .leading) {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.78))
                        .padding(.leading, 10)
                    }
                    .overlay(alignment: .trailing) {
                        Text("12:00")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.72))
                        .padding(.trailing, 10)
                    }
                    .frame(width: previewGeometry.menuBarRect.width, height: previewGeometry.menuBarRect.height)
                    .position(x: previewGeometry.menuBarRect.midX, y: previewGeometry.menuBarRect.midY)

                ForEach(0 ..< rows, id: \.self) { segment in
                    let segmentRect = previewGeometry.menuBarSegmentRect(segment: segment)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.08))
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
                    .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
                    .frame(width: previewGeometry.canvasRect.width, height: previewGeometry.canvasRect.height)
                    .position(x: previewGeometry.canvasRect.midX, y: previewGeometry.canvasRect.midY)

                ForEach(Array(overlays.enumerated()), id: \.element.id) { _, overlay in
                    overlayView(for: overlay, geometry: previewGeometry)
                }
            }
        }
    }

    private func cellFillColor(column: Int, row: Int) -> Color {
        let base = NSColor.controlBackgroundColor.blended(withFraction: 0.2, of: .black) ?? .controlBackgroundColor
        let alternate = NSColor.controlBackgroundColor.blended(withFraction: 0.08, of: .white) ?? .controlBackgroundColor
        return Color(nsColor: (row + column).isMultiple(of: 2) ? base : alternate)
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

struct AppearancePreviewSwiftUIView: View {
    let configuration: AppConfiguration

    private let previewColumns = 12
    private let previewRows = 6
    private let previewWindowSelection = GridSelection(x: 3, y: 1, w: 6, h: 4)
    private let previewTriggerSelection = GridSelection(x: 5, y: 2, w: 2, h: 2)

    var body: some View {
        SharedGridPreview(
            columns: previewColumns,
            rows: previewRows,
            overlays: appearancePreviewOverlays
        )
    }

    private var appearancePreviewOverlays: [GridPreviewOverlayItem] {
        var overlays: [GridPreviewOverlayItem] = []

        if configuration.appearance.renderWindowHighlight {
            overlays.append(
                GridPreviewOverlayItem(
                    id: "window",
                    region: .screen(previewWindowSelection),
                    style: GridPreviewOverlayStyle(
                        strokeColor: Color(configuration.appearance.highlightStrokeColor.nsColor),
                        fillOpacity: configuration.appearance.highlightFillOpacity,
                        strokeWidth: configuration.appearance.highlightStrokeWidth
                    )
                )
            )
        }

        if configuration.appearance.renderTriggerAreas {
            overlays.append(
                GridPreviewOverlayItem(
                    id: "trigger",
                    region: .screen(previewTriggerSelection),
                    style: GridPreviewOverlayStyle(
                        strokeColor: Color(configuration.appearance.triggerStrokeColor.nsColor),
                        fillOpacity: min(max(configuration.appearance.triggerOpacity * 0.45, 0.08), 0.35),
                        strokeWidth: 2
                    )
                )
            )
        }

        return overlays
    }
}
