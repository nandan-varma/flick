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

        registerEventTap()
    }

    private func registerEventTap() {
        guard eventTap == nil else { return }

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
            // No accessibility permission yet — retry every 3s until granted
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.registerEventTap()
            }
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
