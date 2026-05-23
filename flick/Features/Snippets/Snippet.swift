import Foundation

struct Snippet: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var keyword: String
    var expansion: String
    var name: String

    init(keyword: String, expansion: String, name: String) {
        id = UUID()
        self.keyword = keyword
        self.expansion = expansion
        self.name = name
    }
}
