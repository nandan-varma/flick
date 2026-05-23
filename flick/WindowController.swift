import AppKit
import Observation

private final class LauncherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private enum Row {
    case header(String)
    case item(any FlickCommand, Int)

    var isHeader: Bool {
        if case .header = self { return true }
        return false
    }
}

@MainActor
final class WindowController: NSWindowController, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate {

    private enum Layout {
        static let panelWidth: CGFloat = 680
        static let itemRowHeight: CGFloat = 52
        static let headerRowHeight: CGFloat = 24
        static let searchAreaHeight: CGFloat = 60
        static let calculatorHeight: CGFloat = 32
        static let actionBarHeight: CGFloat = 38
        static let separatorHeight: CGFloat = 1
        static let maxVisibleItems = 8
        static let chatPanelHeight: CGFloat = 460
        static let aiInlineMaxHeight: CGFloat = 150
    }

    private static let rowIdentifier       = NSUserInterfaceItemIdentifier("ResultRow")
    private static let headerIdentifier    = NSUserInterfaceItemIdentifier("HeaderRow")

    weak var viewModel: AppViewModel?

    private let searchField = NSTextField()
    private let calculatorLabel = NSTextField(labelWithString: "")
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    // Chat mode: reuses scrollView by swapping its documentView to chatTextView
    private let chatTextView = NSTextView()
    // Inline AI response area (shown automatically when query has "ai " prefix)
    private let aiInlineScrollView = NSScrollView()
    private let aiInlineTextView = NSTextView()
    private let aiInlineSeparator = NSBox()
    private let actionBar = ActionBarView()
    private let topSeparator = NSBox()
    private let bottomSeparator = NSBox()

    private var calculatorHeightConstraint: NSLayoutConstraint?
    private var aiInlineHeightConstraint: NSLayoutConstraint?
    private var aiInlineSeparatorHeightConstraint: NSLayoutConstraint?
    private var scrollHeightConstraint: NSLayoutConstraint?
    private var actionBarHeightConstraint: NSLayoutConstraint?
    private var keyDownMonitor: Any?
    private var clickOutsideMonitor: Any?

    private var rows: [Row] = []

    init(viewModel: AppViewModel) {
        self.viewModel = viewModel

        let panel = LauncherPanel(
            contentRect: CGRect(x: 0, y: 0, width: Layout.panelWidth, height: 200),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.alphaValue = 0

        super.init(window: panel)
        panel.delegate = self

        setupVisualEffect(panel: panel)
        setupSearchField()
        setupCalculatorLabel()
        setupSeparators()
        setupAIInlineView()
        setupTableView()
        setupChatView()
        setupActionBar()
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
        searchField.placeholderString = "Search apps, actions, and more…"
        searchField.isBordered = false
        searchField.drawsBackground = false
        searchField.font = .systemFont(ofSize: 18, weight: .light)
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
        calculatorLabel.font = .monospacedSystemFont(ofSize: 22, weight: .medium)
        calculatorLabel.textColor = .labelColor
        calculatorLabel.alignment = .center
        calculatorLabel.isHidden = true
        calculatorLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(calculatorLabel)
        let h = calculatorLabel.heightAnchor.constraint(equalToConstant: 0)
        calculatorHeightConstraint = h
        NSLayoutConstraint.activate([
            calculatorLabel.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 4),
            calculatorLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            calculatorLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            h,
        ])
    }

    private func setupSeparators() {
        guard let contentView = window?.contentView else { return }
        for sep in [topSeparator, bottomSeparator] {
            sep.boxType = .separator
            sep.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(sep)
        }
        NSLayoutConstraint.activate([
            topSeparator.topAnchor.constraint(equalTo: calculatorLabel.bottomAnchor, constant: 4),
            topSeparator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            topSeparator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            topSeparator.heightAnchor.constraint(equalToConstant: Layout.separatorHeight),
        ])
    }

