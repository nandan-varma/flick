import AppKit
import Foundation

@MainActor final class QuicklinkManager {
    static let defaults: [Quicklink] = [
        Quicklink(name: "Google", url: "https://google.com/search?q={query}", keyword: "g"),
        Quicklink(name: "GitHub", url: "https://github.com/search?q={query}", keyword: "gh"),
        Quicklink(name: "YouTube", url: "https://youtube.com/results?search_query={query}", keyword: "yt"),
        Quicklink(name: "Maps", url: "https://maps.apple.com/?q={query}", keyword: "maps"),
        Quicklink(name: "Dictionary", url: "dict://{query}", keyword: "dict"),
    ]

    private let storageURL: URL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("flick/quicklinks.json")

    var quicklinks: [Quicklink] = []

    init() {
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([Quicklink].self, from: data)
        else {
            quicklinks = Self.defaults
            save()
            return
        }
        quicklinks = decoded
    }

    func save() {
        let dir = storageURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(quicklinks) {
            try? data.write(to: storageURL, options: .atomic)
        }
    }

    func add(_ quicklink: Quicklink) {
        quicklinks.append(quicklink)
        save()
    }

    func remove(at offsets: IndexSet) {
        quicklinks.remove(atOffsets: offsets)
        save()
    }

    func update(_ quicklink: Quicklink) {
        guard let index = quicklinks.firstIndex(where: { $0.id == quicklink.id }) else { return }
        quicklinks[index] = quicklink
        save()
    }

    func match(query: String) -> (Quicklink, String)? {
        let parts = query.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
        guard let keyword = parts.first.map(String.init) else { return nil }
        let remainder = parts.count > 1 ? String(parts[1]) : ""
        guard let quicklink = quicklinks.first(where: { $0.keyword.lowercased() == keyword.lowercased() }) else { return nil }
        return (quicklink, remainder)
    }

    func open(quicklink: Quicklink, query: String) {
        guard let url = quicklink.resolve(query: query) else { return }
        NSWorkspace.shared.open(url)
    }
}
