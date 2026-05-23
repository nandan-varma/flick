import Foundation

final class JSONStore<T: Codable & Sendable>: @unchecked Sendable {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(filename: String) {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("flick", isDirectory: true)
        fileURL = dir.appendingPathComponent(filename)

        try? FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true,
            attributes: nil
        )

        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder.dateDecodingStrategy = .iso8601
    }

    private func readData() -> Data? {
        try? Data(contentsOf: fileURL)
    }

    private func write(_ data: Data) {
        try? data.write(to: fileURL, options: .atomic)
    }

    func load() -> [T] {
        guard let data = readData() else { return [] }
        return (try? decoder.decode([T].self, from: data)) ?? []
    }

    func save(_ items: [T]) {
        guard let data = try? encoder.encode(items) else { return }
        write(data)
    }

    func loadOne() -> T? {
        guard let data = readData() else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    func saveOne(_ item: T) {
        guard let data = try? encoder.encode(item) else { return }
        write(data)
    }

    var exists: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    func delete() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
