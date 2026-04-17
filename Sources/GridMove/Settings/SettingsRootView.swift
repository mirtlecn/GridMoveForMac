import SwiftUI

struct SettingsRootView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        NavigationSplitView {
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
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 260)
            .listStyle(.sidebar)
        } detail: {
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .navigationTitle(headerTitle)
        }
        .frame(minWidth: 860, minHeight: 660)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button(action: handleNavigateBack) {
                    Image(systemName: "chevron.left")
                }
                .disabled(!canNavigateBack)

                Button(action: handleNavigateForward) {
                    Image(systemName: "chevron.right")
                }
                .disabled(!canNavigateForward)
            }

            ToolbarItem(placement: .principal) {
                Text(headerTitle)
                    .font(.headline)
                    .lineLimit(1)
            }
        }
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
