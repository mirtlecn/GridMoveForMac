import Carbon.HIToolbox
import Foundation

enum ShortcutKeyMap {
    private static let keyCodeByName: [String: CGKeyCode] = [
        "a": CGKeyCode(kVK_ANSI_A),
        "b": CGKeyCode(kVK_ANSI_B),
        "c": CGKeyCode(kVK_ANSI_C),
        "d": CGKeyCode(kVK_ANSI_D),
        "e": CGKeyCode(kVK_ANSI_E),
        "f": CGKeyCode(kVK_ANSI_F),
        "g": CGKeyCode(kVK_ANSI_G),
        "h": CGKeyCode(kVK_ANSI_H),
        "i": CGKeyCode(kVK_ANSI_I),
        "j": CGKeyCode(kVK_ANSI_J),
        "k": CGKeyCode(kVK_ANSI_K),
        "l": CGKeyCode(kVK_ANSI_L),
        "m": CGKeyCode(kVK_ANSI_M),
        "n": CGKeyCode(kVK_ANSI_N),
        "o": CGKeyCode(kVK_ANSI_O),
        "p": CGKeyCode(kVK_ANSI_P),
        "q": CGKeyCode(kVK_ANSI_Q),
        "r": CGKeyCode(kVK_ANSI_R),
        "s": CGKeyCode(kVK_ANSI_S),
        "t": CGKeyCode(kVK_ANSI_T),
        "u": CGKeyCode(kVK_ANSI_U),
        "v": CGKeyCode(kVK_ANSI_V),
        "w": CGKeyCode(kVK_ANSI_W),
        "x": CGKeyCode(kVK_ANSI_X),
        "y": CGKeyCode(kVK_ANSI_Y),
        "z": CGKeyCode(kVK_ANSI_Z),
        "0": CGKeyCode(kVK_ANSI_0),
        "1": CGKeyCode(kVK_ANSI_1),
        "2": CGKeyCode(kVK_ANSI_2),
        "3": CGKeyCode(kVK_ANSI_3),
        "4": CGKeyCode(kVK_ANSI_4),
        "5": CGKeyCode(kVK_ANSI_5),
        "6": CGKeyCode(kVK_ANSI_6),
        "7": CGKeyCode(kVK_ANSI_7),
        "8": CGKeyCode(kVK_ANSI_8),
        "9": CGKeyCode(kVK_ANSI_9),
        "-": CGKeyCode(kVK_ANSI_Minus),
        "=": CGKeyCode(kVK_ANSI_Equal),
        "[": CGKeyCode(kVK_ANSI_LeftBracket),
        "]": CGKeyCode(kVK_ANSI_RightBracket),
        "\\": CGKeyCode(kVK_ANSI_Backslash),
        ";": CGKeyCode(kVK_ANSI_Semicolon),
        "'": CGKeyCode(kVK_ANSI_Quote),
        ",": CGKeyCode(kVK_ANSI_Comma),
        ".": CGKeyCode(kVK_ANSI_Period),
        "/": CGKeyCode(kVK_ANSI_Slash),
        "`": CGKeyCode(kVK_ANSI_Grave),
        "return": CGKeyCode(kVK_Return),
        "tab": CGKeyCode(kVK_Tab),
        "space": CGKeyCode(kVK_Space),
        "delete": CGKeyCode(kVK_Delete),
        "escape": CGKeyCode(kVK_Escape),
        "forwardDelete": CGKeyCode(kVK_ForwardDelete),
        "insert": CGKeyCode(kVK_Help),
        "home": CGKeyCode(kVK_Home),
        "end": CGKeyCode(kVK_End),
        "pageUp": CGKeyCode(kVK_PageUp),
        "pageDown": CGKeyCode(kVK_PageDown),
        "left": CGKeyCode(kVK_LeftArrow),
        "right": CGKeyCode(kVK_RightArrow),
        "up": CGKeyCode(kVK_UpArrow),
        "down": CGKeyCode(kVK_DownArrow),
        "f1": CGKeyCode(kVK_F1),
        "f2": CGKeyCode(kVK_F2),
        "f3": CGKeyCode(kVK_F3),
        "f4": CGKeyCode(kVK_F4),
        "f5": CGKeyCode(kVK_F5),
        "f6": CGKeyCode(kVK_F6),
        "f7": CGKeyCode(kVK_F7),
        "f8": CGKeyCode(kVK_F8),
        "f9": CGKeyCode(kVK_F9),
        "f10": CGKeyCode(kVK_F10),
        "f11": CGKeyCode(kVK_F11),
        "f12": CGKeyCode(kVK_F12),
        "f13": CGKeyCode(kVK_F13),
        "f14": CGKeyCode(kVK_F14),
        "f15": CGKeyCode(kVK_F15),
        "f16": CGKeyCode(kVK_F16),
        "f17": CGKeyCode(kVK_F17),
        "f18": CGKeyCode(kVK_F18),
        "f19": CGKeyCode(kVK_F19),
        "f20": CGKeyCode(kVK_F20),
        "keypad0": CGKeyCode(kVK_ANSI_Keypad0),
        "keypad1": CGKeyCode(kVK_ANSI_Keypad1),
        "keypad2": CGKeyCode(kVK_ANSI_Keypad2),
        "keypad3": CGKeyCode(kVK_ANSI_Keypad3),
        "keypad4": CGKeyCode(kVK_ANSI_Keypad4),
        "keypad5": CGKeyCode(kVK_ANSI_Keypad5),
        "keypad6": CGKeyCode(kVK_ANSI_Keypad6),
        "keypad7": CGKeyCode(kVK_ANSI_Keypad7),
        "keypad8": CGKeyCode(kVK_ANSI_Keypad8),
        "keypad9": CGKeyCode(kVK_ANSI_Keypad9),
        "keypadDecimal": CGKeyCode(kVK_ANSI_KeypadDecimal),
        "keypadMultiply": CGKeyCode(kVK_ANSI_KeypadMultiply),
        "keypadPlus": CGKeyCode(kVK_ANSI_KeypadPlus),
        "keypadClear": CGKeyCode(kVK_ANSI_KeypadClear),
        "keypadDivide": CGKeyCode(kVK_ANSI_KeypadDivide),
        "keypadEnter": CGKeyCode(kVK_ANSI_KeypadEnter),
        "keypadMinus": CGKeyCode(kVK_ANSI_KeypadMinus),
        "keypadEquals": CGKeyCode(kVK_ANSI_KeypadEquals),
    ]

