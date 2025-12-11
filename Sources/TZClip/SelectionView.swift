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

class SelectionView: NSView, AnnotationToolbarDelegate, AnnotationPropertiesDelegate {
    
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
    var isInitialized: Bool = false
    
    // Configuration
    private let handleSize: CGFloat = 8.0
    private let overlayColor = NSColor.black.withAlphaComponent(0.5)
    private let borderColor = NSColor.white
    private let borderWidth: CGFloat = 1.0
    
    private var toolbarView: AnnotationToolbar?
    private var propertiesView: AnnotationPropertiesView?
    private var annotationOverlay: AnnotationOverlayView?
    
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
        
        if case .idle = state, isInitialized {
            if let highlightRect = highlightWindowRect {
                highlightBorderColor.setStroke()
                let path = NSBezierPath(rect: highlightRect)
                path.lineWidth = 2.0
                path.stroke()
            }
        }
        
        if case .idle = state, isInitialized, let p = cursorLocation {
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
        
        if let props = propertiesView, !props.isHidden, NSPointInRect(point, props.frame) {
            return super.hitTest(point)
        }
        
        // Allow interaction with annotation overlay if tool is active
        if let overlay = annotationOverlay, !overlay.isHidden {
            if overlay.currentTool != nil && NSPointInRect(point, overlay.frame) {
                return overlay
            }
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
            if case .idle = state, isInitialized {
                cursorLocation = p
                if !event.modifierFlags.contains(.command), let provider = windowProvider {
                    let globalMouseLocation = NSEvent.mouseLocation
                    if let detected = provider.window(at: globalMouseLocation) {
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
                NSCursor.crosshair.set()
            }
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
            if let highlight = highlightWindowRect, !event.modifierFlags.contains(.command) {
                pendingWindowRect = highlight
            }
        }
        
        // Always start creating initially. 
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
        
        // Update overlay frame if it exists
        if let overlay = annotationOverlay {
            overlay.frame = selectionRect
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        snappedEdges.removeAll()
        
        if case .creating = state {
            if let windowRect = pendingWindowRect {
                // Confirm window selection
                selectionRect = windowRect
                state = .selected
                setupAnnotationOverlay()
                showToolbar()
                pendingWindowRect = nil
            } else if selectionRect.width > 10 && selectionRect.height > 10 {
                 state = .selected
                 setupAnnotationOverlay()
                 showToolbar()
             } else {
                 state = .idle
                 selectionRect = .zero
             }
        } else {
            // Moving or resizing finished
            state = .selected
            NSCursor.openHand.set()
            if let overlay = annotationOverlay {
                overlay.frame = selectionRect
            } else {
                setupAnnotationOverlay()
            }
            showToolbar()
        }
        
        startPoint = nil
        lastMouseLocation = nil
        pendingWindowRect = nil
        needsDisplay = true
    }
    
    private func setupAnnotationOverlay() {
        if annotationOverlay == nil {
            let overlay = AnnotationOverlayView(frame: selectionRect)
            addSubview(overlay)
            annotationOverlay = overlay
        } else {
            annotationOverlay?.frame = selectionRect
            annotationOverlay?.isHidden = false
        }
        
        annotationOverlay?.onSelectionChange = { [weak self] annotation in
            guard let self = self, let props = self.propertiesView else { return }
            if let annot = annotation {
                // Update Properties View with selected annotation properties
                props.selectedColor = annot.color
                props.selectedWidth = annot.lineWidth
                if let textAnnot = annot as? TextAnnotation {
                props.isBold = textAnnot.isBold
                props.outlineStyle = textAnnot.outlineStyle
                props.outlineColor = textAnnot.outlineColor
                props.fontName = textAnnot.fontName
            }
            if let rectAnnot = annot as? RectangleAnnotation {
                    props.isFilled = rectAnnot.isFilled
                    props.isRounded = rectAnnot.isRounded
                }
                if let ellAnnot = annot as? EllipseAnnotation {
                    props.isFilled = ellAnnot.isFilled
                }
                
                // Configure View for Type
                props.configure(for: annot.type)
                
                props.isHidden = false
                
                // Update Layout
                self.updatePropertiesLayout()
            } else {
                // If nothing is selected, hide properties to keep screen clean
                // This applies to all tools (Creation tools included)
                // User can re-enable properties by selecting an item or re-selecting the tool (if implemented),
                // but effectively this supports the "Click Away -> Done" workflow.
                props.isHidden = true
            }
        }
        
        annotationOverlay?.onToolChange = { [weak self] tool in
            guard let self = self, let toolbar = self.toolbarView else { return }
            toolbar.selectTool(tool)
            self.didSelectTool(tool)
        }
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
        
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "z" {
            annotationOverlay?.undo()
            return
        }
        
        if (event.keyCode == 51 || event.keyCode == 117) { // Delete or Backspace
            annotationOverlay?.deleteSelected()
            
            // If toolbar was showing properties for the deleted item, hide them
            // deleteSelected will trigger onSelectionChange(nil) which handles hiding properties
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
                if let overlay = annotationOverlay {
                    overlay.frame = selectionRect
                }
                showToolbar() // Update toolbar position
                return
            }
        }
        
        super.keyDown(with: event)
    }
    
    private func showToolbar() {
        hideToolbar() // Clear existing
        
        // 1. Create Main Toolbar
        let toolbar = AnnotationToolbar(frame: .zero)
        toolbar.delegate = self
        self.addSubview(toolbar)
        self.toolbarView = toolbar
        
        // 2. Create Properties View
        let props = AnnotationPropertiesView(frame: .zero)
        props.delegate = self
        self.addSubview(props)
        self.propertiesView = props
        
        // Initially hidden, waiting for tool selection
        props.isHidden = true
        
        // Layout
        let toolbarSize = toolbar.frame.size
        let propsSize = props.frame.size
        let padding: CGFloat = 8
        
        // Default Toolbar X: Bottom Right of selection, constrained
        var toolbarX = selectionRect.maxX - toolbarSize.width
        toolbarX = max(padding, toolbarX)
        toolbarX = min(bounds.width - toolbarSize.width - padding, toolbarX)
        
        // Default Toolbar Y: Below selection
        var toolbarY = selectionRect.minY - padding - toolbarSize.height
        
        // Check if enough space below
        let spaceBelow = selectionRect.minY
        let spaceAbove = self.bounds.height - selectionRect.maxY
        
        var isToolbarBelow = true
        
        if spaceBelow < (toolbarSize.height + padding + propsSize.height + padding) {
            // Not enough space below for both? Try above
            if spaceAbove > (toolbarSize.height + padding + propsSize.height + padding) {
                // Put above
                toolbarY = selectionRect.maxY + padding
                isToolbarBelow = false
            } else {
                // Not enough space above either? Clamp to screen bottom
                // If constrained to bottom, we might cover selection
                if toolbarY < padding {
                    toolbarY = padding
                    isToolbarBelow = true // Technically at bottom
                }
            }
        }
        
        toolbar.frame.origin = NSPoint(x: toolbarX, y: toolbarY)
        
        // Properties View Layout
        // If Toolbar is Below, Props is Below Toolbar
        // If Toolbar is Above, Props is Above Toolbar
        // Wait, usually Props is secondary, so maybe stack them nicely.
        // Let's stack them vertically aligned left to the toolbar? Or same alignment?
        
        var propsX = toolbarX
        propsX = min(bounds.width - propsSize.width - padding, max(padding, propsX))
        var propsY: CGFloat = 0
        
        if isToolbarBelow {
            propsY = toolbarY - padding - propsSize.height
        } else {
            propsY = toolbarY + toolbarSize.height + padding
        }
        
        props.frame.origin = NSPoint(x: propsX, y: propsY)
    }
    
    private func hideToolbar() {
        toolbarView?.removeFromSuperview()
        toolbarView = nil
        propertiesView?.removeFromSuperview()
        propertiesView = nil
    }
    
    private func handleCancel() {
        if let overlay = annotationOverlay, !overlay.isHidden {
            // Check if we have annotations to clear?
            // Or just cancel the whole selection?
            // User pressed Esc.
            // If drawing, maybe cancel drawing?
            // For now, cancel selection.
        }
        
        if !selectionRect.isEmpty {
            selectionRect = .zero
            state = .idle
            hideToolbar()
            annotationOverlay?.isHidden = true
            annotationOverlay?.clear()
            needsDisplay = true
        } else {
            NotificationCenter.default.post(name: .stopCapture, object: nil)
        }
    }
    
    // MARK: - AnnotationToolbarDelegate
    
    func didSelectTool(_ tool: AnnotationType) {
        annotationOverlay?.currentTool = tool
        
        // Configure properties view based on selected tool
        propertiesView?.configure(for: tool)
        
        // Sync properties from overlay (which now stores per-tool config)
        if let overlay = annotationOverlay {
            propertiesView?.selectedColor = overlay.currentColor
            propertiesView?.selectedWidth = overlay.currentLineWidth
            if tool == .text || tool == .counter {
                propertiesView?.isBold = overlay.currentIsBold
                propertiesView?.outlineStyle = overlay.currentOutlineStyle
                propertiesView?.outlineColor = overlay.currentOutlineColor
                propertiesView?.fontName = overlay.currentFontName
            }
        if tool == .rectangle {
                propertiesView?.isRounded = overlay.currentIsRounded
            }
            propertiesView?.isFilled = overlay.currentIsFilled
        }
        
        // Only show properties view if tool is NOT .select, unless we have a selection
        if tool == .select {
            propertiesView?.isHidden = !(annotationOverlay?.hasSelection ?? false)
        } else {
            propertiesView?.isHidden = false
        }
        
        // Update Layout if size changed
        updatePropertiesLayout()
    }
    
    func didSelectAction(_ action: ToolbarAction) {
        switch action {
        case .undo:
            annotationOverlay?.undo()
        case .close:
            handleCancel()
        case .save:
            guard let image = generateFinalImage() else { return }
            saveImageToFile(image)
        case .copy:
            guard let image = generateFinalImage() else { return }
            copyImageToClipboard(image)
            // Feedback?
            NotificationCenter.default.post(name: .stopCapture, object: nil)
        }
    }
    
    // MARK: - Image Generation & Output
    
    func generateFinalImage() -> NSImage? {
        guard !selectionRect.isEmpty, let window = self.window else { return nil }
        
        // 1. Capture the screen content below our window
        // Convert selectionRect to Screen Coordinates (Cocoa)
        var screenRect = window.convertToScreen(selectionRect)
        
        // Convert to Quartz Coordinates (Top-Left origin)
        // Assume screen 0 is the "main" screen for height reference, but actually
        // CGWindowListCreateImage coordinates are relative to the unified display space.
        // NSScreen.screens.first is usually the one with (0,0).
        // A robust way involves flipping Y based on the primary screen height.
        
        guard let primaryScreen = NSScreen.screens.first else { return nil }
        let primaryHeight = primaryScreen.frame.height
        
        // Quartz Y = PrimaryHeight - (CocoaY + Height)
        let quartzY = primaryHeight - (screenRect.origin.y + screenRect.height)
        let captureRect = CGRect(x: screenRect.origin.x, y: quartzY, width: screenRect.width, height: screenRect.height)
        
        // Capture
        guard let cgImage = CGWindowListCreateImage(
            captureRect,
            .optionOnScreenBelowWindow,
            CGWindowID(window.windowNumber),
            .bestResolution
        ) else {
            print("Failed to capture screen image")
            return nil
        }
        
        // 2. Create Final Image
        // We will combine the captured image and annotations into a new NSImage.
        
        let finalImage = NSImage(size: selectionRect.size)
        finalImage.lockFocus()
        
        // Draw Base Image
        // We need to draw the CGImage. NSImage(cgImage:...)
        let baseNSImage = NSImage(cgImage: cgImage, size: selectionRect.size)
        baseNSImage.draw(in: NSRect(origin: .zero, size: selectionRect.size),
                         from: NSRect(origin: .zero, size: selectionRect.size),
                         operation: .copy,
                         fraction: 1.0)
        
        // Draw Annotations
        // We can get the current context (which is the NSImage context)
        if let ctx = NSGraphicsContext.current?.cgContext {
            annotationOverlay?.renderAnnotations(in: ctx)
        }
        
        finalImage.unlockFocus()
        
        return finalImage
    }
    
    func copyImageToClipboard(_ image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }
    
    func saveImageToFile(_ image: NSImage) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png, .jpeg]
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = "Screenshot \(Date().formatted(date: .numeric, time: .standard)).png"
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: ".")
        
