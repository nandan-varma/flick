import AppKit
import Observation

private final class LauncherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class WindowController: NSWindowController, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate {

    private enum Layout {
        static let rowHeight: CGFloat = 48
        static let maxVisibleRows = 8
        static let searchAreaHeight: CGFloat = 60
        static let calculatorHeight: CGFloat = 28
        static let layoutPadding: CGFloat = 16
    }

    // Allocated once — not recreated on every table reload
    private static let clipIcon    = NSImage(systemSymbolName: "doc.on.clipboard",      accessibilityDescription: nil)
    private static let snippetIcon = NSImage(systemSymbolName: "text.quote",            accessibilityDescription: nil)
    private static let linkIcon    = NSImage(systemSymbolName: "link",                  accessibilityDescription: nil)
    private static let commandIcon = NSImage(systemSymbolName: "terminal",              accessibilityDescription: nil)
    private static let windowIcon  = NSImage(systemSymbolName: "rectangle.split.2x1",  accessibilityDescription: nil)

    private static let rowIdentifier = NSUserInterfaceItemIdentifier("ResultRowView")

    weak var viewModel: AppViewModel?
    private let searchField = NSTextField()
    private let calculatorLabel = NSTextField(labelWithString: "")
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private var calculatorHeightConstraint: NSLayoutConstraint?
    private var keyDownMonitor: Any?
    private var clickOutsideMonitor: Any?

    init(viewModel: AppViewModel) {
        self.viewModel = viewModel

        let panel = LauncherPanel(
            contentRect: CGRect(x: 0, y: 0, width: 640, height: 400),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.hasShadow = true
        panel.backgroundColor = .clear

        super.init(window: panel)
        panel.delegate = self

        setupVisualEffect(panel: panel)
        setupSearchField()
        setupCalculatorLabel()
        setupTableView()
        observeViewModel()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setupVisualEffect(panel: NSPanel) {
        let vev = NSVisualEffectView()
        vev.material = .hudWindow
        vev.blendingMode = .behindWindow
        vev.state = .active
        vev.wantsLayer = true
        vev.layer?.cornerRadius = 12
        vev.layer?.masksToBounds = true
        panel.contentView = vev
    }

    private func setupSearchField() {
        guard let contentView = window?.contentView else { return }

        searchField.placeholderString = "Search apps, clipboard, snippets…"
        searchField.isBordered = false
        searchField.drawsBackground = false
        searchField.font = .systemFont(ofSize: 16, weight: .light)
        searchField.focusRingType = .none
        searchField.delegate = self
        searchField.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(searchField)
        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            searchField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            searchField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            searchField.heightAnchor.constraint(equalToConstant: 28),
        ])
    }

