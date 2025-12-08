import Cocoa

class SelectionView: NSView {
    
    // 鼠标按下的起始点
    private var startPoint: NSPoint?
    // 当前鼠标位置
    private var currentPoint: NSPoint?
    // 计算出的选区矩形
    private var selectionRect: NSRect = .zero
    
    // 标记是否正在进行一次新的选择拖拽
    private var isDraggingSelection = false
    
    // 工具栏视图
    private var toolbarView: NSStackView?
    
    // 遮罩颜色
    private let overlayColor = NSColor.black.withAlphaComponent(0.5)
    // 边框颜色
    private let borderColor = NSColor.white
    // 边框宽度
    private let borderWidth: CGFloat = 1.0
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override var isFlipped: Bool {
        return false
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        if let toolbar = toolbarView, NSPointInRect(point, toolbar.frame) {
            return super.hitTest(point)
        }
        return self
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        overlayColor.setFill()
        dirtyRect.fill()
        
        if !selectionRect.isEmpty {
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current?.compositingOperation = .clear
            NSColor.clear.setFill()
            selectionRect.fill()
            NSGraphicsContext.restoreGraphicsState()
            
            borderColor.setStroke()
            let path = NSBezierPath(rect: selectionRect)
            path.lineWidth = borderWidth
            path.stroke()
        }
    }
    
    // MARK: - Event Handling
    
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        
        // 记录起始点，但不立即重置选区
        startPoint = convert(event.locationInWindow, from: nil)
        isDraggingSelection = false
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }
        
        let current = convert(event.locationInWindow, from: nil)
        
        // 如果是首次检测到拖拽（位移超过阈值），则开始新选区逻辑
        if !isDraggingSelection {
            let distance = hypot(current.x - start.x, current.y - start.y)
            if distance > 3.0 { // 3px 阈值防止抖动
                isDraggingSelection = true
                
                // 开始新选区：清除旧选区和工具栏
                selectionRect = .zero
                toolbarView?.removeFromSuperview()
                toolbarView = nil
                needsDisplay = true
            } else {
                return // 未达到阈值，忽略
            }
        }
        
        // 更新选区
        currentPoint = current
        selectionRect = NSRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
        
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        // 只有当真正进行了拖拽操作，或者当前没有选区时，才打印日志
        if isDraggingSelection {
            print("Selection completed: \(selectionRect)")
            
            if selectionRect.width > 10 && selectionRect.height > 10 {
                showToolbar()
            }
        } else {
            // 如果只是点击（没有拖拽），且之前有选区，则什么都不做（保留选区）
            // 除非是点击了空白处且没有选区（那是初始状态）
            
            // 补救措施：如果之前有选区被意外隐藏了（理论上不会，因为 mouseDown 没清空），这里只需确保工具栏可见
            if !selectionRect.isEmpty && toolbarView == nil {
                showToolbar()
            }
        }
        
        // 重置状态
        startPoint = nil
        isDraggingSelection = false
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            handleCancel()
            return
        }
        
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "q" {
            NSApp.terminate(nil)
            return
        }
        
        super.keyDown(with: event)
    }
    
    // MARK: - Toolbar Logic
    
    private func showToolbar() {
        toolbarView?.removeFromSuperview()
        
        let confirmBtn = NSButton(title: "Confirm", target: self, action: #selector(onConfirm))
        confirmBtn.bezelStyle = .rounded
        confirmBtn.controlSize = .regular
        confirmBtn.setButtonType(.momentaryPushIn)
        
        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(onCancelBtn))
        cancelBtn.bezelStyle = .rounded
        cancelBtn.controlSize = .regular
        cancelBtn.setButtonType(.momentaryPushIn)
        
        let stack = NSStackView(views: [cancelBtn, confirmBtn])
        stack.orientation = .horizontal
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        
        stack.wantsLayer = true
        stack.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        stack.layer?.cornerRadius = 6
        
        self.addSubview(stack)
        
        let toolbarSize = stack.fittingSize
        let padding: CGFloat = 8
        
        var x = selectionRect.maxX - toolbarSize.width
        x = max(padding, x)
        
        var y = selectionRect.minY - padding - toolbarSize.height
        if y < padding {
            y = selectionRect.maxY + padding
        }
        if y + toolbarSize.height > self.bounds.height {
            y = min(y, self.bounds.height - toolbarSize.height - padding)
        }
        
        stack.frame = NSRect(origin: NSPoint(x: x, y: y), size: toolbarSize)
        self.toolbarView = stack
    }
    
    @objc func onConfirm() {
        print("Confirmed capture: \(selectionRect)")
        NotificationCenter.default.post(name: .stopCapture, object: nil)
    }
    
    @objc func onCancelBtn() {
        print("Cancel button clicked - Exiting capture mode")
        NotificationCenter.default.post(name: .stopCapture, object: nil)
    }
    
    private func handleCancel() {
        if !selectionRect.isEmpty {
            selectionRect = .zero
            toolbarView?.removeFromSuperview()
            toolbarView = nil
            needsDisplay = true
        } else {
            NotificationCenter.default.post(name: .stopCapture, object: nil)
        }
    }
}
