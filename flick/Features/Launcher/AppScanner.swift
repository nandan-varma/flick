import Foundation

final class AppScanner: @unchecked Sendable {
    func scan() async -> [AppEntry] {
        let fm = FileManager.default
        let searchDirs: [URL] = [
            URL(fileURLWithPath: "/Applications"),
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]

        var entries: [AppEntry] = []

        for dir in searchDirs {
            guard let contents = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in contents where url.pathExtension == "app" {
                let baseName = url.deletingPathExtension().lastPathComponent
                let name: String
                let bundleID: String

                if let bundle = Bundle(url: url) {
                    name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                        ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                        ?? baseName
                    bundleID = bundle.bundleIdentifier ?? baseName
                } else {
                    name = baseName
                    bundleID = baseName
                }

                entries.append(AppEntry(name: name, path: url, bundleID: bundleID))
            }
        }

        return entries.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
