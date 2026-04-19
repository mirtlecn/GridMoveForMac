import AppKit
import Foundation

extension AppConfiguration {
    static let builtInExcludedBundleIDs = [
        "com.apple.Spotlight",
        "com.apple.dock",
        "com.apple.notificationcenterui",
    ]

    static var defaultLayouts: [LayoutPreset] {
        [
            LayoutPreset(id: "layout-1", name: UICopy.defaultLayoutNames[0], gridColumns: 12, gridRows: 6, windowSelection: GridSelection(x: 0, y: 0, w: 4, h: 6), triggerRegion: .screen(GridSelection(x: 0, y: 0, w: 2, h: 6)), includeInLayoutIndex: true),
            LayoutPreset(id: "layout-2", name: UICopy.defaultLayoutNames[1], gridColumns: 12, gridRows: 6, windowSelection: GridSelection(x: 0, y: 0, w: 6, h: 6), triggerRegion: .screen(GridSelection(x: 2, y: 2, w: 3, h: 2)), includeInLayoutIndex: true),
            LayoutPreset(id: "layout-3", name: UICopy.defaultLayoutNames[2], gridColumns: 12, gridRows: 6, windowSelection: GridSelection(x: 0, y: 0, w: 8, h: 6), triggerRegion: .screen(GridSelection(x: 2, y: 0, w: 3, h: 2)), includeInLayoutIndex: true),
            LayoutPreset(id: "layout-4", name: UICopy.defaultLayoutNames[3], gridColumns: 12, gridRows: 6, windowSelection: GridSelection(x: 3, y: 1, w: 6, h: 4), triggerRegion: .screen(GridSelection(x: 5, y: 2, w: 2, h: 2)), includeInLayoutIndex: true),
            LayoutPreset(id: "layout-5", name: UICopy.defaultLayoutNames[4], gridColumns: 12, gridRows: 6, windowSelection: GridSelection(x: 4, y: 0, w: 8, h: 6), triggerRegion: .screen(GridSelection(x: 7, y: 0, w: 3, h: 2)), includeInLayoutIndex: true),
            LayoutPreset(id: "layout-6", name: UICopy.defaultLayoutNames[5], gridColumns: 12, gridRows: 6, windowSelection: GridSelection(x: 6, y: 0, w: 6, h: 6), triggerRegion: .screen(GridSelection(x: 7, y: 2, w: 3, h: 2)), includeInLayoutIndex: true),
            LayoutPreset(id: "layout-7", name: UICopy.defaultLayoutNames[6], gridColumns: 12, gridRows: 6, windowSelection: GridSelection(x: 8, y: 0, w: 4, h: 6), triggerRegion: .screen(GridSelection(x: 10, y: 2, w: 2, h: 2)), includeInLayoutIndex: true),
            LayoutPreset(id: "layout-8", name: UICopy.defaultLayoutNames[7], gridColumns: 12, gridRows: 6, windowSelection: GridSelection(x: 8, y: 0, w: 4, h: 3), triggerRegion: .screen(GridSelection(x: 10, y: 0, w: 2, h: 2)), includeInLayoutIndex: true),
            LayoutPreset(id: "layout-9", name: UICopy.defaultLayoutNames[8], gridColumns: 12, gridRows: 6, windowSelection: GridSelection(x: 8, y: 3, w: 4, h: 3), triggerRegion: .screen(GridSelection(x: 10, y: 4, w: 2, h: 2)), includeInLayoutIndex: true),
            LayoutPreset(id: "layout-10", name: UICopy.defaultLayoutNames[9], gridColumns: 12, gridRows: 6, windowSelection: GridSelection(x: 0, y: 0, w: 12, h: 6), triggerRegion: .screen(GridSelection(x: 5, y: 0, w: 2, h: 2)), includeInLayoutIndex: true),
            LayoutPreset(id: "layout-11", name: UICopy.defaultLayoutNames[10], gridColumns: 12, gridRows: 6, windowSelection: GridSelection(x: 0, y: 0, w: 12, h: 6), triggerRegion: .menuBar(MenuBarSelection(x: 0, w: 6)), includeInLayoutIndex: false, includeInMenu: false),
        ]
    }

