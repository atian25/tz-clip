import Cocoa

class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

class OverlayWindowController: NSWindowController {
    init(screen: NSScreen, windowProvider: WindowInfoProvider? = nil) {
        let frame = screen.frame
        let window = OverlayWindow(contentRect: frame, styleMask: [.borderless, .fullSizeContentView], backing: .buffered, defer: false, screen: screen)
        window.level = .screenSaver
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.acceptsMouseMovedEvents = true
        super.init(window: window)
        let viewRect = NSRect(origin: .zero, size: frame.size)
        let view = SelectionView(frame: viewRect)
        view.windowProvider = windowProvider
        window.contentView = view
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func setInitialized(_ initialized: Bool) { (self.window?.contentView as? SelectionView)?.isInitialized = initialized }
}
