import AppKit

/// The atomic unit of flick — every searchable, executable entry implements this.
protocol FlickCommand: AnyObject {
    var id: String { get }
    var title: String { get }
    var subtitle: String? { get }
    var icon: NSImage? { get }
    var keywords: [String] { get }
    var category: String { get }
    var actionLabel: String { get }
    var sectionTitle: String { get }
    func run()
}

extension FlickCommand {
    var subtitle: String? { nil }
    var keywords: [String] { [] }
}
