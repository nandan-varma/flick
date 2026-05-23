import AppKit

// STUB: real definition in flick/Features/Launcher/AppEntry.swift
struct AppEntry: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var path: URL
    var bundleID: String

    init(name: String, path: URL, bundleID: String) {
        id = UUID()
        self.name = name
        self.path = path
        self.bundleID = bundleID
    }
}

// STUB: real definition in flick/Features/Clipboard/ClipEntry.swift
struct ClipEntry: Identifiable, Codable, Sendable {
    let id: UUID
    var text: String
    var date: Date
    var sourceApp: String?

    init(text: String, date: Date = .now, sourceApp: String? = nil) {
        id = UUID()
        self.text = text
        self.date = date
        self.sourceApp = sourceApp
    }
}

// STUB: real definition in flick/Features/Snippets/Snippet.swift
struct Snippet: Identifiable, Codable, Sendable {
    let id: UUID
    var keyword: String
    var expansion: String
    var name: String

    init(keyword: String, expansion: String, name: String) {
        id = UUID()
        self.keyword = keyword
        self.expansion = expansion
        self.name = name
    }
}

// STUB: real definition in flick/Features/Quicklinks/Quicklink.swift
struct Quicklink: Identifiable, Codable, Sendable {
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
}

// STUB: real definition in flick/Features/SystemCommands/SystemCommand.swift
protocol SystemCommandProtocol: AnyObject {
    var name: String { get }
    var keywords: [String] { get }
    func run()
}

enum ResultItem: Identifiable {
    case app(AppEntry)
    case clip(ClipEntry)
    case snippet(Snippet)
    case quicklink(Quicklink)
    case command(any SystemCommandProtocol)

    var id: String {
        switch self {
        case .app(let e): "app-\(e.id)"
        case .clip(let e): "clip-\(e.id)"
        case .snippet(let e): "snippet-\(e.id)"
        case .quicklink(let e): "quicklink-\(e.id)"
        case .command(let c): "command-\(c.name)"
        }
    }

    var displayName: String {
        switch self {
        case .app(let e): e.name
        case .clip(let e): e.text
        case .snippet(let e): e.name
        case .quicklink(let e): e.name
        case .command(let c): c.name
        }
    }

    var category: String {
        switch self {
        case .app: "Application"
        case .clip: "Clipboard"
        case .snippet: "Snippet"
        case .quicklink: "Quicklink"
        case .command: "Command"
        }
    }

    func run() {
        switch self {
        case .app(let e):
            NSWorkspace.shared.openApplication(at: e.path, configuration: .init())
        case .clip(let e):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(e.text, forType: .string)
        case .snippet(let e):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(e.expansion, forType: .string)
        case .quicklink(let e):
            if let url = URL(string: e.url) { NSWorkspace.shared.open(url) }
        case .command(let c):
            c.run()
        }
    }
}