    private func setupAIInlineView() {
        guard let contentView = window?.contentView else { return }

        aiInlineTextView.isEditable = false
        aiInlineTextView.isSelectable = true
        aiInlineTextView.drawsBackground = false
        aiInlineTextView.textContainerInset = NSSize(width: 16, height: 10)
        aiInlineTextView.isVerticallyResizable = true
        aiInlineTextView.isHorizontallyResizable = false
        aiInlineTextView.autoresizingMask = [.width]
        aiInlineTextView.textContainer?.widthTracksTextView = true
        aiInlineTextView.textContainer?.containerSize = NSSize(
            width: Layout.panelWidth, height: .greatestFiniteMagnitude
        )

        aiInlineScrollView.documentView = aiInlineTextView
        aiInlineScrollView.hasVerticalScroller = true
        aiInlineScrollView.hasHorizontalScroller = false
        aiInlineScrollView.drawsBackground = false
        aiInlineScrollView.translatesAutoresizingMaskIntoConstraints = false

        aiInlineSeparator.boxType = .separator
        aiInlineSeparator.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(aiInlineScrollView)
        contentView.addSubview(aiInlineSeparator)

        let aih = aiInlineScrollView.heightAnchor.constraint(equalToConstant: 0)
        let ash = aiInlineSeparator.heightAnchor.constraint(equalToConstant: 0)
        aiInlineHeightConstraint = aih
        aiInlineSeparatorHeightConstraint = ash

        NSLayoutConstraint.activate([
            aiInlineScrollView.topAnchor.constraint(equalTo: topSeparator.bottomAnchor),
            aiInlineScrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            aiInlineScrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            aih,

            aiInlineSeparator.topAnchor.constraint(equalTo: aiInlineScrollView.bottomAnchor),
            aiInlineSeparator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            aiInlineSeparator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            ash,
        ])
    }

    private func setupTableView() {
        guard let contentView = window?.contentView else { return }
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("results"))
        col.isEditable = false
        tableView.addTableColumn(col)
        tableView.headerView = nil
        tableView.rowHeight = Layout.itemRowHeight
        tableView.selectionHighlightStyle = .regular
        tableView.backgroundColor = .clear
        tableView.intercellSpacing = .zero
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.doubleAction = #selector(tableRowDoubleClicked)
        tableView.style = .plain

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.automaticallyAdjustsContentInsets = false

