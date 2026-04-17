import AppKit

enum PreferenceHotkeyIconCatalog {
    static func image(for action: HotkeyAction, configuration: AppConfiguration) -> NSImage? {
        guard let resourceName = resourceName(for: action, configuration: configuration),
              let resourceURL = Bundle.module.url(
                forResource: resourceName,
                withExtension: "png"
              ) else {
            return nil
        }

        let image = NSImage(contentsOf: resourceURL)
        image?.isTemplate = false
        return image
    }

    private static func resourceName(for action: HotkeyAction, configuration: AppConfiguration) -> String? {
        switch action {
        case let .applyLayout(layoutID):
            guard let layout = configuration.layouts.first(where: { $0.id == layoutID }) else {
                return nil
            }
            return resourceName(for: layout.name)
        case .cyclePrevious:
            return "prevDisplayTemplate"
        case .cycleNext:
            return "nextDisplayTemplate"
        }
    }

    private static func resourceName(for layoutName: String) -> String? {
        switch layoutName {
        case UICopy.defaultLayoutNames[0]:
            return "firstThirdTemplate"
        case UICopy.defaultLayoutNames[1]:
            return "leftHalfTemplate"
        case UICopy.defaultLayoutNames[2]:
            return "firstTwoThirdsTemplate"
        case UICopy.defaultLayoutNames[3]:
            return "centerTemplate"
        case UICopy.defaultLayoutNames[4]:
            return "lastTwoThirdsTemplate"
        case UICopy.defaultLayoutNames[5]:
            return "rightHalfTemplate"
        case UICopy.defaultLayoutNames[6]:
            return "lastThirdTemplate"
        case UICopy.defaultLayoutNames[7]:
            return "topRightSixthTemplate"
        case UICopy.defaultLayoutNames[8]:
            return "bottomRightSixthTemplate"
        case UICopy.defaultLayoutNames[9]:
            return "maximizeTemplate"
        case UICopy.defaultLayoutNames[10]:
            return "almostMaximizeTemplate"
        default:
            return nil
        }
    }
}
