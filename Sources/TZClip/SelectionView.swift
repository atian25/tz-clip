import Cocoa

// MARK: - Enums

enum InteractionState {
    case idle               // No selection
    case creating           // Dragging to create new selection
    case selected           // Selection exists, waiting for interaction
    case moving             // Moving the entire selection
    case resizing(Handle)   // Resizing via a handle
}

enum Handle: CaseIterable {
    case topLeft, top, topRight
    case left, right
    case bottomLeft, bottom, bottomRight
}

class SelectionView: NSView {
    
    // MARK: - Properties
    
    private var startPoint: NSPoint?
    private var selectionRect: NSRect = .zero
    
    // Interaction State
    private var state: InteractionState = .idle
    private var lastMouseLocation: NSPoint?
    
    // Configuration
    private let handleSize: CGFloat = 8.0
    private let overlayColor = NSColor.black.withAlphaComponent(0.5)
    private let borderColor = NSColor.white
    private let borderWidth: CGFloat = 1.0
    
    private var toolbarView: NSStackView?
    
    // Tracking area for cursor updates
    private var trackingArea: NSTrackingArea?
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override var isFlipped: Bool {
        return false
    }
    
    // MARK: - Lifecycle
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow]
        trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }
    
    // MARK: - Drawing
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Draw Overlay
        overlayColor.setFill()
        dirtyRect.fill()
        
        if !selectionRect.isEmpty {
            // Cut out selection
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current?.compositingOperation = .clear
            NSColor.clear.setFill()
            selectionRect.fill()
            NSGraphicsContext.restoreGraphicsState()
            
            // Draw Border
            borderColor.setStroke()
            let path = NSBezierPath(rect: selectionRect)
            path.lineWidth = borderWidth
            path.stroke()
            
            // Draw Handles if selected or moving/resizing
            // Only hide handles when we are creating a NEW selection
            if case .creating = state {
                // Don't draw handles
            } else {
                drawHandles()
            }
        }
    }
    
    private func drawHandles() {
        NSColor.white.setFill()
        for handle in Handle.allCases {
            let rect = rectForHandle(handle)
            let path = NSBezierPath(ovalIn: rect)
            path.fill()
        }
    }
    
    private func rectForHandle(_ handle: Handle) -> NSRect {
        let x = selectionRect.origin.x
        let y = selectionRect.origin.y
        let w = selectionRect.width
        let h = selectionRect.height
        let hs = handleSize
        let half = hs / 2
        
        var center = NSPoint.zero
        
        switch handle {
        case .topLeft:     center = NSPoint(x: x, y: y + h)
        case .top:         center = NSPoint(x: x + w / 2, y: y + h)
        case .topRight:    center = NSPoint(x: x + w, y: y + h)
        case .left:        center = NSPoint(x: x, y: y + h / 2)
        case .right:       center = NSPoint(x: x + w, y: y + h / 2)
        case .bottomLeft:  center = NSPoint(x: x, y: y)
        case .bottom:      center = NSPoint(x: x + w / 2, y: y)
        case .bottomRight: center = NSPoint(x: x + w, y: y)
        }
        
        return NSRect(x: center.x - half, y: center.y - half, width: hs, height: hs)
    }
    
    // MARK: - Hit Testing
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        if let toolbar = toolbarView, NSPointInRect(point, toolbar.frame) {
            return super.hitTest(point)
        }
        return self
    }
    
    private func handle(at point: NSPoint) -> Handle? {
        for handle in Handle.allCases {
            if rectForHandle(handle).contains(point) {
                return handle
            }
        }
        return nil
    }
    
    // MARK: - Mouse Events
    
    override func mouseMoved(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        
        if selectionRect.isEmpty {
            NSCursor.crosshair.set()
            return
        }
        
        if let h = handle(at: p) {
            cursorForHandle(h).set()
        } else if selectionRect.contains(p) {
            NSCursor.openHand.set()
        } else {
            NSCursor.crosshair.set()
        }
    }
    
    private func cursorForHandle(_ handle: Handle) -> NSCursor {
        switch handle {
        case .top, .bottom: return .resizeUpDown
        case .left, .right: return .resizeLeftRight
        // Using crosshair for corners as a simple default, or resizeUpDown/LeftRight
        // Ideally we would use diagonal cursors but they are not standard in NSCursor without private API or images
        default: return .crosshair
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        
        let p = convert(event.locationInWindow, from: nil)
        startPoint = p
        lastMouseLocation = p
        
        // Check for handles first
        if !selectionRect.isEmpty {
            if let h = handle(at: p) {
                state = .resizing(h)
                hideToolbar()
                return
            }
            
            if selectionRect.contains(p) {
                state = .moving
                NSCursor.closedHand.set()
                hideToolbar()
                return
            }
        }
        
        // Otherwise start creating
        state = .creating
        selectionRect = .zero
        hideToolbar()
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        let deltaX = p.x - (lastMouseLocation?.x ?? p.x)
        let deltaY = p.y - (lastMouseLocation?.y ?? p.y)
        lastMouseLocation = p
        
        switch state {
        case .creating:
            guard let start = startPoint else { return }
            selectionRect = NSRect(
                x: min(start.x, p.x),
                y: min(start.y, p.y),
                width: abs(p.x - start.x),
                height: abs(p.y - start.y)
            )
            
        case .moving:
            selectionRect.origin.x += deltaX
            selectionRect.origin.y += deltaY
            // Ensure we don't move completely offscreen? 
            // For now, let's allow free movement.
            
        case .resizing(let handle):
            resizeSelection(handle: handle, deltaX: deltaX, deltaY: deltaY)
            
        default:
            break
        }
        
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        if case .creating = state {
             if selectionRect.width > 10 && selectionRect.height > 10 {
                 state = .selected
                 showToolbar()
             } else {
                 state = .idle
                 selectionRect = .zero
             }
        } else {
            // Moving or resizing finished
            state = .selected
            NSCursor.openHand.set()
            showToolbar()
        }
        
        startPoint = nil
        lastMouseLocation = nil
        needsDisplay = true
    }
    
    // MARK: - Logic Helpers
    
    private func resizeSelection(handle: Handle, deltaX: CGFloat, deltaY: CGFloat) {
        var r = selectionRect
        
        // Minimum size to prevent flipping for MVP
        let minSize: CGFloat = 10.0
        
        switch handle {
        case .left:
            let newWidth = r.size.width - deltaX
            if newWidth >= minSize {
                r.origin.x += deltaX
                r.size.width = newWidth
            }
        case .right:
            let newWidth = r.size.width + deltaX
            if newWidth >= minSize {
                r.size.width = newWidth
            }
        case .bottom:
            let newHeight = r.size.height - deltaY
            if newHeight >= minSize {
                r.origin.y += deltaY
                r.size.height = newHeight
            }
        case .top:
            let newHeight = r.size.height + deltaY
            if newHeight >= minSize {
                r.size.height = newHeight
            }
        case .topLeft:
            let newWidth = r.size.width - deltaX
            let newHeight = r.size.height + deltaY
            if newWidth >= minSize {
                r.origin.x += deltaX
                r.size.width = newWidth
            }
            if newHeight >= minSize {
                r.size.height = newHeight
            }
        case .topRight:
            let newWidth = r.size.width + deltaX
            let newHeight = r.size.height + deltaY
            if newWidth >= minSize {
                r.size.width = newWidth
            }
            if newHeight >= minSize {
                r.size.height = newHeight
            }
        case .bottomLeft:
            let newWidth = r.size.width - deltaX
            let newHeight = r.size.height - deltaY
            if newWidth >= minSize {
                r.origin.x += deltaX
                r.size.width = newWidth
            }
            if newHeight >= minSize {
                r.origin.y += deltaY
                r.size.height = newHeight
            }
        case .bottomRight:
            let newWidth = r.size.width + deltaX
            let newHeight = r.size.height - deltaY
            if newWidth >= minSize {
                r.size.width = newWidth
            }
            if newHeight >= minSize {
                r.origin.y += deltaY
                r.size.height = newHeight
            }
        }
        
        selectionRect = r
    }
    
    // MARK: - Keyboard & Toolbar
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            handleCancel()
            return
        }
        
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "q" {
            NSApp.terminate(nil)
            return
        }
        
        // Handle arrow keys if we have a selection
        if !selectionRect.isEmpty {
            let shift = event.modifierFlags.contains(.shift)
            let option = event.modifierFlags.contains(.option)
            let step: CGFloat = shift ? 10.0 : 1.0
            
            var dx: CGFloat = 0
            var dy: CGFloat = 0
            var dWidth: CGFloat = 0
            var dHeight: CGFloat = 0
            var handled = false
            
            // Arrow key codes: Left=123, Right=124, Down=125, Up=126
            if let specialKey = event.specialKey {
                switch specialKey {
                case .leftArrow:
                    if option { dWidth = -step } else { dx = -step }
                    handled = true
                case .rightArrow:
                    if option { dWidth = step } else { dx = step }
                    handled = true
                case .upArrow:
                    if option { dHeight = step } else { dy = step }
                    handled = true
                case .downArrow:
                    if option { dHeight = -step } else { dy = -step }
                    handled = true
                default:
                    break
                }
            }
            
            if handled {
                if option {
                    // Resizing (adjusting width/height from bottom-right implied)
                    var newRect = selectionRect
                    newRect.size.width = max(10, newRect.width + dWidth)
                    newRect.size.height = max(10, newRect.height + dHeight)
                    selectionRect = newRect
                } else {
                    // Moving
                    selectionRect.origin.x += dx
                    selectionRect.origin.y += dy
                }
                
                needsDisplay = true
                showToolbar() // Update toolbar position
                return
            }
        }
        
        super.keyDown(with: event)
    }
    
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
    
    private func hideToolbar() {
        toolbarView?.removeFromSuperview()
        toolbarView = nil
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
            state = .idle
            hideToolbar()
            needsDisplay = true
        } else {
            NotificationCenter.default.post(name: .stopCapture, object: nil)
        }
    }
}
