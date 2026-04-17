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
                return UICopy.windowOverlayTitle
            case .triggerOverlay:
                return UICopy.triggerOverlayTitle
            }
        }
    }

    @ObservedObject var viewModel: SettingsViewModel
    @State private var selectedTab: AppearanceTab = .windowOverlay

    var body: some View {
        SettingsPreviewConfigurationPage {
            SharedGridPreview(
                columns: 12,
                rows: 6,
                overlays: appearancePreviewOverlays
            )
            .frame(height: 270)
        } controls: {
            Picker("", selection: $selectedTab) {
                ForEach(AppearanceTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: .infinity)

            SettingsFormSection(title: selectedTab.title) {
                switch selectedTab {
                case .windowOverlay:
                    windowOverlayConfiguration
                case .triggerOverlay:
                    triggerOverlayConfiguration
                }
            }

            HStack {
                Spacer()
                Button(UICopy.resetToDefaults) {
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
        Group {
            SettingsSwitchRow(
                title: UICopy.renderWindowArea,
                subtitle: UICopy.renderWindowAreaSubtitle,
                isOn: Binding(
                    get: { viewModel.configuration.appearance.renderWindowHighlight },
                    set: { newValue in
                        viewModel.updateAppearance { $0.renderWindowHighlight = newValue }
                    }
                )
            )

            LabeledSliderRow(
                title: UICopy.fillOpacity,
                value: Binding(
                    get: { viewModel.configuration.appearance.highlightFillOpacity },
                    set: { newValue in
                        viewModel.updateAppearance { $0.highlightFillOpacity = newValue }
                    }
                ),
                range: 0 ... 1
            )
            .disabled(!viewModel.configuration.appearance.renderWindowHighlight)

            LabeledNumberFieldRow(
                title: UICopy.strokeWidth,
                value: Binding(
                    get: { viewModel.configuration.appearance.highlightStrokeWidth },
                    set: { newValue in
                        viewModel.updateAppearance { $0.highlightStrokeWidth = newValue }
                    }
                )
            )
            .disabled(!viewModel.configuration.appearance.renderWindowHighlight)

            colorPickerRow(
                title: UICopy.strokeColor,
                color: Binding(
                    get: { Color(viewModel.configuration.appearance.highlightStrokeColor.nsColor) },
                    set: { newColor in
                        viewModel.updateAppearance {
                            $0.highlightStrokeColor = resolvedColor(from: newColor, fallback: .white)
                        }
                    }
                )
            )
            .disabled(!viewModel.configuration.appearance.renderWindowHighlight)
        }
    }

    private var triggerOverlayConfiguration: some View {
        Group {
            SettingsSwitchRow(
                title: UICopy.renderTriggerArea,
                subtitle: UICopy.renderTriggerAreaSubtitle,
                isOn: Binding(
                    get: { viewModel.configuration.appearance.renderTriggerAreas },
                    set: { newValue in
                        viewModel.updateAppearance { $0.renderTriggerAreas = newValue }
                    }
                )
            )

            LabeledSliderRow(
                title: UICopy.strokeOpacity,
                value: Binding(
                    get: { viewModel.configuration.appearance.triggerOpacity },
                    set: { newValue in
                        viewModel.updateAppearance { $0.triggerOpacity = newValue }
                    }
                ),
                range: 0 ... 1
            )
            .disabled(!viewModel.configuration.appearance.renderTriggerAreas)

            LabeledNumberFieldRow(
                title: UICopy.gridGap,
                value: Binding(
                    get: { viewModel.configuration.appearance.triggerGap },
                    set: { newValue in
                        viewModel.updateAppearance { $0.triggerGap = newValue }
                    }
                )
            )
            .disabled(!viewModel.configuration.appearance.renderTriggerAreas)

            colorPickerRow(
                title: UICopy.strokeColor,
                color: Binding(
                    get: { Color(viewModel.configuration.appearance.triggerStrokeColor.nsColor) },
                    set: { newColor in
                        viewModel.updateAppearance {
                            $0.triggerStrokeColor = resolvedColor(from: newColor, fallback: .systemBlue)
                        }
                    }
                )
            )
            .disabled(!viewModel.configuration.appearance.renderTriggerAreas)
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
        LabeledContent(title) {
            ColorPicker("", selection: color, supportsOpacity: true)
                .labelsHidden()
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