    static var defaultLayoutGroups: [LayoutGroup] {
        [
            LayoutGroup(
                name: builtInGroupName,
                includeInGroupCycle: true,
                protect: true,
                sets: [
                    LayoutSet(monitor: .all, layouts: defaultLayouts),
                ]
            ),
            LayoutGroup(
                name: fullscreenGroupName,
                includeInGroupCycle: true,
                protect: true,
                sets: [
                    LayoutSet(
                        monitor: .main,
                        layouts: [
                            LayoutPreset(
                                id: "layout-12",
                                name: "Fullscreen main",
                                gridColumns: 12,
                                gridRows: 6,
                                windowSelection: GridSelection(x: 0, y: 0, w: 12, h: 6),
                                triggerRegion: .screen(GridSelection(x: 0, y: 0, w: 12, h: 6)),
                                includeInLayoutIndex: true
                            ),
                            LayoutPreset(
                                id: "layout-13",
                                name: "Main left 1/2",
                                gridColumns: 12,
                                gridRows: 6,
                                windowSelection: GridSelection(x: 0, y: 0, w: 6, h: 6),
                                triggerRegion: .screen(GridSelection(x: 0, y: 0, w: 3, h: 6)),
                                includeInLayoutIndex: true
                            ),
                            LayoutPreset(
                                id: "layout-14",
                                name: "Main right 1/2",
                                gridColumns: 12,
                                gridRows: 6,
                                windowSelection: GridSelection(x: 6, y: 0, w: 6, h: 6),
                                triggerRegion: .screen(GridSelection(x: 9, y: 0, w: 3, h: 6)),
                                includeInLayoutIndex: true
                            ),
                            LayoutPreset(
                                id: "layout-15",
                                name: "Fullscreen main (menu bar)",
                                gridColumns: 12,
                                gridRows: 6,
                                windowSelection: GridSelection(x: 0, y: 0, w: 12, h: 6),
                                triggerRegion: .menuBar(MenuBarSelection(x: 0, w: 6)),
                                includeInLayoutIndex: false,
                                includeInMenu: false
                            ),
                        ]
                    ),
                    LayoutSet(
                        monitor: .all,
                        layouts: [
                            LayoutPreset(
                                id: "layout-16",
                                name: "Fullscreen other",
                                gridColumns: 12,
                                gridRows: 6,
                                windowSelection: GridSelection(x: 0, y: 0, w: 12, h: 6),
                                triggerRegion: .screen(GridSelection(x: 0, y: 0, w: 12, h: 6)),
                                includeInLayoutIndex: true
                            ),
                            LayoutPreset(
                                id: "layout-17",
                                name: "Fullscreen other (menu bar)",
                                gridColumns: 12,
                                gridRows: 6,
                                windowSelection: GridSelection(x: 0, y: 0, w: 12, h: 6),
                                triggerRegion: .menuBar(MenuBarSelection(x: 0, w: 6)),
                                includeInLayoutIndex: false,
                                includeInMenu: false
                            ),
                        ]
                    ),
                ]
            ),
        ]
    }

    static var defaultBindings: [ShortcutBinding] {
        [
            ShortcutBinding(shortcut: KeyboardShortcut(modifiers: [.ctrl, .cmd, .shift, .alt], key: "l"), action: .cycleNext),
            ShortcutBinding(shortcut: KeyboardShortcut(modifiers: [.ctrl, .cmd, .shift, .alt], key: "j"), action: .cyclePrevious),
            ShortcutBinding(shortcut: KeyboardShortcut(modifiers: [.ctrl, .cmd, .shift, .alt], key: "\\"), action: .applyLayoutByIndex(layout: 4)),
            ShortcutBinding(shortcut: KeyboardShortcut(modifiers: [.ctrl, .cmd, .shift, .alt], key: "["), action: .applyLayoutByIndex(layout: 2)),
            ShortcutBinding(shortcut: KeyboardShortcut(modifiers: [.ctrl, .cmd, .shift, .alt], key: "]"), action: .applyLayoutByIndex(layout: 6)),
            ShortcutBinding(shortcut: KeyboardShortcut(modifiers: [.ctrl, .cmd, .shift, .alt], key: ";"), action: .applyLayoutByIndex(layout: 3)),
            ShortcutBinding(shortcut: KeyboardShortcut(modifiers: [.ctrl, .cmd, .shift, .alt], key: "'"), action: .applyLayoutByIndex(layout: 7)),
            ShortcutBinding(shortcut: KeyboardShortcut(modifiers: [.ctrl, .cmd, .shift, .alt], key: "-"), action: .applyLayoutByIndex(layout: 1)),
            ShortcutBinding(shortcut: KeyboardShortcut(modifiers: [.ctrl, .cmd, .shift, .alt], key: "="), action: .applyLayoutByIndex(layout: 5)),
            ShortcutBinding(shortcut: KeyboardShortcut(modifiers: [.ctrl, .cmd, .shift, .alt], key: "return"), action: .applyLayoutByIndex(layout: 10)),
        ]
    }

    static let defaultValue = AppConfiguration(
        general: GeneralSettings(
            isEnabled: true,
            launchAtLogin: false,
            excludedBundleIDs: ["com.apple.Spotlight"],
            excludedWindowTitles: [],
            activeLayoutGroup: builtInGroupName,
            mouseButtonNumber: 3
        ),
        appearance: AppearanceSettings(
            renderTriggerAreas: false,
            triggerGap: 2,
            triggerStrokeColor: .defaultTriggerStrokeColor,
            layoutGap: 1,
            renderWindowHighlight: true,
            highlightFillOpacity: 0.08,
            highlightStrokeWidth: 3,
            highlightStrokeColor: RGBAColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.92)
        ),
        dragTriggers: DragTriggerSettings(
            enableMouseButtonDrag: true,
            enableModifierLeftMouseDrag: true,
            preferLayoutMode: true,
            modifierGroups: [
                [.ctrl, .cmd, .shift, .alt],
                [.ctrl, .shift, .alt],
            ],
            activationDelaySeconds: 0.3,
            activationMoveThreshold: 10
        ),
        hotkeys: HotkeySettings(bindings: defaultBindings),
        layoutGroups: defaultLayoutGroups,
        monitors: [:]
    )
}

extension RGBAColor {
    static var defaultTriggerStrokeColor: RGBAColor {
        let resolvedColor = NSColor.controlAccentColor.usingColorSpace(.deviceRGB) ?? .systemBlue
        return RGBAColor(
            red: resolvedColor.redComponent,
            green: resolvedColor.greenComponent,
            blue: resolvedColor.blueComponent,
            alpha: 0.2
        )
    }
}
