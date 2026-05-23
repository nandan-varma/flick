import AppKit
import Foundation

@MainActor final class ClipboardManager: @unchecked Sendable {
    var maxEntries: Int {
        let v = UserDefaults.standard.integer(forKey: "flick.maxClipboardEntries")
        return v > 0 ? v : 500
    }
    var entries: [ClipEntry] = []

    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount

    private let storageURL: URL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("flick/clipboard.json")

    private static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")

    init() {
        load()
    }

    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.checkPasteboard() }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func checkPasteboard() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        guard pb.types?.contains(Self.concealedType) != true else { return }

        guard let text = pb.string(forType: .string) ?? pb.string(forType: .URL),
              !text.isEmpty,
              text != entries.first?.text
        else { return }

        entries.insert(ClipEntry(text: text, date: .now), at: 0)
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        save()
    }

    func paste(entry: ClipEntry) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(entry.text, forType: .string)

        let src = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([ClipEntry].self, from: data)
        else { return }
        entries = decoded
    }

    private func save() {
        let dir = storageURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: storageURL, options: .atomic)
        }
    }
}
