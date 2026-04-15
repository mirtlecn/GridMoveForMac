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
        .frame(minWidth: 920, minHeight: 660)
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
                .font(.title2.weight(.bold))
                .padding(.horizontal, 14)
                .padding(.top, 32)

            Spacer()
                .frame(height: 20)

            List(selection: $viewModel.selectedSection) {
                ForEach(SettingsViewModel.Section.allCases) { section in
                    Label(section.title, systemImage: section.systemImage)
                        .tag(section)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            Spacer()
        }
        .frame(minWidth: 228, idealWidth: 228, maxWidth: 228, maxHeight: .infinity, alignment: .topLeading)
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
