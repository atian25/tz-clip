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
        // 注意：我们不要在这里调用 makeKeyAndOrderFront，因为这可能会在多屏幕时导致焦点抢夺混乱。
        // 我们会在 AppDelegate 中根据鼠标位置决定谁是 Key。
        // 但是，为了确保窗口能够立即接收事件，我们这里只 orderFront，或者不做操作，由 AppDelegate 统一管理。
        // 不过，OverlayWindowController 初始化时通常希望窗口就绪。
        
        // 关键修复：允许非激活应用时的点击事件穿透到窗口
        // 但我们已经设置了 acceptsFirstMouse 在 View 层。
        // 问题可能在于 ActivationPolicy 的切换时机。
        
        // 我们只在 AppDelegate 中统一调用 makeKeyAndOrderFront
        // window.makeKeyAndOrderFront(nil) 
        // window.makeFirstResponder(view)
        print("Overlay window initialized")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
