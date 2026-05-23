import AppKit

enum ResultItem: Identifiable {
    case app(AppEntry)
    case clip(ClipEntry)
    case snippet(Snippet)
    case quicklink(Quicklink, query: String)
    case command(any SystemCommandProtocol)
    case windowAction(WindowAction)

    var id: String {
        switch self {
        case .app(let e): "app-\(e.id)"
        case .clip(let e): "clip-\(e.id)"
        case .snippet(let e): "snippet-\(e.id)"
        case .quicklink(let e, _): "quicklink-\(e.id)"
        case .command(let c): "command-\(c.name)"
        case .windowAction(let a): "windowAction-\(a.rawValue)"
        }
    }

    var displayName: String {
        switch self {
        case .app(let e): e.name
        case .clip(let e): e.text
        case .snippet(let e): "\(e.keyword)  →  \(e.name)"
        case .quicklink(let e, let q): q.isEmpty ? e.name : "\(e.name): \(q)"
        case .command(let c): c.name
        case .windowAction(let a): a.name
        }
    }

    var category: String {
        switch self {
        case .app: "Application"
        case .clip: "Clipboard"
        case .snippet: "Snippet"
        case .quicklink: "Quicklink"
        case .command: "Command"
        case .windowAction: "Window"
        }
    }
}
