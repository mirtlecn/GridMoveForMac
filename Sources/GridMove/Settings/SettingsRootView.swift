import SwiftUI

struct SettingsRootView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Divider()

            detailColumn
        }
        .frame(minWidth: 860, minHeight: 620)
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
            Text(UICopy.appName)
                .font(.largeTitle.weight(.bold))
                .padding(.horizontal, 12)
                .padding(.top, 18)

            Spacer()
                .frame(height: 14)

            List(
                selection: Binding(
                    get: { viewModel.selectedSection },
                    set: { nextSection in
                        if let nextSection {
                            viewModel.navigateToSection(nextSection)
                        }
                    }
                )
            ) {
                ForEach(SettingsViewModel.Section.allCases) { section in
                    SettingsSidebarRowLabel(
                        title: section.title,
                        systemImage: section.systemImage
                    )
                        .tag(section)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 36)

            Spacer()
        }
        .frame(minWidth: 220, idealWidth: 220, maxWidth: 220, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var detailColumn: some View {
        VStack(spacing: 0) {
            SettingsDetailHeaderBar(
                title: headerTitle,
                canNavigateBack: canNavigateBack,
                canNavigateForward: canNavigateForward,
                onNavigateBack: handleNavigateBack,
                onNavigateForward: handleNavigateForward
            )
            Divider()
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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

    private var headerTitle: String {
        if viewModel.selectedSection == .layouts, viewModel.layoutPageMode == .detail {
            return viewModel.selectedLayoutDisplayID
        }
        return viewModel.selectedSection.title
    }

    private var canNavigateBack: Bool {
        if viewModel.selectedSection == .layouts, viewModel.layoutPageMode == .detail {
            return true
        }
        return viewModel.canNavigateBack
    }

    private var canNavigateForward: Bool {
        if viewModel.selectedSection == .layouts {
            return viewModel.canNavigateToLayoutDetail || viewModel.canNavigateForward
        }
        return viewModel.canNavigateForward
    }

    private func handleNavigateBack() {
        if viewModel.selectedSection == .layouts, viewModel.layoutPageMode == .detail {
            viewModel.showLayoutsList()
            return
        }
        viewModel.navigateBack()
    }

    private func handleNavigateForward() {
        if viewModel.selectedSection == .layouts, viewModel.canNavigateToLayoutDetail {
            viewModel.reopenLayoutDetail()
            return
        }
        viewModel.navigateForward()
    }
}
