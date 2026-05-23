import CoreGraphics
import Foundation

enum WindowAction: String, CaseIterable, Identifiable, Sendable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case maximize, center
    case leftThird, centerThird, rightThird

    var id: String { rawValue }

    var name: String {
        switch self {
        case .leftHalf: "Left Half"
        case .rightHalf: "Right Half"
        case .topHalf: "Top Half"
        case .bottomHalf: "Bottom Half"
        case .maximize: "Maximize"
        case .center: "Center"
        case .leftThird: "Left Third"
        case .centerThird: "Center Third"
        case .rightThird: "Right Third"
        }
    }

    var keywords: [String] {
        switch self {
        case .leftHalf: ["window left", "left half", "snap left"]
        case .rightHalf: ["window right", "right half", "snap right"]
        case .topHalf: ["window top", "top half", "snap top"]
        case .bottomHalf: ["window bottom", "bottom half", "snap bottom"]
        case .maximize: ["window maximize", "maximize", "full screen", "window full"]
        case .center: ["window center", "center window"]
        case .leftThird: ["window left third", "left third"]
        case .centerThird: ["window center third", "middle third"]
        case .rightThird: ["window right third", "right third"]
        }
    }

    func frame(in screen: CGRect) -> CGRect {
        switch self {
        case .leftHalf:
            CGRect(x: screen.minX, y: screen.minY, width: screen.width * 0.5, height: screen.height)
        case .rightHalf:
            CGRect(x: screen.minX + screen.width * 0.5, y: screen.minY, width: screen.width * 0.5, height: screen.height)
        case .topHalf:
            CGRect(x: screen.minX, y: screen.minY + screen.height * 0.5, width: screen.width, height: screen.height * 0.5)
        case .bottomHalf:
            CGRect(x: screen.minX, y: screen.minY, width: screen.width, height: screen.height * 0.5)
        case .maximize:
            screen
        case .center:
            CGRect(x: screen.minX + screen.width * 0.25, y: screen.minY + screen.height * 0.25, width: screen.width * 0.5, height: screen.height * 0.5)
        case .leftThird:
            CGRect(x: screen.minX, y: screen.minY, width: screen.width / 3, height: screen.height)
        case .centerThird:
            CGRect(x: screen.minX + screen.width / 3, y: screen.minY, width: screen.width / 3, height: screen.height)
        case .rightThird:
            CGRect(x: screen.minX + screen.width * 2 / 3, y: screen.minY, width: screen.width / 3, height: screen.height)
        }
    }
}
