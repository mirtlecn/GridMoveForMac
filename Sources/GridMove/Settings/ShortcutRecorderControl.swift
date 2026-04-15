import AppKit
import Carbon.HIToolbox

@MainActor
final class ShortcutRecorderControl: NSButton {
    var shortcut: KeyboardShortcut = KeyboardShortcut(modifiers: [.alt], key: "a") {
        didSet { updateTitle() }
    }

    var onShortcutChange: ((KeyboardShortcut) -> Void)?
    private var isRecording = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        bezelStyle = .rounded
        controlSize = .large
        target = self
        action = #selector(beginRecording)
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

    @objc private func beginRecording() {
        isRecording = true
        title = "Press Shortcut"
        window?.makeFirstResponder(self)
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
        if keyCode == CGKeyCode(kVK_Escape) {
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

    private func updateTitle() {
        title = shortcut.displayString
    }
}
