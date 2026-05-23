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
        case .snippet(let e): e.name
        case .quicklink(let e, let q): q.isEmpty ? e.name : "\(e.name): \(q)"
        case .command(let c): c.name
        case .windowAction(let a): a.name
        }
    }

    var subtitle: String? {
        switch self {
        case .app(let e): return e.bundleID
        case .clip(let e):
            let f = RelativeDateTimeFormatter()
            f.unitsStyle = .abbreviated
            return f.localizedString(for: e.date, relativeTo: Date())
        case .snippet(let e): return e.expansion
        case .quicklink(let e, _): return e.url
        case .command: return nil
        case .windowAction: return nil
        }
    }

    var actionLabel: String {
        switch self {
        case .app: "Launch Application"
        case .clip: "Paste to Active App"
        case .snippet: "Expand Snippet"
        case .quicklink: "Open in Browser"
        case .command: "Run Command"
        case .windowAction: "Apply Layout"
        }
    }

    var sectionTitle: String {
        switch self {
        case .app: "Applications"
        case .clip: "Clipboard History"
        case .snippet: "Snippets"
        case .quicklink: "Quicklinks"
        case .command: "System Commands"
        case .windowAction: "Window Management"
        }
    }

    var category: String { sectionTitle }
}
