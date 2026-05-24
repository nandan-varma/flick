import CoreGraphics
import Foundation

enum WindowAction: String, CaseIterable, Identifiable, Sendable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case maximize, center
    case leftThird, centerThird, rightThird

    var id: String { rawValue }

    var name: String {
        switch self {
        case .leftHalf:    "Left Half"
        case .rightHalf:   "Right Half"
        case .topHalf:     "Top Half"
        case .bottomHalf:  "Bottom Half"
        case .maximize:    "Maximize"
        case .center:      "Center"
        case .leftThird:   "Left Third"
        case .centerThird: "Center Third"
        case .rightThird:  "Right Third"
        }
    }

    var keywords: [String] {
        switch self {
        case .leftHalf:    ["window left", "left half", "snap left"]
        case .rightHalf:   ["window right", "right half", "snap right"]
        case .topHalf:     ["window top", "top half", "snap top"]
        case .bottomHalf:  ["window bottom", "bottom half", "snap bottom"]
        case .maximize:    ["window maximize", "maximize", "full screen", "window full"]
        case .center:      ["window center", "center window"]
        case .leftThird:   ["window left third", "left third"]
        case .centerThird: ["window center third", "middle third"]
        case .rightThird:  ["window right third", "right third"]
        }
    }

    // Returns the target frame in AppKit coordinates (bottom-left origin, same system as
    // visibleFrame). Fractions are kept as CGFloat to avoid integer-division truncation;
    // WindowManager rounds to integer points before sending to AX.
    func frame(in screen: CGRect) -> CGRect {
        let w = screen.width, h = screen.height
        let x = screen.minX,  y = screen.minY
        switch self {
        case .leftHalf:
            return CGRect(x: x,         y: y, width: w / 2, height: h)
        case .rightHalf:
            return CGRect(x: x + w / 2, y: y, width: w / 2, height: h)
        case .topHalf:
            return CGRect(x: x, y: y + h / 2, width: w, height: h / 2)
        case .bottomHalf:
            return CGRect(x: x, y: y,          width: w, height: h / 2)
        case .maximize:
            return screen
        case .center:
            return CGRect(x: x + w / 4, y: y + h / 4, width: w / 2, height: h / 2)
        case .leftThird:
            return CGRect(x: x,               y: y, width: w / 3, height: h)
        case .centerThird:
            return CGRect(x: x + w / 3,       y: y, width: w / 3, height: h)
        case .rightThird:
            return CGRect(x: x + 2 * (w / 3), y: y, width: w / 3, height: h)
        }
    }
}