    private func setupCalculatorLabel() {
        guard let contentView = window?.contentView else { return }

        calculatorLabel.font = .monospacedSystemFont(ofSize: 20, weight: .medium)
        calculatorLabel.textColor = .labelColor
        calculatorLabel.alignment = .center
        calculatorLabel.isHidden = true
        calculatorLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(calculatorLabel)
        let heightConstraint = calculatorLabel.heightAnchor.constraint(equalToConstant: 0)
        calculatorHeightConstraint = heightConstraint
        NSLayoutConstraint.activate([
            calculatorLabel.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 4),
            calculatorLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            calculatorLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            heightConstraint,
        ])
    }

    private func setupTableView() {
        guard let contentView = window?.contentView else { return }

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("results"))
        column.isEditable = false
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = Layout.rowHeight
        tableView.selectionHighlightStyle = .regular
        tableView.backgroundColor = .clear
        tableView.intercellSpacing = .zero
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.doubleAction = #selector(tableRowDoubleClicked)

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.automaticallyAdjustsContentInsets = false

        contentView.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: calculatorLabel.bottomAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
        ])
    }

    // MARK: - Event monitors

    private func installMonitors() {
        guard keyDownMonitor == nil else { return }

        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event: event) ?? event
        }

        // Global monitor dismisses the panel when the user clicks in another app.
        // Local clicks on the panel itself are handled naturally by AppKit.
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }
    }

    private func removeMonitors() {
        if let m = keyDownMonitor   { NSEvent.removeMonitor(m); keyDownMonitor = nil }
        if let m = clickOutsideMonitor { NSEvent.removeMonitor(m); clickOutsideMonitor = nil }
    }

    // MARK: - Key handling

    private func handleKeyDown(event: NSEvent) -> NSEvent? {
        guard let vm = viewModel else { return event }
        switch event.keyCode {
        case 125: // ↓
            vm.moveDown()
            tableView.selectRowIndexes(IndexSet(integer: vm.selectedIndex), byExtendingSelection: false)
            tableView.scrollRowToVisible(vm.selectedIndex)
            return nil
        case 126: // ↑
            vm.moveUp()
            tableView.selectRowIndexes(IndexSet(integer: vm.selectedIndex), byExtendingSelection: false)
            tableView.scrollRowToVisible(vm.selectedIndex)
            return nil
        case 36, 76: // Return / numpad Enter
            // Close first so the previous app's window regains key status before any paste simulation.
            close()
            vm.runSelected()
            return nil
        case 53: // Escape
            close()
            return nil
        default:
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "k" {
                showActionsPanel()
                return nil
            }
            return event
        }
    }

    @objc private func tableRowDoubleClicked() {
        guard let vm = viewModel, tableView.clickedRow >= 0 else { return }
        vm.selectedIndex = tableView.clickedRow
        close()
        vm.runSelected()
    }

    private func showActionsPanel() {
        guard let vm = viewModel, vm.results.indices.contains(vm.selectedIndex) else { return }
        if case .app(let entry) = vm.results[vm.selectedIndex] {
            NSWorkspace.shared.activateFileViewerSelecting([entry.path])
            close()
        }
    }

    // MARK: - Observation

    func observeViewModel() {
        withObservationTracking {
            _ = viewModel?.results
            _ = viewModel?.calculatorResult
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                self?.reloadTable()
                self?.observeViewModel()
            }
        }
    }

    // MARK: - Table reload & window sizing

    private func reloadTable() {
        // Skip all work while the panel is hidden — avoids useless layout passes.
        guard window?.isVisible == true, let vm = viewModel else { return }

        let hasCalcResult = vm.calculatorResult != nil
        calculatorLabel.isHidden = !hasCalcResult
        calculatorHeightConstraint?.constant = hasCalcResult ? Layout.calculatorHeight : 0
        if let value = vm.calculatorResult {
            calculatorLabel.stringValue = "= \(value)"
        }

        tableView.reloadData()

        let visibleRows = hasCalcResult ? 0 : min(vm.results.count, Layout.maxVisibleRows)
        let tableHeight = CGFloat(visibleRows) * Layout.rowHeight
        let calcAreaHeight = hasCalcResult ? Layout.calculatorHeight + 8 : 0
        let totalHeight = Layout.searchAreaHeight + calcAreaHeight + tableHeight + Layout.layoutPadding

        if let panel = window {
            var frame = panel.frame
            frame.origin.y += frame.height - totalHeight
            frame.size.height = totalHeight
            panel.setFrame(frame, display: true, animate: false)
        }

        if vm.results.indices.contains(vm.selectedIndex) {
            tableView.selectRowIndexes(IndexSet(integer: vm.selectedIndex), byExtendingSelection: false)
        }
    }

    // MARK: - Positioning & visibility

    private func centerOnMainScreen() {
        guard let screen = NSScreen.main, let panel = window else { return }
        let visible = screen.visibleFrame
        let x = visible.midX - panel.frame.width / 2
        let y = visible.midY + panel.frame.height / 2
        panel.setFrameTopLeftPoint(NSPoint(x: x, y: y))
    }

    override func showWindow(_ sender: Any?) {
        viewModel?.query = ""
        viewModel?.selectedIndex = 0
        centerOnMainScreen()
        installMonitors()
        // Do NOT call NSApp.activate — the .nonactivatingPanel style lets the panel
        // become key (receive keyboard) without stealing app focus. The previously
        // active app remains the AX-focused application so window management commands
        // (maximize, snap, etc.) target the correct window.
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(searchField)
    }

    override func close() {
        removeMonitors()
        window?.orderOut(nil)
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        viewModel?.results.count ?? 0
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let vm = viewModel, vm.results.indices.contains(row) else { return nil }
        let item = vm.results[row]

        let rowView: ResultRowView
        if let recycled = tableView.makeView(withIdentifier: Self.rowIdentifier, owner: self) as? ResultRowView {
            rowView = recycled
        } else {
            rowView = ResultRowView()
            rowView.identifier = Self.rowIdentifier
        }

        let icon: NSImage?
        switch item {
        case .app(let entry): icon = NSWorkspace.shared.icon(forFile: entry.path.path)
        case .clip:           icon = Self.clipIcon
        case .snippet:        icon = Self.snippetIcon
        case .quicklink:      icon = Self.linkIcon
        case .command:        icon = Self.commandIcon
        case .windowAction:   icon = Self.windowIcon
        }

        rowView.configure(with: item, icon: icon)
        return rowView
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard row >= 0 else { return }
        viewModel?.selectedIndex = row
    }
}

extension WindowController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        viewModel?.query = searchField.stringValue
    }
}
