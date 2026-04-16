import AppKit
import SwiftUI

struct AppearanceSettingsView: View {
    enum AppearanceTab: String, CaseIterable, Identifiable {
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
    @State private var selectedTab: AppearanceTab = .windowOverlay

    var body: some View {
        SettingsPreviewConfigurationPage {
            previewPanel
        } controls: {
            configurationPanel
        }
    }

    private var previewPanel: some View {
        SharedGridPreview(
            columns: 12,
            rows: 6,
            overlays: appearancePreviewOverlays
        )
        .frame(height: 270)
    }

    private var configurationPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            Picker("", selection: $selectedTab) {
                ForEach(AppearanceTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: .infinity)

            switch selectedTab {
            case .windowOverlay:
                windowOverlayConfiguration
            case .triggerOverlay:
                triggerOverlayConfiguration
            }

            HStack {
                Spacer()
                Button("Reset to Defaults") {
                    switch selectedTab {
                    case .windowOverlay:
                        viewModel.resetWindowAppearanceToDefaults()
                    case .triggerOverlay:
                        viewModel.resetTriggerAppearanceToDefaults()
                    }
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var windowOverlayConfiguration: some View {
        SettingsGroupedRows {
            SettingsGroupedRow {
                SettingsSwitchRow(
                    title: "Render Window Area",
                    subtitle: "Show the current or target window preview while dragging.",
                    isOn: Binding(
                        get: { viewModel.configuration.appearance.renderWindowHighlight },
                        set: { newValue in
                            viewModel.updateAppearance { $0.renderWindowHighlight = newValue }
                        }
                    )
                )
            }

            Divider()

            SettingsGroupedRow {
                LabeledSliderRow(
                    title: "Fill Opacity",
                    value: Binding(
                        get: { viewModel.configuration.appearance.highlightFillOpacity },
                        set: { newValue in
                            viewModel.updateAppearance { $0.highlightFillOpacity = newValue }
                        }
                    ),
                    range: 0 ... 1
                )
            }
            .allowsHitTesting(viewModel.configuration.appearance.renderWindowHighlight)
            .opacity(viewModel.configuration.appearance.renderWindowHighlight ? 1 : 0.45)

            Divider()

            SettingsGroupedRow {
                LabeledNumberFieldRow(
                    title: "Stroke Width",
                    value: Binding(
                        get: { viewModel.configuration.appearance.highlightStrokeWidth },
                        set: { newValue in
                            viewModel.updateAppearance { $0.highlightStrokeWidth = newValue }
                        }
                    )
                )
            }
            .allowsHitTesting(viewModel.configuration.appearance.renderWindowHighlight)
            .opacity(viewModel.configuration.appearance.renderWindowHighlight ? 1 : 0.45)

            Divider()

            SettingsGroupedRow {
                colorPickerRow(
                    title: "Stroke Color",
                    color: Binding(
                        get: { Color(viewModel.configuration.appearance.highlightStrokeColor.nsColor) },
                        set: { newColor in
                            viewModel.updateAppearance {
                                $0.highlightStrokeColor = resolvedColor(from: newColor, fallback: .white)
                            }
                        }
                    )
                )
            }
            .allowsHitTesting(viewModel.configuration.appearance.renderWindowHighlight)
            .opacity(viewModel.configuration.appearance.renderWindowHighlight ? 1 : 0.45)
        }
    }

    private var triggerOverlayConfiguration: some View {
        SettingsGroupedRows {
            SettingsGroupedRow {
                SettingsSwitchRow(
                    title: "Render Trigger Area",
                    subtitle: "Show trigger regions while dragging across the screen or menu bar.",
                    isOn: Binding(
                        get: { viewModel.configuration.appearance.renderTriggerAreas },
                        set: { newValue in
                            viewModel.updateAppearance { $0.renderTriggerAreas = newValue }
                        }
                    )
                )
            }

            Divider()

            SettingsGroupedRow {
                LabeledSliderRow(
                    title: "Stroke Opacity",
                    value: Binding(
                        get: { viewModel.configuration.appearance.triggerOpacity },
                        set: { newValue in
                            viewModel.updateAppearance { $0.triggerOpacity = newValue }
                        }
                    ),
                    range: 0 ... 1
                )
            }
            .allowsHitTesting(viewModel.configuration.appearance.renderTriggerAreas)
            .opacity(viewModel.configuration.appearance.renderTriggerAreas ? 1 : 0.45)

            Divider()

            SettingsGroupedRow {
                LabeledNumberFieldRow(
                    title: "Grid Gap",
                    value: Binding(
                        get: { viewModel.configuration.appearance.triggerGap },
                        set: { newValue in
                            viewModel.updateAppearance { $0.triggerGap = newValue }
                        }
                    )
                )
            }
            .allowsHitTesting(viewModel.configuration.appearance.renderTriggerAreas)
            .opacity(viewModel.configuration.appearance.renderTriggerAreas ? 1 : 0.45)

            Divider()

            SettingsGroupedRow {
                colorPickerRow(
                    title: "Stroke Color",
                    color: Binding(
                        get: { Color(viewModel.configuration.appearance.triggerStrokeColor.nsColor) },
                        set: { newColor in
                            viewModel.updateAppearance {
                                $0.triggerStrokeColor = resolvedColor(from: newColor, fallback: .systemBlue)
                            }
                        }
                    )
                )
            }
            .allowsHitTesting(viewModel.configuration.appearance.renderTriggerAreas)
            .opacity(viewModel.configuration.appearance.renderTriggerAreas ? 1 : 0.45)
        }
    }

    private var appearancePreviewOverlays: [GridPreviewOverlayItem] {
        var overlays: [GridPreviewOverlayItem] = []

        if viewModel.configuration.appearance.renderWindowHighlight {
            overlays.append(
                GridPreviewOverlayItem(
                    id: "window-preview",
                    region: .screen(GridSelection(x: 3, y: 1, w: 6, h: 4)),
                    style: GridPreviewOverlayStyle(
                        strokeColor: Color(viewModel.configuration.appearance.highlightStrokeColor.nsColor),
                        fillOpacity: viewModel.configuration.appearance.highlightFillOpacity,
                        strokeWidth: viewModel.configuration.appearance.highlightStrokeWidth
                    )
                )
            )
        }

        if viewModel.configuration.appearance.renderTriggerAreas {
            overlays.append(
                GridPreviewOverlayItem(
                    id: "trigger-preview",
                    region: .screen(GridSelection(x: 5, y: 2, w: 2, h: 2)),
                    style: GridPreviewOverlayStyle(
                        strokeColor: Color(viewModel.configuration.appearance.triggerStrokeColor.nsColor),
                        fillOpacity: min(max(viewModel.configuration.appearance.triggerOpacity * 0.45, 0.08), 0.35),
                        strokeWidth: 2
                    )
                )
            )
        }

        return overlays
    }

    private func colorPickerRow(title: String, color: Binding<Color>) -> some View {
        HStack(spacing: 14) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 130, alignment: .leading)

            ColorPicker("", selection: color, supportsOpacity: true)
                .labelsHidden()

            Spacer(minLength: 0)
        }
    }

    private func resolvedColor(from color: Color, fallback: NSColor) -> RGBAColor {
        let nsColor = NSColor(color)
        let resolved = nsColor.usingColorSpace(.deviceRGB) ?? fallback
        return RGBAColor(
            red: resolved.redComponent,
            green: resolved.greenComponent,
            blue: resolved.blueComponent,
            alpha: resolved.alphaComponent
        )
    }
}