        contentView.addSubview(scrollView)
        let sh = scrollView.heightAnchor.constraint(equalToConstant: 0)
        scrollHeightConstraint = sh
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: aiInlineSeparator.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            sh,
        ])
    }

    private func setupChatView() {
        // chatTextView will become scrollView's documentView in chat mode.
        // Configure it here; it is not in the view hierarchy until mode switches.
        chatTextView.isEditable = false
        chatTextView.isSelectable = true
        chatTextView.drawsBackground = false
        chatTextView.textContainerInset = NSSize(width: 14, height: 14)
        chatTextView.isVerticallyResizable = true
        chatTextView.isHorizontallyResizable = false
        chatTextView.autoresizingMask = [.width]
        chatTextView.textContainer?.widthTracksTextView = true
        chatTextView.textContainer?.containerSize = NSSize(
            width: Layout.panelWidth, height: .greatestFiniteMagnitude
        )
    }

    private func setupActionBar() {
        guard let contentView = window?.contentView else { return }
        actionBar.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(actionBar)
        let ah = actionBar.heightAnchor.constraint(equalToConstant: 0)
        actionBarHeightConstraint = ah
        NSLayoutConstraint.activate([
            bottomSeparator.topAnchor.constraint(equalTo: scrollView.bottomAnchor),
            bottomSeparator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            bottomSeparator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            bottomSeparator.heightAnchor.constraint(equalToConstant: Layout.separatorHeight),

            actionBar.topAnchor.constraint(equalTo: bottomSeparator.bottomAnchor),
            actionBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            actionBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            actionBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            ah,
        ])
    }

    // MARK: - Event monitors

    private func installMonitors() {
        guard keyDownMonitor == nil else { return }
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event: event) ?? event
        }
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

        if vm.mode == .chat {
            switch event.keyCode {
            case 36, 76: // Return — send message
                let prompt = searchField.stringValue
                searchField.stringValue = ""
                Task { await vm.chatViewModel?.send(prompt) }
                return nil
            case 53: // Escape — exit chat
                vm.exitChatMode()
                searchField.stringValue = ""
                vm.query = ""
                return nil
            default:
                return event
            }
        }

        switch event.keyCode {
        case 125: // ↓
            moveSelection(by: 1)
            return nil
        case 126: // ↑
            moveSelection(by: -1)
            return nil
        case 36, 76: // Return / numpad Enter
            if vm.inlineAIResponse != nil {
                // Copy the inline AI response and dismiss
                vm.copyInlineAIResponse()
                close()
            } else {
                vm.runSelected()
                // Only close if the command didn't switch to chat mode
                if vm.mode == .search {
                    close()
                }
            }
            return nil
        case 53: // Escape
            if vm.inlineAIResponse != nil || vm.inlineAIStreaming {
                // Cancel inline AI without closing
                vm.cancelInlineAI()
                searchField.stringValue = ""
                vm.query = ""
            } else {
                close()
            }
            return nil
        default:
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "k" {
                showActionsPanel()
                return nil
            }
            return event
        }
    }

    private func moveSelection(by delta: Int) {
        let current = tableView.selectedRow
        var next = current + delta
        while rows.indices.contains(next) {
            if case .item(_, let idx) = rows[next] {
                tableView.selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
                tableView.scrollRowToVisible(next)
                viewModel?.selectedIndex = idx
                updateActionBar()
                return
            }
            next += delta
        }
    }

    @objc private func tableRowDoubleClicked() {
        guard let vm = viewModel, tableView.clickedRow >= 0 else { return }
        guard case .item(_, let idx) = rows[tableView.clickedRow] else { return }
        vm.selectedIndex = idx
        close()
        vm.runSelected()
    }

    private func showActionsPanel() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0,
              rows.indices.contains(selectedRow),
              case .item(let cmd, _) = rows[selectedRow],
              let appCmd = cmd as? AppLaunchCommand else { return }
        NSWorkspace.shared.activateFileViewerSelecting([appCmd.appPath])
        close()
    }

    // MARK: - Observation

    func observeViewModel() {
        withObservationTracking {
            _ = viewModel?.results
            _ = viewModel?.calculatorResult
            _ = viewModel?.mode
            _ = viewModel?.inlineAIResponse
            _ = viewModel?.inlineAIStreaming
            _ = viewModel?.chatViewModel?.messages
            _ = viewModel?.chatViewModel?.isStreaming
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                self?.applyMode()
                self?.observeViewModel()
            }
        }
    }

    // MARK: - Mode management

    private func applyMode() {
        guard window?.isVisible == true, let vm = viewModel else { return }

        // Always sync inline AI view first (affects layout in search mode)
        updateAIInlineView()

        switch vm.mode {
        case .search:
            if scrollView.documentView !== tableView {
                scrollView.documentView = tableView
            }
            searchField.placeholderString = "Search apps, actions, and more…"
            reloadTable()
        case .chat:
            aiInlineHeightConstraint?.constant = 0
            aiInlineSeparatorHeightConstraint?.constant = 0
            if scrollView.documentView !== chatTextView {
                chatTextView.frame = NSRect(
                    x: 0, y: 0,
                    width: scrollView.contentSize.width,
                    height: scrollView.contentSize.height
                )
                scrollView.documentView = chatTextView
            }
            searchField.placeholderString = "Ask AI anything…"
            calculatorLabel.isHidden = true
            calculatorHeightConstraint?.constant = 0
            syncChatTextView()
            resizePanelForChat()
        }
    }

    private func updateAIInlineView() {
        guard let vm = viewModel else { return }
        let active = vm.inlineAIStreaming || vm.inlineAIResponse != nil
        if active {
            aiInlineHeightConstraint?.constant = Layout.aiInlineMaxHeight
            aiInlineSeparatorHeightConstraint?.constant = Layout.separatorHeight
            syncAIInlineTextView()
        } else {
            aiInlineHeightConstraint?.constant = 0
            aiInlineSeparatorHeightConstraint?.constant = 0
        }
    }

    private func syncAIInlineTextView() {
        guard let vm = viewModel else { return }
        let result = NSMutableAttributedString()

        let isStreaming = vm.inlineAIStreaming
        let text = vm.inlineAIResponse

        if isStreaming && (text?.isEmpty ?? true) {
            result.append(NSAttributedString(
                string: "Generating…",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 13),
                    .foregroundColor: NSColor.tertiaryLabelColor,
                ]
            ))
        } else if let response = text {
            result.append(NSAttributedString(
                string: response,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 13),
                    .foregroundColor: NSColor.labelColor,
                ]
            ))
            if isStreaming {
                result.append(NSAttributedString(
                    string: " ▋",
                    attributes: [
                        .font: NSFont.systemFont(ofSize: 13),
                        .foregroundColor: NSColor.tertiaryLabelColor,
                    ]
                ))
            }
        }

        aiInlineTextView.textStorage?.setAttributedString(result)
        aiInlineTextView.scrollToEndOfDocument(nil)
    }

    private func syncChatTextView() {
        guard let vm = viewModel, let chatVM = vm.chatViewModel else { return }

        let result = NSMutableAttributedString()

        if chatVM.messages.isEmpty {
            let placeholder = NSAttributedString(
                string: "Ask anything. Runs entirely on-device.\n",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 13),
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
            )
            result.append(placeholder)
        }

        for (i, msg) in chatVM.messages.enumerated() {
            if i > 0 { result.append(NSAttributedString(string: "\n\n")) }
            switch msg.role {
            case .user:
                result.append(NSAttributedString(string: "You\n", attributes: [
                    .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                    .foregroundColor: NSColor.tertiaryLabelColor
                ]))
                result.append(NSAttributedString(string: msg.text, attributes: [
                    .font: NSFont.systemFont(ofSize: 13),
                    .foregroundColor: NSColor.labelColor
                ]))
            case .assistant:
                result.append(NSAttributedString(string: "AI\n", attributes: [
                    .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                    .foregroundColor: NSColor.tertiaryLabelColor
                ]))
                let text = msg.isStreaming && msg.text.isEmpty ? "…" : msg.text
                result.append(NSAttributedString(string: text, attributes: [
                    .font: NSFont.systemFont(ofSize: 13),
                    .foregroundColor: NSColor.secondaryLabelColor
                ]))
            }
        }

        chatTextView.textStorage?.setAttributedString(result)
        // Scroll to bottom so latest response is visible
        chatTextView.scrollToEndOfDocument(nil)

        // Update action bar
        let isStreaming = chatVM.isStreaming
        actionBar.configure(
            actionLabel: isStreaming ? "AI is thinking…" : "On-device · private",
            icon: NSImage(systemSymbolName: isStreaming ? "ellipsis" : "brain", accessibilityDescription: nil)
        )
        actionBarHeightConstraint?.constant = Layout.actionBarHeight
        topSeparator.isHidden = false
        bottomSeparator.isHidden = false
    }

    private func resizePanelForChat() {
        let totalHeight = Layout.chatPanelHeight
        let chatHeight = totalHeight
            - Layout.searchAreaHeight
            - Layout.separatorHeight * 2
            - Layout.actionBarHeight
        scrollHeightConstraint?.constant = chatHeight
        guard let panel = window else { return }
        var frame = panel.frame
        frame.origin.y += frame.height - totalHeight
        frame.size.height = totalHeight
        panel.setFrame(frame, display: true, animate: false)
    }

    // MARK: - Table reload & window sizing

    private func reloadTable() {
        guard window?.isVisible == true, let vm = viewModel else { return }

        let hasCalcResult = vm.calculatorResult != nil
        calculatorLabel.isHidden = !hasCalcResult
        calculatorHeightConstraint?.constant = hasCalcResult ? Layout.calculatorHeight : 0
        if let value = vm.calculatorResult {
            calculatorLabel.stringValue = "= \(value)"
        }

        rows = buildRows(from: vm.results)
        tableView.reloadData()

        let hasResults = !vm.results.isEmpty
        let tableHeight = computeTableHeight()
        scrollHeightConstraint?.constant = tableHeight

        let actionBarHeight: CGFloat = (hasResults || hasCalcResult) ? Layout.actionBarHeight : 0
        actionBarHeightConstraint?.constant = actionBarHeight

        let calcAreaHeight: CGFloat = hasCalcResult ? Layout.calculatorHeight + 8 : 0
        let separators: CGFloat = hasResults ? Layout.separatorHeight * 2 : 0
        let aiHeight = (aiInlineHeightConstraint?.constant ?? 0) + (aiInlineSeparatorHeightConstraint?.constant ?? 0)
        let totalHeight = Layout.searchAreaHeight + calcAreaHeight + aiHeight + tableHeight + separators + actionBarHeight + 4

        if let panel = window {
            var frame = panel.frame
            frame.origin.y += frame.height - totalHeight
            frame.size.height = totalHeight
            panel.setFrame(frame, display: true, animate: false)
        }

        let firstItemRow = rows.firstIndex { !$0.isHeader }
        if let first = firstItemRow, !rows.isEmpty {
            if tableView.selectedRow < 0 || !rows.indices.contains(tableView.selectedRow) {
                tableView.selectRowIndexes(IndexSet(integer: first), byExtendingSelection: false)
                if case .item(_, let idx) = rows[first] {
                    vm.selectedIndex = idx
                }
            }
        } else {
            tableView.deselectAll(nil)
        }

        let hasInlineAI = (viewModel?.inlineAIResponse != nil || viewModel?.inlineAIStreaming == true)
        topSeparator.isHidden = !hasResults && !hasInlineAI
        bottomSeparator.isHidden = !(hasResults || hasCalcResult || hasInlineAI)
        updateActionBar()
    }

    private func buildRows(from results: [any FlickCommand]) -> [Row] {
        // Section headers only on the home screen; search results are flat by score.
        let addHeaders = viewModel?.isHomeScreen == true
        guard addHeaders else {
            return results.enumerated().map { .item($1, $0) }
        }
        var built: [Row] = []
        var lastSection: String? = nil
        for (i, item) in results.enumerated() {
            let section = item.sectionTitle
            if section != lastSection {
                built.append(.header(section))
                lastSection = section
            }
            built.append(.item(item, i))
        }
        return built
    }

    private func computeTableHeight() -> CGFloat {
        guard !rows.isEmpty else { return 0 }
        // Cap display at maxVisibleItems items (not counting headers)
        var itemsSeen = 0
        var height: CGFloat = 0
        for row in rows {
            if row.isHeader {
                height += Layout.headerRowHeight
            } else {
                height += Layout.itemRowHeight
                itemsSeen += 1
                if itemsSeen >= Layout.maxVisibleItems { break }
            }
        }
        return height
    }

    private func updateActionBar() {
        guard let vm = viewModel else { return }
        if let calcResult = vm.calculatorResult {
            actionBar.configure(
                actionLabel: "Copy \"\(calcResult)\"",
                icon: NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: nil)
            )
            return
        }
        if vm.inlineAIStreaming {
            actionBar.configure(
                actionLabel: "Generating…",
                icon: NSImage(systemSymbolName: "brain", accessibilityDescription: nil)
            )
            actionBarHeightConstraint?.constant = Layout.actionBarHeight
            return
        }
        if vm.inlineAIResponse != nil {
            actionBar.configure(
                actionLabel: "Copy AI Response",
                icon: NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: nil)
            )
            actionBarHeightConstraint?.constant = Layout.actionBarHeight
            return
        }
        let row = tableView.selectedRow
        if rows.indices.contains(row), case .item(let cmd, _) = rows[row] {
            actionBar.configure(actionLabel: cmd.actionLabel, icon: cmd.icon)
        } else {
            actionBar.configure(actionLabel: "", icon: nil)
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
        // Reset to search mode and clear query each time the panel appears.
        viewModel?.cancelInlineAI()
        viewModel?.mode = .search
        searchField.stringValue = ""
        viewModel?.query = ""
        viewModel?.selectedIndex = 0
        rows = []
        centerOnMainScreen()
        installMonitors()
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(searchField)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window?.animator().alphaValue = 1
        }
    }

    override func close() {
        removeMonitors()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.08
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window?.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            DispatchQueue.main.async { self?.window?.orderOut(nil) }
        }
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        rows.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard rows.indices.contains(row) else { return Layout.itemRowHeight }
        return rows[row].isHeader ? Layout.headerRowHeight : Layout.itemRowHeight
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        guard rows.indices.contains(row), !rows[row].isHeader else { return NSTableRowView() }
        return RoundedTableRowView()
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard rows.indices.contains(row) else { return nil }

        switch rows[row] {
        case .header(let title):
            let v: SectionHeaderView
            if let recycled = tableView.makeView(withIdentifier: Self.headerIdentifier, owner: self) as? SectionHeaderView {
                v = recycled
            } else {
                v = SectionHeaderView()
                v.identifier = Self.headerIdentifier
            }
            v.configure(title: title)
            return v

        case .item(let cmd, _):
            let v: ResultRowView
            if let recycled = tableView.makeView(withIdentifier: Self.rowIdentifier, owner: self) as? ResultRowView {
                v = recycled
            } else {
                v = ResultRowView()
                v.identifier = Self.rowIdentifier
            }
            v.configure(with: cmd)
            return v
        }
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        guard rows.indices.contains(row) else { return false }
        return !rows[row].isHeader
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard row >= 0, rows.indices.contains(row), case .item(_, let idx) = rows[row] else { return }
        viewModel?.selectedIndex = idx
        updateActionBar()
    }
}

