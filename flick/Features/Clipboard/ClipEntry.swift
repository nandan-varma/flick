import Foundation

struct ClipEntry: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var text: String
    var date: Date
    var sourceApp: String?

    init(text: String, date: Date = .now, sourceApp: String? = nil) {
        id = UUID()
        self.text = text
        self.date = date
        self.sourceApp = sourceApp
    }
}
