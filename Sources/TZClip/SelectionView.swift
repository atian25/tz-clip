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
    
    // Snapping
    private var snappedEdges: Set<Int> = [] // 0:minX, 1:maxX, 2:minY, 3:maxY
    private let snapThreshold: CGFloat = 10.0
    
    // Window Detection
    var windowProvider: WindowInfoProvider?
    private var highlightWindowRect: NSRect?
    private var pendingWindowRect: NSRect? // For hybrid mode click-to-select
    private let highlightColor = NSColor.systemBlue.withAlphaComponent(0.2)
    private let highlightBorderColor = NSColor.systemBlue
    
    // Crosshair
    private var cursorLocation: NSPoint?
    
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
    
    // Allow the view to handle mouse events immediately, even if the window is not key
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
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
        
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .mouseMoved, .activeAlways]
        trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }
    
    // MARK: - Drawing
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Draw Overlay
        // Removed semi-transparent background as per user request
        // overlayColor.setFill()
        // dirtyRect.fill()
        
        // Draw Window Highlight if idle and present
        if case .idle = state {
            // DEBUG: Draw ALL detected windows to check coordinates
            /*
            if let provider = windowProvider, let window = self.window {
                NSColor.red.withAlphaComponent(0.5).setStroke() // 增加透明度以便看清
                for w in provider.allWindows() {
                     let r = window.convertFromScreen(w.frame)
                     let path = NSBezierPath(rect: r)
                     path.lineWidth = 1.0
                     path.stroke()
                }
            }
            */
            
            if let highlightRect = highlightWindowRect {
                highlightBorderColor.setStroke()
                let path = NSBezierPath(rect: highlightRect)
                path.lineWidth = 2.0
                path.stroke()
            }
        }
        
        // Draw Crosshair if idle
        if case .idle = state, let p = cursorLocation {
            drawCrosshair(at: p)
        }
        
        if !selectionRect.isEmpty {
            // Draw Border
            borderColor.setStroke()
            let path = NSBezierPath(rect: selectionRect)
            path.lineWidth = borderWidth
            path.stroke()
            
            // Draw Snap Guides
            drawSnapGuides()
            
            // Draw Handles if selected or moving/resizing
            // Only hide handles when we are creating a NEW selection
            if case .creating = state {
                // Don't draw handles
            } else {
                drawHandles()
            }
            
            // Draw Size Indicator
            drawSizeIndicator()
        }
    }
    
    private func drawCrosshair(at point: NSPoint) {
        let color = NSColor.white.withAlphaComponent(0.3)
        color.setStroke()
        let path = NSBezierPath()
        path.lineWidth = 1.0
        
        // Horizontal
        path.move(to: NSPoint(x: bounds.minX, y: point.y))
        path.line(to: NSPoint(x: bounds.maxX, y: point.y))
        
        // Vertical
        path.move(to: NSPoint(x: point.x, y: bounds.minY))
        path.line(to: NSPoint(x: point.x, y: bounds.maxY))
        
        path.stroke()
    }
    
    private func drawHandles() {
        NSColor.white.setFill()
        for handle in Handle.allCases {
            let rect = rectForHandle(handle)
            let path = NSBezierPath(ovalIn: rect)
            path.fill()
        }
    }
    
    private func drawSnapGuides() {
        guard !snappedEdges.isEmpty else { return }
        
        let guideColor = NSColor.systemYellow
        guideColor.setStroke()
        let path = NSBezierPath()
        path.lineWidth = 1.0
        // Dashed line pattern
        path.setLineDash([4.0, 2.0], count: 2, phase: 0)
        
        if snappedEdges.contains(0) { // minX
            path.move(to: NSPoint(x: selectionRect.minX, y: bounds.minY))
            path.line(to: NSPoint(x: selectionRect.minX, y: bounds.maxY))
        }
        if snappedEdges.contains(1) { // maxX
            path.move(to: NSPoint(x: selectionRect.maxX, y: bounds.minY))
            path.line(to: NSPoint(x: selectionRect.maxX, y: bounds.maxY))
        }
        if snappedEdges.contains(2) { // minY
            path.move(to: NSPoint(x: bounds.minX, y: selectionRect.minY))
            path.line(to: NSPoint(x: bounds.maxX, y: selectionRect.minY))
        }
        if snappedEdges.contains(3) { // maxY
            path.move(to: NSPoint(x: bounds.minX, y: selectionRect.maxY))
            path.line(to: NSPoint(x: bounds.maxX, y: selectionRect.maxY))
        }
        
        path.stroke()
    }
    
    private func drawSizeIndicator() {
        let width = Int(round(selectionRect.width))
        let height = Int(round(selectionRect.height))
        let text = "\(width) × \(height)"
        
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let size = text.size(withAttributes: attrs)
        
        let padding: CGFloat = 4
        let bgRectSize = NSSize(width: size.width + padding * 2, height: size.height + padding * 2)
        
        // Default position: Top-Left, slightly above
        var origin = NSPoint(x: selectionRect.minX, y: selectionRect.maxY + 6)
        
        // 1. If out of bounds top, move inside top-left
        if origin.y + bgRectSize.height > bounds.maxY {
            origin.y = selectionRect.maxY - bgRectSize.height - 6
        }
        
        // 2. Ensure x is within bounds
        if origin.x < bounds.minX {
            origin.x = bounds.minX + 4
        }
        if origin.x + bgRectSize.width > bounds.maxX {
            origin.x = bounds.maxX - bgRectSize.width - 4
        }
        
        let bgRect = NSRect(origin: origin, size: bgRectSize)
        
        NSGraphicsContext.saveGraphicsState()
        let path = NSBezierPath(roundedRect: bgRect, xRadius: 4, yRadius: 4)
        NSColor.black.withAlphaComponent(0.7).setFill()
        path.fill()
        NSGraphicsContext.restoreGraphicsState()
        
        let textPoint = NSPoint(x: origin.x + padding, y: origin.y + padding)
        text.draw(at: textPoint, withAttributes: attrs)
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
            // 如果在 idle 状态
            if case .idle = state {
                cursorLocation = p
                
                // Window Detection
                // Disable if Command key is pressed
                if !event.modifierFlags.contains(.command), let provider = windowProvider {
                    // Convert view point to screen point for hit testing
                    // window?.convertPoint(toScreen: p) // 10.12+
                    // Since OverlayWindow fills the screen, we can use NSEvent.mouseLocation or convert manually
                    // But NSEvent.mouseLocation is global.
                    
                    let globalMouseLocation = NSEvent.mouseLocation
                    if let detected = provider.window(at: globalMouseLocation) {
                        // Convert detected global rect to view local rect
                        if let window = self.window {
                            highlightWindowRect = window.convertFromScreen(detected.frame)
                        }
                    } else {
                        highlightWindowRect = nil
                    }
                } else {
                    highlightWindowRect = nil
                }
                
                needsDisplay = true
            }
            NSCursor.crosshair.set()
            return
        }
        
        // 既然 selectionRect 不为空，说明已经有选区了，清空 cursorLocation 和 highlight
        cursorLocation = nil
        highlightWindowRect = nil
        
        if let h = handle(at: p) {
            cursorForHandle(h).set()
        } else if selectionRect.contains(p) {
            NSCursor.openHand.set()
        } else {
            NSCursor.crosshair.set()
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        cursorLocation = nil
        needsDisplay = true
        super.mouseExited(with: event)
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
        } else {
            // Check for Window Selection (Hybrid Mode)
            // If we have a highlighted window, we MIGHT select it if this is a click,
            // or we MIGHT ignore it if this becomes a drag.
            if let highlight = highlightWindowRect, !event.modifierFlags.contains(.command) {
                pendingWindowRect = highlight
            }
        }
        
        // Always start creating initially. 
        // If it's a click on a window, mouseUp will handle it.
        // If it's a drag, mouseDragged will handle it (and clear pendingWindowRect).
        state = .creating
        selectionRect = .zero
        cursorLocation = nil // Stop showing crosshair
        highlightWindowRect = nil // Stop showing highlight
        hideToolbar()
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        let deltaX = p.x - (lastMouseLocation?.x ?? p.x)
        let deltaY = p.y - (lastMouseLocation?.y ?? p.y)
        lastMouseLocation = p
        
        // If we are dragging significantly, cancel any pending window selection
        if pendingWindowRect != nil {
            if let start = startPoint {
                let dragDist = hypot(p.x - start.x, p.y - start.y)
                if dragDist > 3.0 {
                    pendingWindowRect = nil
                }
            }
        }
        
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
            
        case .resizing(let handle):
            resizeSelection(handle: handle, deltaX: deltaX, deltaY: deltaY)
            
        default:
            break
        }
        
        // Apply Snapping (unless Command is pressed)
        if !event.modifierFlags.contains(.command) {
            selectionRect = applySnapping(to: selectionRect)
        } else {
            snappedEdges.removeAll()
        }
        
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        snappedEdges.removeAll()
        
        if case .creating = state {
            if let windowRect = pendingWindowRect {
                // Confirm window selection
                selectionRect = windowRect
                state = .selected
                showToolbar()
                pendingWindowRect = nil
            } else if selectionRect.width > 10 && selectionRect.height > 10 {
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
        pendingWindowRect = nil
        needsDisplay = true
    }
    
    // MARK: - Logic Helpers
    
    private func applySnapping(to rect: NSRect) -> NSRect {
        var r = rect
        var edges: Set<Int> = []
        
        // Snap to Screen Edges
        
        // MinX (Left)
        if abs(r.minX - bounds.minX) < snapThreshold {
            r.origin.x = bounds.minX
            edges.insert(0)
        }
        // MaxX (Right)
        else if abs(r.maxX - bounds.maxX) < snapThreshold {
            r.origin.x = bounds.maxX - r.width
            edges.insert(1)
        }
        
        // MinY (Bottom in macOS coords, visual bottom)
        if abs(r.minY - bounds.minY) < snapThreshold {
            r.origin.y = bounds.minY
            edges.insert(2)
        }
        // MaxY (Top)
        else if abs(r.maxY - bounds.maxY) < snapThreshold {
            r.origin.y = bounds.maxY - r.height
            edges.insert(3)
        }
        
        snappedEdges = edges
        return r
    }
    
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
