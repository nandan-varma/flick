import AppKit
import Foundation

@Observable @MainActor final class SnippetManager {
    var snippets: [Snippet] = []

    private let storageURL: URL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("flick/snippets.json")

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    init() {
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([Snippet].self, from: data)
        else { return }
        snippets = decoded
    }

    func save() {
        let dir = storageURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(snippets) {
            try? data.write(to: storageURL, options: .atomic)
        }
    }

    func add(_ snippet: Snippet) {
        snippets.append(snippet)
        save()
    }

    func remove(at offsets: IndexSet) {
        for index in offsets.reversed() { snippets.remove(at: index) }
        save()
    }

    func update(_ snippet: Snippet) {
        guard let index = snippets.firstIndex(where: { $0.id == snippet.id }) else { return }
        snippets[index] = snippet
        save()
    }

    func expand(_ snippet: Snippet) -> String {
        let now = Date()
        let clipboard = NSPasteboard.general.string(forType: .string) ?? ""
        return snippet.expansion
            .replacingOccurrences(of: "{date}", with: Self.dateFormatter.string(from: now))
            .replacingOccurrences(of: "{time}", with: Self.timeFormatter.string(from: now))
            .replacingOccurrences(of: "{clipboard}", with: clipboard)
    }

    func matching(query: String) -> [Snippet] {
        guard query.hasPrefix("snip:") else { return [] }
        let term = String(query.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { return snippets }
        return snippets
            .filter {
                $0.keyword.localizedCaseInsensitiveContains(term) ||
                $0.name.localizedCaseInsensitiveContains(term)
            }
            .sorted { a, b in
                let aExact = a.keyword.localizedCaseInsensitiveCompare(term) == .orderedSame
                let bExact = b.keyword.localizedCaseInsensitiveCompare(term) == .orderedSame
                if aExact != bExact { return aExact }
                return a.name < b.name
            }
    }

    func paste(snippet: Snippet) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(expand(snippet), forType: .string)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let src = CGEventSource(stateID: .hidSystemState)
            let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: true)
            let keyUp   = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: false)
            keyDown?.flags = .maskCommand
            keyUp?.flags   = .maskCommand
            keyDown?.post(tap: .cgAnnotatedSessionEventTap)
            keyUp?.post(tap: .cgAnnotatedSessionEventTap)
        }
    }
}
