import AppKit
import ApplicationServices

@MainActor final class WindowManager {
    func apply(_ action: WindowAction) {
        let systemWide = AXUIElementCreateSystemWide()

        var focusedAppRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedAppRef) == .success,
              let focusedAppRef else { return }
        let focusedApp: AXUIElement = unsafeBitCast(focusedAppRef, to: AXUIElement.self)

        var windowRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focusedApp, kAXFocusedWindowAttribute as CFString, &windowRef) == .success,
              let windowRef else { return }
        let axWindow: AXUIElement = unsafeBitCast(windowRef, to: AXUIElement.self)

        let mainScreen = NSScreen.main
        let screenFrame = mainScreen?.visibleFrame ?? mainScreen?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let targetFrame = action.frame(in: screenFrame)

        let mainScreenHeight = mainScreen?.frame.height ?? 900
        let axY = mainScreenHeight - targetFrame.maxY

        var point = CGPoint(x: targetFrame.minX, y: axY)
        guard let posValue = AXValueCreate(.cgPoint, &point) else { return }

        var size = CGSize(width: targetFrame.width, height: targetFrame.height)
        guard let sizeValue = AXValueCreate(.cgSize, &size) else { return }

        AXUIElementSetAttributeValue(axWindow, kAXPositionAttribute as CFString, posValue)
        AXUIElementSetAttributeValue(axWindow, kAXSizeAttribute as CFString, sizeValue)
    }

    func matching(query: String) -> [WindowAction] {
        let lower = query.lowercased()
        return WindowAction.allCases.filter { action in
            action.keywords.contains { $0.contains(lower) }
        }
    }
}
