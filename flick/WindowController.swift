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

    private static let rowIdentifier = NSUserInterfaceItemIdentifier("ResultRowView")

    weak var viewModel: AppViewModel?
    private let searchField = NSTextField()
    private let calculatorLabel = NSTextField(labelWithString: "")
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private var calculatorHeightConstraint: NSLayoutConstraint?
    private var keyDownMonitor: Any?
    private var mouseDownMonitor: Any?

    init(viewModel: AppViewModel) {
        self.viewModel = viewModel

        let panel = LauncherPanel(
            contentRect: CGRect(x: 0, y: 0, width: 640, height: 480),
            styleMask: [.nonactivatingPanel, .borderless, .resizable, .fullSizeContentView],
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

        searchField.placeholderString = "Search apps, commands…"
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

    private func installMonitors() {
        guard keyDownMonitor == nil else { return }
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event: event) ?? event
        }
        mouseDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.handleMouseDown(event: event) ?? event
        }
    }

    private func removeMonitors() {
        if let m = keyDownMonitor { NSEvent.removeMonitor(m); keyDownMonitor = nil }
        if let m = mouseDownMonitor { NSEvent.removeMonitor(m); mouseDownMonitor = nil }
    }

    private func handleKeyDown(event: NSEvent) -> NSEvent? {
        guard let vm = viewModel else { return event }
        switch event.keyCode {
        case 125:
            vm.moveDown()
            tableView.selectRowIndexes(IndexSet(integer: vm.selectedIndex), byExtendingSelection: false)
            tableView.scrollRowToVisible(vm.selectedIndex)
            return nil
        case 126:
            vm.moveUp()
            tableView.selectRowIndexes(IndexSet(integer: vm.selectedIndex), byExtendingSelection: false)
            tableView.scrollRowToVisible(vm.selectedIndex)
            return nil
        case 36, 76:
            vm.runSelected()
            close()
            return nil
        case 53:
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

    private func handleMouseDown(event: NSEvent) -> NSEvent? {
        guard let panel = window else { return event }
        let screenLocation = panel.convertPoint(toScreen: event.locationInWindow)
        if !panel.frame.contains(screenLocation) { close() }
        return event
    }

    private func showActionsPanel() {
        guard let vm = viewModel, vm.results.indices.contains(vm.selectedIndex) else { return }
        let item = vm.results[vm.selectedIndex]
        if case .app(let entry) = item {
            NSWorkspace.shared.activateFileViewerSelecting([entry.path])
            close()
        }
    }

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

    private func reloadTable() {
        guard let vm = viewModel else { return }

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

    func centerOnMainScreen() {
        guard let screen = NSScreen.main, let panel = window else { return }
        let visible = screen.visibleFrame
        let panelSize = panel.frame.size
        let x = visible.midX - panelSize.width / 2
        let y = visible.midY + panelSize.height / 2
        panel.setFrameTopLeftPoint(NSPoint(x: x, y: y))
    }

    override func showWindow(_ sender: Any?) {
        viewModel?.query = ""
        centerOnMainScreen()
        installMonitors()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(searchField)
    }

    override func close() {
        removeMonitors()
        window?.orderOut(nil)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        viewModel?.results.count ?? 0
    }

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
        case .app(let entry):
            icon = NSWorkspace.shared.icon(forFile: entry.path.path)
        case .clip:
            icon = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: nil)
        case .snippet:
            icon = NSImage(systemSymbolName: "text.quote", accessibilityDescription: nil)
        case .quicklink:
            icon = NSImage(systemSymbolName: "link", accessibilityDescription: nil)
        case .command:
            icon = NSImage(systemSymbolName: "terminal", accessibilityDescription: nil)
        case .windowAction:
            icon = NSImage(systemSymbolName: "rectangle.split.2x1", accessibilityDescription: nil)
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