    private static let canonicalKeyNameByCode: [CGKeyCode: String] = {
        Dictionary(uniqueKeysWithValues: keyCodeByName.map { ($1, $0) })
    }()

    private static let aliasToCanonicalName: [String: String] = [
        "enter": "return",
        "backspace": "delete",
        "esc": "escape",
        "del": "forwardDelete",
        "help": "insert",
        "ins": "insert",
        "pagedown": "pageDown",
        "pageup": "pageUp",
        "pgdn": "pageDown",
        "pgup": "pageUp",
        "kp0": "keypad0",
        "kp1": "keypad1",
        "kp2": "keypad2",
        "kp3": "keypad3",
        "kp4": "keypad4",
        "kp5": "keypad5",
        "kp6": "keypad6",
        "kp7": "keypad7",
        "kp8": "keypad8",
        "kp9": "keypad9",
        "kpdecimal": "keypadDecimal",
        "kpmultiply": "keypadMultiply",
        "kpplus": "keypadPlus",
        "kpclear": "keypadClear",
        "kpdivide": "keypadDivide",
        "kpenter": "keypadEnter",
        "kpminus": "keypadMinus",
        "kpequals": "keypadEquals",
    ]

    static func keyCode(for key: String) -> CGKeyCode? {
        let canonicalName = canonicalKeyName(for: key)
        return keyCodeByName[canonicalName]
    }

    static func keyName(for keyCode: CGKeyCode) -> String? {
        canonicalKeyNameByCode[keyCode]
    }

    static func canonicalKeyName(for key: String) -> String {
        let normalizedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedKey.isEmpty else {
            return normalizedKey
        }

        let lowercased = normalizedKey.lowercased()
        return aliasToCanonicalName[lowercased] ?? lowercased
    }
}