extension WindowController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        viewModel?.query = searchField.stringValue
    }
}

// MARK: - ActionBarView

private final class ActionBarView: NSView {
    private let iconView = NSImageView()
    private let actionLabel = NSTextField(labelWithString: "")
    private let enterBadge = BadgeLabel(text: "↵")
    private let actionsLabel = NSTextField(labelWithString: "Actions")
    private let cmdKBadge = BadgeLabel(text: "⌘K")

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false

        actionLabel.font = .systemFont(ofSize: 12)
        actionLabel.textColor = .secondaryLabelColor
        actionLabel.lineBreakMode = .byTruncatingTail
        actionLabel.translatesAutoresizingMaskIntoConstraints = false
        actionLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        actionsLabel.font = .systemFont(ofSize: 12)
        actionsLabel.textColor = .secondaryLabelColor
        actionsLabel.translatesAutoresizingMaskIntoConstraints = false
        actionsLabel.setContentHuggingPriority(.required, for: .horizontal)

        for v in [iconView, actionLabel, enterBadge, actionsLabel, cmdKBadge] as [NSView] {
            addSubview(v)
        }

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),

            actionLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
            actionLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            cmdKBadge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            cmdKBadge.centerYAnchor.constraint(equalTo: centerYAnchor),

            actionsLabel.trailingAnchor.constraint(equalTo: cmdKBadge.leadingAnchor, constant: -6),
            actionsLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            enterBadge.trailingAnchor.constraint(equalTo: actionsLabel.leadingAnchor, constant: -16),
            enterBadge.centerYAnchor.constraint(equalTo: centerYAnchor),

            actionLabel.trailingAnchor.constraint(lessThanOrEqualTo: enterBadge.leadingAnchor, constant: -8),
        ])
    }

    func configure(actionLabel text: String, icon: NSImage?) {
        iconView.image = icon
        actionLabel.stringValue = text
    }
}

private final class BadgeLabel: NSView {
    private let label = NSTextField(labelWithString: "")

    init(text: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 4
        layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        label.stringValue = text
        label.font = .systemFont(ofSize: 10, weight: .medium)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func updateLayer() {
        layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
    }
}
