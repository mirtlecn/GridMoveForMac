import SwiftUI

struct SettingsRootView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Divider()

            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 1180, minHeight: 800)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $viewModel.excludedWindowSheetPresented) {
            ExcludedWindowSheetView { kind, value in
                viewModel.addExcludedWindow(kind: kind, value: value)
            }
        }
        .sheet(isPresented: $viewModel.modifierGroupSheetPresented) {
            ModifierGroupSheetView { group in
                viewModel.addModifierGroup(group)
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("GridMove")
                .font(.system(size: 28, weight: .bold))
                .padding(.top, 72)

            Spacer()
                .frame(height: 52)

            VStack(spacing: 10) {
                ForEach(SettingsViewModel.Section.allCases) { section in
                    SettingsSidebarTabButton(
                        title: section.title,
                        systemImage: section.systemImage,
                        isSelected: viewModel.selectedSection == section,
                        action: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                viewModel.selectedSection = section
                            }
                        }
                    )
                }
            }

            Spacer()
        }
        .padding(.horizontal, 18)
        .frame(minWidth: 270, idealWidth: 270, maxWidth: 270, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private var detailView: some View {
        switch viewModel.selectedSection {
        case .general:
            GeneralSettingsView(viewModel: viewModel)
        case .layouts:
            LayoutsSettingsView(viewModel: viewModel)
        case .appearance:
            AppearanceSettingsView(viewModel: viewModel)
        case .hotkeys:
            HotkeysSettingsView(viewModel: viewModel)
        case .about:
            AboutSettingsView()
        }
    }
}
