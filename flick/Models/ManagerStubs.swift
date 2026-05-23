import AppKit

// STUB: real definitions provided by feature units
// These allow Unit 1 to compile before feature units are merged.

class AppScanner {}
class ClipboardManager {}
class SnippetManager {}
class QuicklinkManager {}
class FrecencyStore {}
class WindowManager {}

class HotkeyManager {
    var onActivate: (() -> Void)?
}

@MainActor
class WindowController: NSWindowController {
    convenience init(viewModel: AppViewModel) {
        self.init(window: nil)
    }
}
