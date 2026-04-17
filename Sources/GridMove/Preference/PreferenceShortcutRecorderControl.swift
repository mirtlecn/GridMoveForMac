import AppKit
import Carbon.HIToolbox

@MainActor
final class PreferenceShortcutRecorderControl: NSButton {
    var shortcut: KeyboardShortcut? {
        didSet { updateTitle() }
    }

    var onShortcutChange: ((KeyboardShortcut?) -> Void)?

    private var isRecording = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isBordered = false
        setButtonType(.momentaryChange)
        focusRingType = .none
        alignment = .center
        font = .systemFont(ofSize: 14, weight: .medium)
        updateTitle()
    }

    convenience init() {
        self.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount >= 2 {
            beginRecording()
        } else {
            window?.makeFirstResponder(nil)
        }
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        updateTitle()
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        let keyCode = CGKeyCode(event.keyCode)
        if keyCode == CGKeyCode(kVK_Escape) || keyCode == CGKeyCode(kVK_Delete) || keyCode == CGKeyCode(kVK_ForwardDelete) {
            shortcut = nil
            onShortcutChange?(nil)
            isRecording = false
            updateTitle()
            return
        }

        guard let key = ShortcutKeyMap.keyName(for: keyCode) else {
            NSSound.beep()
            return
        }

        let modifiers = [
            event.modifierFlags.contains(.control) ? ModifierKey.ctrl : nil,
            event.modifierFlags.contains(.command) ? ModifierKey.cmd : nil,
            event.modifierFlags.contains(.shift) ? ModifierKey.shift : nil,
            event.modifierFlags.contains(.option) ? ModifierKey.alt : nil,
        ].compactMap { $0 }

        let shortcut = KeyboardShortcut(modifiers: modifiers, key: key)
        self.shortcut = shortcut
        onShortcutChange?(shortcut)
        isRecording = false
        updateTitle()
    }

    private func beginRecording() {
        isRecording = true
        updateTitle()
        window?.makeFirstResponder(self)
    }

    private func updateTitle() {
        let text = isRecording ? UICopy.typeShortcut : (shortcut?.symbolDisplayString ?? UICopy.recordShortcut)
        let color: NSColor = shortcut == nil && !isRecording ? .secondaryLabelColor : .labelColor
        attributedTitle = NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: 14, weight: shortcut == nil && !isRecording ? .regular : .medium),
                .foregroundColor: color,
            ]
        )
    }
}
