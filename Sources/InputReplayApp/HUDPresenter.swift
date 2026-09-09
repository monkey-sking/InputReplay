import AppKit

final class HUDPresenter {
    private var panel: NSPanel?
    private var dismissWorkItem: DispatchWorkItem?

    func show(title: String, detail: String? = nil, duration: TimeInterval = 2.2) {
        dismissWorkItem?.cancel()

        let contentView = NSVisualEffectView()
        contentView.material = .hudWindow
        contentView.blendingMode = .behindWindow
        contentView.state = .active
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = 12
        contentView.layer?.masksToBounds = true

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 3
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(titleLabel)

        if let detail, !detail.isEmpty {
            let detailLabel = NSTextField(labelWithString: detail)
            detailLabel.font = .systemFont(ofSize: 11)
            detailLabel.textColor = .secondaryLabelColor
            detailLabel.lineBreakMode = .byTruncatingTail
            stack.addArrangedSubview(detailLabel)
        }

        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: 360)
        ])

        let fitting = contentView.fittingSize
        let width = max(180, min(390, fitting.width))
        let height = max(44, fitting.height)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        panel.contentView = contentView

        position(panel)
        panel.orderFrontRegardless()
        self.panel?.orderOut(nil)
        self.panel = panel

        let workItem = DispatchWorkItem { [weak self, weak panel] in
            panel?.orderOut(nil)
            if self?.panel === panel {
                self?.panel = nil
            }
        }
        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
    }

    func dismiss() {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        panel?.orderOut(nil)
        panel = nil
    }

    private func position(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = panel.frame.size

        var x = mouse.x + 16
        var y = mouse.y - size.height - 14

        if x + size.width > visible.maxX - 8 {
            x = visible.maxX - size.width - 8
        }
        if y < visible.minY + 8 {
            y = mouse.y + 18
        }
        x = max(visible.minX + 8, x)
        y = min(visible.maxY - size.height - 8, max(visible.minY + 8, y))

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
