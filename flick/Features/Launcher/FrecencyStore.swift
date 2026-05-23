import Foundation

private struct FrecencyEntry: Codable {
    var count: Int
    var lastUsed: Date
}

final class FrecencyStore: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.nandanvarma.flick.frecency")
    private var entries: [String: FrecencyEntry] = [:]
    private static let defaultsKey = "flick.frecency"

    init() {
        load()
    }

    func record(bundleID: String) {
        queue.sync {
            var entry = entries[bundleID] ?? FrecencyEntry(count: 0, lastUsed: Date())
            entry.count += 1
            entry.lastUsed = Date()
            entries[bundleID] = entry
            save()
        }
    }

    func score(for bundleID: String) -> Double {
        queue.sync {
            guard let entry = entries[bundleID] else { return 0 }
            let daysSince = Date().timeIntervalSince(entry.lastUsed) / 86400
            return Double(entry.count) / log2(daysSince + 2)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
              let decoded = try? JSONDecoder().decode([String: FrecencyEntry].self, from: data)
        else { return }
        entries = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }
}
