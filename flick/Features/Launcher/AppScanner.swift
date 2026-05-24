import Foundation

final class AppScanner: @unchecked Sendable {
    func scan() async -> [AppEntry] {
        let fm = FileManager.default

        let rootDirs: [URL] = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "/System/Applications/Utilities"),
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
        ]

        var seen = Set<URL>()
        var entries: [AppEntry] = []

        for root in rootDirs {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: root.path, isDirectory: &isDir), isDir.boolValue else { continue }
            collect(in: root, fm: fm, depth: 1, seen: &seen, entries: &entries)
        }

        return entries.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // Recursively finds .app bundles up to `depth` levels deep.
    private func collect(
        in dir: URL,
        fm: FileManager,
        depth: Int,
        seen: inout Set<URL>,
        entries: inout [AppEntry]
    ) {
        guard depth >= 0,
              let contents = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
              )
        else { return }

        for url in contents {
            let resolved = (try? url.resolvingSymlinksInPath()) ?? url
            if url.pathExtension == "app" {
                guard seen.insert(resolved).inserted else { continue }
                entries.append(makeEntry(url: url))
            } else if depth > 0 {
                // Descend into plain folders (e.g. /Applications/Utilities/)
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                    collect(in: url, fm: fm, depth: depth - 1, seen: &seen, entries: &entries)
                }
            }
        }
    }

    private func makeEntry(url: URL) -> AppEntry {
        let baseName = url.deletingPathExtension().lastPathComponent
        let plist = url.appendingPathComponent("Contents/Info.plist")
        if FileManager.default.fileExists(atPath: plist.path),
           let bundle = Bundle(url: url) {
            let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? baseName
            let bundleID = bundle.bundleIdentifier ?? baseName
            return AppEntry(name: name, path: url, bundleID: bundleID)
        }
        return AppEntry(name: baseName, path: url, bundleID: baseName)
    }
}
