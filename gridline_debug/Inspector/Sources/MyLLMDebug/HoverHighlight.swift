import AppKit

@MainActor
final class HoverHighlight {
    private var panel: NSPanel?
    private let border = HoverBorderView()
    private let borderWidth: CGFloat = 2

    func show(_ element: DebugElement?) {
        guard let frame = element?.highlightFrame else {
            hide()
            return
        }
        let overlayFrame = frame.insetBy(dx: -borderWidth / 2, dy: -borderWidth / 2)
        let window = panel ?? makePanel(frame: overlayFrame)
        panel = window
        window.setFrame(overlayFrame, display: true)
        window.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel(frame: CGRect) -> NSPanel {
        let window = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isFloatingPanel = true
        window.hidesOnDeactivate = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        window.setAccessibilityElement(false)
        border.frame = CGRect(origin: .zero, size: frame.size)
        border.autoresizingMask = [.width, .height]
        window.contentView = border
        return window
    }
}

private final class HoverBorderView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.borderColor = NSColor.systemMint.withAlphaComponent(0.98).cgColor
        layer?.borderWidth = 2
        layer?.cornerRadius = 7
        layer?.shadowColor = NSColor.systemMint.cgColor
        layer?.shadowOpacity = 0.8
        layer?.shadowRadius = 7
        layer?.shadowOffset = .zero
        setAccessibilityElement(false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
