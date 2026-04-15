import AppKit
import SwiftUI

struct AppearanceSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 18) {
                    SettingsCard(title: "Trigger Overlay") {
                        VStack(alignment: .leading, spacing: 14) {
                            Toggle(
                                "Render Trigger Areas",
                                isOn: Binding(
                                    get: { viewModel.configuration.appearance.renderTriggerAreas },
                                    set: { newValue in
                                        viewModel.updateAppearance { $0.renderTriggerAreas = newValue }
                                    }
                                )
                            )

                            if viewModel.configuration.appearance.renderTriggerAreas {
                                LabeledSliderRow(
                                    title: "Trigger Opacity",
                                    value: Binding(
                                        get: { viewModel.configuration.appearance.triggerOpacity },
                                        set: { newValue in
                                            viewModel.updateAppearance { $0.triggerOpacity = newValue }
                                        }
                                    ),
                                    range: 0 ... 1
                                )

                                HStack {
                                    Text("Trigger Stroke Color")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 130, alignment: .leading)
                                    ColorPicker(
                                        "",
                                        selection: Binding(
                                            get: { Color(viewModel.configuration.appearance.triggerStrokeColor.nsColor) },
                                            set: { newColor in
                                                let nsColor = NSColor(newColor)
                                                let resolved = nsColor.usingColorSpace(.deviceRGB) ?? .controlAccentColor
                                                viewModel.updateAppearance {
                                                    $0.triggerStrokeColor = RGBAColor(
                                                        red: resolved.redComponent,
                                                        green: resolved.greenComponent,
                                                        blue: resolved.blueComponent,
                                                        alpha: resolved.alphaComponent
                                                    )
                                                }
                                            }
                                        )
                                    )
                                    .labelsHidden()
                                }

                                LabeledNumberFieldRow(
                                    title: "Trigger Gap",
                                    value: Binding(
                                        get: { viewModel.configuration.appearance.triggerGap },
                                        set: { newValue in
                                            viewModel.updateAppearance { $0.triggerGap = newValue }
                                        }
                                    )
                                )
                            }
                        }
                    }

                    SettingsCard(title: "Window Highlight") {
                        VStack(alignment: .leading, spacing: 14) {
                            Toggle(
                                "Render Window Highlight",
                                isOn: Binding(
                                    get: { viewModel.configuration.appearance.renderWindowHighlight },
                                    set: { newValue in
                                        viewModel.updateAppearance { $0.renderWindowHighlight = newValue }
                                    }
                                )
                            )

                            if viewModel.configuration.appearance.renderWindowHighlight {
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

                                LabeledNumberFieldRow(
                                    title: "Stroke Width",
                                    value: Binding(
                                        get: { viewModel.configuration.appearance.highlightStrokeWidth },
                                        set: { newValue in
                                            viewModel.updateAppearance { $0.highlightStrokeWidth = newValue }
                                        }
                                    )
                                )

                                HStack {
                                    Text("Stroke Color")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 130, alignment: .leading)
                                    ColorPicker(
                                        "",
                                        selection: Binding(
                                            get: { Color(viewModel.configuration.appearance.highlightStrokeColor.nsColor) },
                                            set: { newColor in
                                                let nsColor = NSColor(newColor)
                                                let resolved = nsColor.usingColorSpace(.deviceRGB) ?? .systemOrange
                                                viewModel.updateAppearance {
                                                    $0.highlightStrokeColor = RGBAColor(
                                                        red: resolved.redComponent,
                                                        green: resolved.greenComponent,
                                                        blue: resolved.blueComponent,
                                                        alpha: resolved.alphaComponent
                                                    )
                                                }
                                            }
                                        )
                                    )
                                    .labelsHidden()
                                }
                            }
                        }
                    }
                }
                .frame(width: 360)

                SettingsCard(title: "Preview") {
                    AppearancePreviewSwiftUIView(configuration: viewModel.configuration)
                        .frame(minHeight: 460)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}
