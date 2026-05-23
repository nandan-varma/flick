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

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
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

        let openItem = NSMenuItem(title: "Open flick", action: #selector(toggleLauncherWindow), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        let prefsItem = NSMenuItem(title: "Preferences…", action: #selector(openSettings), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit flick", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        menu.addItem(quitItem)

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
            let hosting = NSHostingController(rootView: view)
            let win = NSWindow(contentViewController: hosting)
            win.title = "flick Preferences"
            win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            win.setContentSize(NSSize(width: 560, height: 420))
            win.center()
            let wc = NSWindowController(window: win)
            settingsWindowController = wc
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
    }
}
