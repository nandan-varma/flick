import Foundation

@Observable @MainActor final class CommandStore {
    private static let disabledKey = "flick.disabledCommandIDs"
    private static let hotkeysKey  = "flick.commandHotkeys"

    struct Hotkey: Codable, Equatable {
        var keyCode: Int
        var modifiers: Int
    }

    private(set) var disabledIDs: Set<String>
    private(set) var hotkeys: [String: Hotkey]

    init() {
        let saved = UserDefaults.standard.stringArray(forKey: Self.disabledKey) ?? []
        disabledIDs = Set(saved)
        if let data = UserDefaults.standard.data(forKey: Self.hotkeysKey),
           let decoded = try? JSONDecoder().decode([String: Hotkey].self, from: data) {
            hotkeys = decoded
        } else {
            hotkeys = [:]
        }
    }

    func isEnabled(_ id: String) -> Bool { !disabledIDs.contains(id) }

    func setEnabled(_ id: String, _ enabled: Bool) {
        if enabled { disabledIDs.remove(id) } else { disabledIDs.insert(id) }
        UserDefaults.standard.set(Array(disabledIDs), forKey: Self.disabledKey)
    }

    func hotkey(for id: String) -> Hotkey? { hotkeys[id] }

    func setHotkey(_ hotkey: Hotkey?, for id: String) {
        if let h = hotkey { hotkeys[id] = h } else { hotkeys.removeValue(forKey: id) }
        UserDefaults.standard.set(try? JSONEncoder().encode(hotkeys), forKey: Self.hotkeysKey)
    }
}
