import Cocoa

class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}

class OverlayWindowController: NSWindowController {
    
    init(screen: NSScreen, windowProvider: WindowInfoProvider? = nil) {
        let frame = screen.frame
        print("Initializing overlay for screen: \(frame)")
        
        let window = OverlayWindow(
            contentRect: frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        
        window.level = .screenSaver
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.acceptsMouseMovedEvents = true // 关键：开启鼠标移动事件
        
        super.init(window: window)
        
        // View frame should be relative to window (0,0), not screen coordinates
        let viewRect = NSRect(origin: .zero, size: frame.size)
        let view = SelectionView(frame: viewRect)
        view.windowProvider = windowProvider
        window.contentView = view
        
        // 必须 makeKey 才能接收键盘事件
        window.makeKeyAndOrderFront(nil)
        // 显式将 View 设为第一响应者
        window.makeFirstResponder(view)
        print("Overlay window ordered front")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
