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

    func makeNSView(context: Context) -> GridSelectionEditorView {
        let view = GridSelectionEditorView(columns: columns, rows: rows)
        view.selectionColor = selectionColor
        view.onSelectionChanged = { nextSelection in
            selection = GridSelection(x: nextSelection.x, y: nextSelection.y, w: nextSelection.w, h: nextSelection.h)
        }
        return view
    }

    func updateNSView(_ nsView: GridSelectionEditorView, context: Context) {
        nsView.columns = columns
        nsView.rows = rows
        nsView.selectionColor = selectionColor
        nsView.selection = CellSelection(x: selection.x, y: selection.y, w: selection.w, h: selection.h)
        nsView.onSelectionChanged = { nextSelection in
            selection = GridSelection(x: nextSelection.x, y: nextSelection.y, w: nextSelection.w, h: nextSelection.h)
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

struct AppearancePreviewSwiftUIView: View {
    let configuration: AppConfiguration

    var body: some View {
        GeometryReader { geometry in
            let screenRect = geometry.frame(in: .local).insetBy(dx: 24, dy: 24)
            let preset = configuration.layouts.first ?? AppConfiguration.defaultLayouts[0]
            let engine = LayoutEngine()
            let triggerFrame = engine.frame(
                for: preset.triggerSelection,
                columns: preset.gridColumns,
                rows: preset.gridRows,
                in: screenRect
            ).insetBy(dx: configuration.appearance.triggerGap, dy: configuration.appearance.triggerGap)
            let windowFrame = engine.frame(
                for: preset.windowSelection,
                columns: preset.gridColumns,
                rows: preset.gridRows,
                in: screenRect
            )

            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(nsColor: .controlBackgroundColor))

                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
                    .frame(width: screenRect.width, height: screenRect.height)
                    .position(x: screenRect.midX, y: screenRect.midY)

                if configuration.appearance.renderTriggerAreas {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.accentColor.opacity(configuration.appearance.triggerOpacity), lineWidth: 2)
                        .frame(width: triggerFrame.width, height: triggerFrame.height)
                        .position(x: triggerFrame.midX, y: triggerFrame.midY)
                }

                if configuration.appearance.renderWindowHighlight {
                    let color = Color(configuration.appearance.highlightStrokeColor.nsColor)
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(configuration.appearance.highlightFillOpacity))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(color, lineWidth: configuration.appearance.highlightStrokeWidth)
                        )
                        .frame(width: windowFrame.width, height: windowFrame.height)
                        .position(x: windowFrame.midX, y: windowFrame.midY)
                }
            }
        }
    }
}
