import AppKit
import CoreGraphics

private enum HotkeyKey {
    static let keyCode = "flick.hotkey.keyCode"
    static let modifiers = "flick.hotkey.modifiers"
}

private let relevantModifiers: CGEventFlags = [.maskAlternate, .maskShift, .maskCommand, .maskControl]

private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard type == .keyDown, let userInfo else { return Unmanaged.passUnretained(event) }
    let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()

    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let eventMods = event.flags.intersection(relevantModifiers)

    if keyCode == Int64(manager.keyCode), eventMods == manager.maskedModifiers {
        DispatchQueue.main.async { manager.onActivate?() }
        return nil
    }

    return Unmanaged.passUnretained(event)
}

final class HotkeyManager: @unchecked Sendable {
    var onActivate: (() -> Void)?

    private var eventTap: CFMachPort?

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

        if !AXIsProcessTrusted() {
            print("[HotkeyManager] Accessibility permission not granted — prompting user.")
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
        registerEventTap()
    }

    private func registerEventTap() {
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
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
