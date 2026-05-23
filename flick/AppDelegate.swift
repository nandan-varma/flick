import AppKit
import SwiftUI

@main @MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let viewModel = AppViewModel()
    private var windowController: WindowController?
    private var hotkeyManager: HotkeyManager?
    private let clipboardManager = ClipboardManager()
    private let snippetManager = SnippetManager()
    private let quicklinkManager = QuicklinkManager()
    private let frecencyStore = FrecencyStore()
    private let windowManager = WindowManager()
    private let appScanner = AppScanner()
    private var statusItem: NSStatusItem?
    private var settingsWindowController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        viewModel.clipboardManager = clipboardManager
        viewModel.snippetManager = snippetManager
        viewModel.quicklinkManager = quicklinkManager
        viewModel.frecencyStore = frecencyStore
        viewModel.windowManager = windowManager

        clipboardManager.startMonitoring()

        Task {
            let apps = await appScanner.scan()
            viewModel.cachedApps = apps
        }

        windowController = WindowController(viewModel: viewModel)

        let hotkey = HotkeyManager()
        hotkeyManager = hotkey
        hotkey.onActivate = { [weak self] in self?.toggleLauncherWindow() }

        setupStatusItem()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        toggleLauncherWindow()
        return true
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let btn = statusItem?.button
        btn?.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "flick")
        btn?.image?.isTemplate = true

        let menu = NSMenu()
        menu.addItem(withTitle: "Open flick", action: #selector(toggleLauncherWindow), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Preferences…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit flick", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem?.menu = menu
    }

    @objc func toggleLauncherWindow() {
        if let window = windowController?.window, window.isVisible {
            windowController?.close()
        } else {
            windowController?.showWindow(nil)
        }
    }

    @objc func openSettings() {
        if settingsWindowController == nil {
            let view = SettingsView(snippetManager: snippetManager, quicklinkManager: quicklinkManager)
            let wc = NSWindowController(window: NSWindow(contentViewController: NSHostingController(rootView: view)))
            wc.window?.title = "flick Preferences"
            wc.window?.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            wc.window?.setContentSize(NSSize(width: 560, height: 420))
            wc.window?.center()
            settingsWindowController = wc
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
