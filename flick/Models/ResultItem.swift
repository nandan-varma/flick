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
        case .app(let e): return e.name
        case .clip(let e): return e.text
        case .snippet(let e): return e.name
        case .quicklink(let e, let q): return q.isEmpty ? e.name : "\(e.name): \(q)"
        case .command(let c): return c.name
        case .windowAction(let a): return a.name
        }
    }

    // Shown inline after the name in the same row
    var subtitle: String? {
        switch self {
        case .app: return nil
        case .clip(let e):
            let f = RelativeDateTimeFormatter()
            f.unitsStyle = .abbreviated
            return f.localizedString(for: e.date, relativeTo: Date())
        case .snippet(let e): return e.keyword
        case .quicklink(let e, _): return e.keyword
        case .command: return nil
        case .windowAction: return nil
        }
    }

    var actionLabel: String {
        switch self {
        case .app: return "Launch Application"
        case .clip: return "Paste to Active App"
        case .snippet: return "Expand Snippet"
        case .quicklink: return "Open in Browser"
        case .command: return "Run Command"
        case .windowAction: return "Apply Layout"
        }
    }

    // Section title — used only on home screen
    var sectionTitle: String {
        switch self {
        case .app: return "Suggested"
        case .clip: return "Recent"
        case .snippet: return "Snippets"
        case .quicklink: return "Quicklinks"
        case .command: return "System Commands"
        case .windowAction: return "Window Management"
        }
    }

    // Short label shown on right side of each row
    var category: String {
        switch self {
        case .app: return "Application"
        case .clip: return "Clipboard"
        case .snippet: return "Snippet"
        case .quicklink: return "Quicklink"
        case .command: return "Command"
        case .windowAction: return "Window"
        }
    }
}
