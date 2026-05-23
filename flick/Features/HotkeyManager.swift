import AppKit
import CoreGraphics

private enum HotkeyKey {
    static let keyCode = "flick.hotkey.keyCode"
    static let modifiers = "flick.hotkey.modifiers"
}

private let relevantModifiers: CGEventFlags = [.maskAlternate, .maskShift, .maskCommand, .maskControl]

final class HotkeyManager: @unchecked Sendable {
    var onActivate: (() -> Void)?

    nonisolated(unsafe) private var eventTap: CFMachPort?

    var keyCode: Int {
        get { UserDefaults.standard.object(forKey: HotkeyKey.keyCode) as? Int ?? 49 }
        set { UserDefaults.standard.set(newValue, forKey: HotkeyKey.keyCode) }
    }

    var modifiers: CGEventFlags {
        get {
            let raw = UserDefaults.standard.object(forKey: HotkeyKey.modifiers) as? UInt64
                ?? CGEventFlags.maskAlternate.rawValue
            return CGEventFlags(rawValue: raw)
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: HotkeyKey.modifiers)
            maskedModifiers = newValue.intersection(relevantModifiers)
        }
    }

    private(set) var maskedModifiers: CGEventFlags

    init() {
        maskedModifiers = CGEventFlags(
            rawValue: UserDefaults.standard.object(forKey: HotkeyKey.modifiers) as? UInt64
                ?? CGEventFlags.maskAlternate.rawValue
        ).intersection(relevantModifiers)

        let trusted = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        )
        if trusted {
            registerEventTap()
        } else {
            // System has shown the accessibility prompt. Re-check after a short delay
            // so the event tap is registered once the user grants permission.
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                self?.retryIfTrusted()
            }
        }
    }

    private func retryIfTrusted() {
        if AXIsProcessTrusted() {
            registerEventTap()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                self?.retryIfTrusted()
            }
        }
    }

    private func registerEventTap() {
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo -> Unmanaged<CGEvent>? in
                guard type == .keyDown, let userInfo else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                let eventMods = event.flags.intersection(relevantModifiers)
                if keyCode == Int64(manager.keyCode), eventMods == manager.maskedModifiers {
                    DispatchQueue.main.async { manager.onActivate?() }
                    return nil
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: userInfo
        ) else {
            print("[HotkeyManager] Failed to create event tap — ensure Accessibility permission is granted.")
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    deinit {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
    }
}
