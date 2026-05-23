import AppKit
import ApplicationServices
import SwiftUI

@MainActor
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
        setupStatusItem()

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

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.promptAccessibilityIfNeeded()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        showLauncherWindow()
        return true
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let btn = statusItem?.button
        btn?.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "flick")
        btn?.image?.isTemplate = true

        let menu = NSMenu()

        let openItem = NSMenuItem(title: "Open flick", action: #selector(openFlick), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        let prefsItem = NSMenuItem(title: "Preferences…", action: #selector(openSettings), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        let a11yItem = NSMenuItem(title: "Enable Hotkey Access…", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        a11yItem.target = self
        menu.addItem(a11yItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit flick", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(openAccessibilitySettings) {
            return !AXIsProcessTrusted()
        }
        return true
    }

    // MARK: - Actions

    @objc private func openFlick() {
        // Brief delay so the status menu finishes dismissing before the panel appears.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.showLauncherWindow()
        }
    }

    @objc func toggleLauncherWindow() {
        if let window = windowController?.window, window.isVisible {
            windowController?.close()
        } else {
            showLauncherWindow()
        }
    }

    private func showLauncherWindow() {
        // Capture the focused window of the frontmost app BEFORE showing the launcher.
        // Once our nonactivating panel is key, AX-focused-application changes to flick,
        // so window management commands must use this pre-captured reference.
        captureTargetWindow()
        windowController?.showWindow(nil)
    }

    /// Stores the focused window of the currently active app into WindowManager
    /// so that window snap/resize commands work after the launcher appears.
    private func captureTargetWindow() {
        guard let frontmost = NSWorkspace.shared.frontmostApplication else { return }
        let axApp = AXUIElementCreateApplication(pid_t(frontmost.processIdentifier))
        var windowRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &windowRef) == .success,
              let windowRef else {
            windowManager.targetWindow = nil
            return
        }
        windowManager.targetWindow = unsafeBitCast(windowRef, to: AXUIElement.self)
    }

    @objc private func openSettings() {
        if settingsWindowController == nil {
            let view = SettingsView(snippetManager: snippetManager, quicklinkManager: quicklinkManager)
            let hosting = NSHostingController(rootView: view)
            let win = NSWindow(contentViewController: hosting)
            win.title = "flick Preferences"
            win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            win.setContentSize(NSSize(width: 560, height: 420))
            win.center()
            settingsWindowController = NSWindowController(window: win)
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
    }

    @objc private func openAccessibilitySettings() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        )
    }

    // MARK: - Accessibility prompt

    private func promptAccessibilityIfNeeded() {
        guard !AXIsProcessTrusted() else { return }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Allow flick to use Accessibility features"
        alert.informativeText = """
            flick needs Accessibility access to register the ⌥Space global hotkey \
            and manage windows.\n\nOpen System Settings → Privacy & Security → \
            Accessibility, then add flick to the list. The hotkey activates \
            automatically once permission is granted — no restart needed.
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            openAccessibilitySettings()
        }
    }
}
