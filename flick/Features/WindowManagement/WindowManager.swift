import AppKit
import ApplicationServices

@MainActor final class WindowManager {
    // Set by AppDelegate before the launcher appears so window management
    // targets the correct app even after our panel becomes the key window.
    var targetWindow: AXUIElement?

    func apply(_ action: WindowAction) {
        guard let axWindow = targetWindow else { return }

        let mainScreen = NSScreen.main
        let screenFrame = mainScreen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let targetFrame = action.frame(in: screenFrame)

        // AX uses top-left origin; convert from macOS bottom-left.
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
