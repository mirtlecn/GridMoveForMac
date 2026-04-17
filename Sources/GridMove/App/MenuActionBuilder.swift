import Foundation

struct MenuActionBuilder {
    func buildActionItems(configuration: AppConfiguration) -> [MenuBarController.ActionItem] {
        cycleItems(configuration: configuration) + layoutItems(configuration: configuration)
    }

    private func cycleItems(configuration: AppConfiguration) -> [MenuBarController.ActionItem] {
        [
            MenuBarController.ActionItem(
                title: UICopy.applyPreviousLayout,
                action: .cyclePrevious,
                shortcut: configuration.hotkeys.firstShortcut(for: .cyclePrevious)
            ),
            MenuBarController.ActionItem(
                title: UICopy.applyNextLayout,
                action: .cycleNext,
                shortcut: configuration.hotkeys.firstShortcut(for: .cycleNext)
            ),
        ]
    }

    private func layoutItems(configuration: AppConfiguration) -> [MenuBarController.ActionItem] {
        let layoutIndexByID = Dictionary(
            uniqueKeysWithValues: LayoutGroupResolver.indexedActiveEntries(in: configuration).enumerated().map { offset, entry in
                (entry.layout.id, offset + 1)
            }
        )

        return LayoutGroupResolver.activeGroup(in: configuration)?.sets.flatMap { set in
            set.layouts.compactMap { layout in
                guard layout.includeInMenu else {
                    return nil
                }

                let title = UICopy.applyLayout(
                    UICopy.layoutMenuName(
                        name: layout.name,
                        fallbackIdentifier: layout.id
                    )
                )
                let shortcut = layoutIndexByID[layout.id].flatMap {
                    configuration.hotkeys.firstShortcut(for: .applyLayoutByIndex(layout: $0))
                }

                return MenuBarController.ActionItem(
                    title: title,
                    action: .applyLayoutByID(layoutID: layout.id),
                    shortcut: shortcut
                )
            }
        } ?? []
    }
}
