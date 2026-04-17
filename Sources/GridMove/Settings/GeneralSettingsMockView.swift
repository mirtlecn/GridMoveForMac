import SwiftUI

struct GeneralSettingsMockView: View {
    private struct ModifierGroupRow: Identifiable {
        let id: String
        let title: String
    }

    private struct ExcludedWindowRow: Identifiable {
        let id: String
        let value: String
        let type: String
    }

    private let modifierGroups = [
        ModifierGroupRow(id: "option", title: "Option"),
        ModifierGroupRow(id: "shift-option", title: "Shift + Option"),
    ]

    private let excludedWindows = [
        ExcludedWindowRow(id: "finder", value: "com.apple.finder", type: UICopy.bundleIDTitle),
        ExcludedWindowRow(id: "picture-in-picture", value: "Picture in Picture", type: UICopy.windowTitle),
    ]

    @State private var isEnabled = true
    @State private var enableMiddleMouse = true
    @State private var enableModifierLeftMouse = true
    @State private var selectedModifierGroupID: String? = "option"
    @State private var selectedExcludedWindowID: String? = "finder"

    var body: some View {
        Form {
            Section {
                Toggle(
                    isOn: $isEnabled,
                    label: {
                        SettingsMockDescriptionLabel(
                            title: UICopy.enableTitle,
                            subtitle: UICopy.enableSubtitle
                        )
                    }
                )
            }

            Section(UICopy.pressAndDragSectionTitle) {
                Toggle(
                    isOn: $enableMiddleMouse,
                    label: {
                        SettingsMockDescriptionLabel(
                            title: UICopy.middleMouseTitle,
                            subtitle: UICopy.middleMouseSubtitle
                        )
                    }
                )

                GroupBox {
                    VStack(alignment: .leading) {
                        Toggle(
                            isOn: $enableModifierLeftMouse,
                            label: {
                                SettingsMockDescriptionLabel(
                                    title: UICopy.modifierLeftMouseTitle,
                                    subtitle: UICopy.modifierLeftMouseSubtitle
                                )
                            }
                        )

                        List(modifierGroups, selection: $selectedModifierGroupID) { item in
                            Text(item.title)
                                .tag(item.id)
                        }
                        .frame(minHeight: 96)
                        .disabled(!enableModifierLeftMouse)

                        HStack {
                            Button(UICopy.add) {}
                            Button(UICopy.delete) {}
                            Spacer()
                        }
                        .disabled(!enableModifierLeftMouse)
                    }
                }
            }

            Section(UICopy.excludedWindowsSectionTitle) {
                GroupBox {
                    VStack(alignment: .leading) {
                        Table(excludedWindows, selection: $selectedExcludedWindowID) {
                            TableColumn(UICopy.valueColumnTitle) { item in
                                Text(item.value)
                            }

                            TableColumn(UICopy.typeColumnTitle) { item in
                                Text(item.type)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(minHeight: 180)

                        HStack {
                            Button(UICopy.add) {}
                            Button(UICopy.delete) {}
                            Spacer()
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct SettingsMockDescriptionLabel: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
