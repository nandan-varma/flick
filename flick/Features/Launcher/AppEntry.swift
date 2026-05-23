import Foundation

struct AppEntry: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var path: URL
    var bundleID: String

    init(name: String, path: URL, bundleID: String) {
        self.id = UUID()
        self.name = name
        self.path = path
        self.bundleID = bundleID
    }
}
