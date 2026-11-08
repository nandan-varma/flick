import Foundation

@Observable @MainActor final class ExtensionStore {
    private static let defaultsKey = "flick.disabledExtensionIDs"

    private(set) var disabledIDs: Set<String>

    init() {
        let saved = UserDefaults.standard.stringArray(forKey: Self.defaultsKey) ?? []
        disabledIDs = Set(saved)
    }

    func isEnabled(_ id: String) -> Bool { !disabledIDs.contains(id) }

    func setEnabled(_ id: String, _ enabled: Bool) {
        if enabled { disabledIDs.remove(id) } else { disabledIDs.insert(id) }
        UserDefaults.standard.set(Array(disabledIDs), forKey: Self.defaultsKey)
    }
}
