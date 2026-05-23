import AppKit

/// The atomic unit of flick — every searchable, executable entry implements this.
protocol FlickCommand: AnyObject {
    var id: String { get }
    var title: String { get }
    var subtitle: String? { get }   // shown inline after title in the row
    var icon: NSImage? { get }
    var keywords: [String] { get }
    var category: String { get }      // short type badge (right side of row)
    var actionLabel: String { get }   // bottom action bar
    var sectionTitle: String { get }  // home-screen section header
    func run()
}