        // We need to present this. Since we are in a window controller/view...
        // But our window is level .screenSaver, save panel might be hidden behind?
        // We should temporarily elevate or hide our window?
        // Actually, saving usually implies we are done.
        // But the user might want to save and CONTINUE?
        // "Confirm" (Copy) exits. "Save" might also exit?
        // Standard behavior: Save -> Dialog -> Save -> Exit.
        
        // Let's hide our window temporarily for the save panel?
        // Or ensure save panel is above.
        savePanel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)) + 1)
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                if let tiffData = image.tiffRepresentation,
                   let bitmapRep = NSBitmapImageRep(data: tiffData) {
                    
                    let props: [NSBitmapImageRep.PropertyKey: Any] = [:]
                    // Determine type based on extension
                    let fileType: NSBitmapImageRep.FileType = url.pathExtension.lowercased() == "jpg" ? .jpeg : .png
                    
                    if let data = bitmapRep.representation(using: fileType, properties: props) {
                        try? data.write(to: url)
                    }
                }
                // Exit after save
                NotificationCenter.default.post(name: .stopCapture, object: nil)
            }
        }
    }
    
    // MARK: - AnnotationPropertiesDelegate
    
    func didChangeColor(_ color: NSColor) {
        annotationOverlay?.currentColor = color
    }
    
    func didChangeLineWidth(_ width: CGFloat) {
        annotationOverlay?.currentLineWidth = width
    }
    
    func didChangeIsBold(_ isBold: Bool) {
        annotationOverlay?.currentIsBold = isBold
    }
    
    func didChangeIsFilled(_ isFilled: Bool) {
        annotationOverlay?.currentIsFilled = isFilled
    }
    
    func didChangeIsRounded(_ isRounded: Bool) {
        annotationOverlay?.currentIsRounded = isRounded
    }
    
    func didChangeOutlineStyle(_ style: Int) {
        annotationOverlay?.currentOutlineStyle = style
    }
    
    func didChangeOutlineColor(_ color: NSColor) {
        annotationOverlay?.currentOutlineColor = color
    }
    
    func didChangeFontName(_ name: String) {
        annotationOverlay?.currentFontName = name
    }

    func didChangeTextBackgroundColor(_ color: NSColor?) {
        annotationOverlay?.currentTextBackgroundColor = color
    }
    
    // Helper to update layout
    func updatePropertiesLayout() {
        guard let toolbar = toolbarView, let props = propertiesView else { return }
        
        let propsSize = props.frame.size
        let padding: CGFloat = 8
        
        // Re-evaluate propsY
        let toolbarY = toolbar.frame.minY
        
        // If toolbar is near bottom (toolbarY is small), props should be above
        // We previously calculated this in showToolbar.
        // Let's just re-use the relative positioning logic.
        
        // Simple heuristic: if toolbarY < propsSize.height + padding, place above toolbar
        var propsY: CGFloat
        if toolbarY < (propsSize.height + padding) {
             propsY = toolbar.frame.maxY + padding
        } else {
             propsY = toolbarY - padding - propsSize.height
        }
        
        // Ensure properties view doesn't go below screen bounds
        if propsY < 0 {
            // If it would go off-screen bottom, force it above toolbar
            propsY = toolbar.frame.maxY + padding
        }
        
        var finalX = toolbar.frame.minX
        finalX = min(bounds.width - propsSize.width - padding, max(padding, finalX))
        props.frame.origin = NSPoint(x: finalX, y: propsY)
    }
}
