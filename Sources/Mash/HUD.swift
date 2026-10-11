import AppKit

/// A brief on-screen confirmation, since the menu bar is hidden while the game is fullscreen.
final class HUD {
    private let label = NSTextField(labelWithString: "")
    private lazy var panel = makePanel()
    private var hideWork: DispatchWorkItem?

    func show(_ text: String) {
        label.stringValue = text
        guard let contentView = panel.contentView else { return }
        let size = contentView.fittingSize

        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let frame = screen?.frame else { return }
        let origin = NSPoint(x: frame.midX - size.width / 2, y: frame.maxY - size.height - 80)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)

        hideWork?.cancel()
        panel.alphaValue = 1
        panel.orderFrontRegardless()

        let work = DispatchWorkItem { [weak self] in self?.fadeOut() }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
    }

    private func fadeOut() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self, self.panel.alphaValue == 0 else { return }
            self.panel.orderOut(nil)
        })
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        // SDL raises a focused fullscreen window to the shielding level, so the HUD has to sit above that.
        panel.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.appearance = NSAppearance(named: .vibrantDark)

        let background = NSVisualEffectView()
        background.material = .hudWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 12
        background.layer?.masksToBounds = true

        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .labelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 18),
            label.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -18),
            label.topAnchor.constraint(equalTo: background.topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -10),
        ])

        panel.contentView = background
        return panel
    }
}
