import Foundation

struct Quicklink: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var url: String
    var keyword: String

    init(name: String, url: String, keyword: String) {
        id = UUID()
        self.name = name
        self.url = url
        self.keyword = keyword
    }

    func resolve(query: String) -> URL? {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let filled = url.replacingOccurrences(of: "{query}", with: encoded)
        return URL(string: filled)
    }
}
