import AppKit

final class ResultRowView: NSTableCellView {
    private let iconView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let badgeLabel = NSTextField(labelWithString: "")
    private let badgeBackground = NSView()
    private let stack = NSStackView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = .systemFont(ofSize: 14, weight: .medium)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        subtitleLabel.font = .systemFont(ofSize: 11)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(nameLabel)
        stack.addArrangedSubview(subtitleLabel)

        badgeLabel.font = .systemFont(ofSize: 10, weight: .medium)
        badgeLabel.textColor = .secondaryLabelColor
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.setContentHuggingPriority(.required, for: .horizontal)
        badgeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        badgeBackground.wantsLayer = true
        badgeBackground.layer?.cornerRadius = 4
        badgeBackground.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        badgeBackground.translatesAutoresizingMaskIntoConstraints = false
        badgeBackground.addSubview(badgeLabel)

        addSubview(iconView)
        addSubview(stack)
        addSubview(badgeBackground)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),

            stack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: badgeBackground.leadingAnchor, constant: -8),

            badgeBackground.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            badgeBackground.centerYAnchor.constraint(equalTo: centerYAnchor),

            badgeLabel.topAnchor.constraint(equalTo: badgeBackground.topAnchor, constant: 3),
            badgeLabel.bottomAnchor.constraint(equalTo: badgeBackground.bottomAnchor, constant: -3),
            badgeLabel.leadingAnchor.constraint(equalTo: badgeBackground.leadingAnchor, constant: 6),
            badgeLabel.trailingAnchor.constraint(equalTo: badgeBackground.trailingAnchor, constant: -6),
        ])
    }

    func configure(with item: ResultItem, icon: NSImage?) {
        iconView.image = icon
        nameLabel.stringValue = item.displayName
        if let sub = item.subtitle, !sub.isEmpty {
            subtitleLabel.stringValue = sub
            subtitleLabel.isHidden = false
        } else {
            subtitleLabel.isHidden = true
        }
        badgeLabel.stringValue = item.category
    }

    override func updateLayer() {
        badgeBackground.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
    }
}

final class SectionHeaderView: NSTableCellView {
    private let titleLabel = NSTextField(labelWithString: "")

    override init(frame: NSRect) {
        super.init(frame: frame)
        titleLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        titleLabel.textColor = .tertiaryLabelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String) {
        titleLabel.stringValue = title.uppercased()
    }
}

final class RoundedTableRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        guard selectionHighlightStyle != .none else { return }
        let rect = bounds.insetBy(dx: 6, dy: 2)
        let path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        NSColor.controlAccentColor.withAlphaComponent(0.18).setFill()
        path.fill()
    }
}
