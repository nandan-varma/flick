import AppKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    var windowController: WindowController?
    var hotkeyManager: HotkeyManager?
    @MainActor let viewModel = AppViewModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let controller = WindowController(viewModel: viewModel)
        windowController = controller

        let hotkey = HotkeyManager()
        hotkeyManager = hotkey
        hotkey.onActivate = { [weak self] in
            self?.toggleLauncherWindow()
        }
    }

    func toggleLauncherWindow() {
        if let window = windowController?.window, window.isVisible {
            window.orderOut(nil)
        } else {
            windowController?.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
