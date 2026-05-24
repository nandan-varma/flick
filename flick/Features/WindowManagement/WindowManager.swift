import AppKit
import ApplicationServices

@MainActor final class WindowManager {
    var targetWindow: AXUIElement?

    func apply(_ action: WindowAction) {
        guard let window = targetWindow, AXIsProcessTrusted() else { return }
        // Native full-screen windows live in a separate Space; AX can't reposition them.
        guard !boolAttr("AXFullScreen", of: window) else { return }
        // Un-zoom (green-button zoom) so the resize isn't fighting the zoomed state.
        if boolAttr("AXZoomed", of: window) {
            AXUIElementSetAttributeValue(window, "AXZoomed" as CFString, NSNumber(value: false))
        }

        let screen  = screenFor(window) ?? NSScreen.main
        let visible = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let target  = action.frame(in: visible)

        // AX uses top-left origin referenced to the PRIMARY screen (frame.origin == .zero).
        // AppKit uses bottom-left. Convert once, round to integer points to avoid jitter.
        let pH     = primaryHeight()
        let origin = CGPoint(x: target.minX.rounded(), y: (pH - target.maxY).rounded())
        let size   = CGSize(width: target.width.rounded(), height: target.height.rounded())

        // Two full synchronous passes.
        // Pass 1: apply the desired frame.
        // Pass 2: correct any drift from minimum-size clamping or origin shift after resize.
        // AX calls are synchronous (they block until the target app handles the message),
        // so this runs entirely before close() is called and before the app re-enters focus.
        setFrame(window, origin: origin, size: size)
        setFrame(window, origin: origin, size: size)
    }

    // pos → size → pos: move first, resize (may shift origin due to constraints), re-anchor.
    private func setFrame(_ window: AXUIElement, origin: CGPoint, size: CGSize) {
        var o = origin, s = size
        guard let pos = AXValueCreate(.cgPoint, &o),
              let sz  = AXValueCreate(.cgSize,  &s) else { return }
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pos)
        AXUIElementSetAttributeValue(window, kAXSizeAttribute     as CFString, sz)
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pos)
    }

    private func boolAttr(_ attr: String, of window: AXUIElement) -> Bool {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, attr as CFString, &ref) == .success else { return false }
        // CFBoolean toll-free bridges to NSNumber, not directly to Swift Bool.
        return (ref as? NSNumber)?.boolValue ?? false
    }

    private func screenFor(_ window: AXUIElement) -> NSScreen? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &ref) == .success,
              let val = ref, CFGetTypeID(val) == AXValueGetTypeID() else { return nil }
        var axPt = CGPoint.zero
        AXValueGetValue(val as! AXValue, .cgPoint, &axPt)
        // Convert AX (top-left) → AppKit (bottom-left) to find the containing screen.
        let appKitPt = CGPoint(x: axPt.x, y: primaryHeight() - axPt.y)
        return NSScreen.screens.first { $0.frame.contains(appKitPt) }
    }

    private func primaryHeight() -> CGFloat {
        // The primary screen has its AppKit frame at the global origin (0, 0).
        // All AX y-coordinates are measured from this screen's top edge.
        NSScreen.screens.first(where: { $0.frame.origin == .zero })?.frame.height
            ?? NSScreen.screens.first?.frame.height
            ?? 900
    }
}
