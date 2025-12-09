import Cocoa

class AnnotationOverlayView: NSView {
    
    // MARK: - Enums
    
    enum DragAction: Equatable {
        case none
        case creating
        case moving
        case resizing(handle: ResizeHandle)
    }
    
    enum ResizeHandle: CaseIterable {
        case topLeft, top, topRight
        case right
        case bottomRight, bottom, bottomLeft
        case left
        case start, end // For Line/Arrow
    }
    
    // MARK: - Properties
    
    // Independent Tool Configuration
    private struct ToolConfig {
        var color: NSColor = .red
        var lineWidth: CGFloat = 4.0
        var isBold: Bool = false
        var isFilled: Bool = false
        var isRounded: Bool = false
    }
    
    private var toolConfigs: [AnnotationType: ToolConfig] = [:]
    
    // Helper to get/set config for current tool
    private var currentConfig: ToolConfig {
        get {
            guard let tool = currentTool else { return ToolConfig() }
            return toolConfigs[tool] ?? ToolConfig()
        }
        set {
            guard let tool = currentTool else { return }
            toolConfigs[tool] = newValue
        }
    }
    
    var currentTool: AnnotationType? {
        didSet {
            window?.invalidateCursorRects(for: self)
            
            // If we switch tools (or cancel), we must end any active text editing session.
            if let _ = activeTextView {
                endTextEditing()
            }
            
            if currentTool != .select {
                selectedAnnotationID = nil
                // Notify tool change to update properties view with new tool's config
                // Wait, onToolChange usually comes FROM toolbar.
                // If we set tool here, we should notify properties view.
                // The delegate flow is: Toolbar -> SelectionView -> Overlay -> SelectionView -> PropertiesView
                // But we need to sync the Overlay's stored config to the Properties View.
                
                // Let's rely on SelectionView asking us or we notify SelectionView via a new callback?
                // Or easier: SelectionView calls `annotationOverlay.currentConfig`?
                
                // Better: When tool changes, we fire a callback that includes the config?
                // `onToolChange` is used to tell Toolbar to highlight button.
                // We might need `onConfigChange`?
                
                // Actually, SelectionView.didSelectTool sets overlay.currentTool
                // Then it calls propertiesView.configure(for: tool).
                // It SHOULD also set propertiesView values from overlay.
            }
        }
    }
    
    var currentColor: NSColor {
        get { currentConfig.color }
        set {
            if currentTool != .select {
                currentConfig.color = newValue
            }
            // Also update selected annotation if any
            if let id = selectedAnnotationID, let index = annotations.firstIndex(where: { $0.id == id }) {
                annotations[index].color = newValue
                needsDisplay = true
            }
        }
    }
    
    var currentLineWidth: CGFloat {
        get { currentConfig.lineWidth }
        set {
            if currentTool != .select {
                currentConfig.lineWidth = newValue
            }
            if let id = selectedAnnotationID, let index = annotations.firstIndex(where: { $0.id == id }) {
                annotations[index].lineWidth = newValue
                needsDisplay = true
            }
        }
    }
    
    var currentIsBold: Bool {
        get { currentConfig.isBold }
        set {
            if currentTool != .select {
                currentConfig.isBold = newValue
            }
            if let id = selectedAnnotationID, let index = annotations.firstIndex(where: { $0.id == id }) {
                if var textAnnot = annotations[index] as? TextAnnotation {
                    textAnnot.isBold = newValue
                    annotations[index] = textAnnot
                    needsDisplay = true
                }
            }
        }
    }
    
    var currentIsFilled: Bool {
        get { currentConfig.isFilled }
        set {
            if currentTool != .select {
                currentConfig.isFilled = newValue
            }
            if let id = selectedAnnotationID, let index = annotations.firstIndex(where: { $0.id == id }) {
                if var rectAnnot = annotations[index] as? RectangleAnnotation {
                    rectAnnot.isFilled = newValue
                    annotations[index] = rectAnnot
                    needsDisplay = true
                } else if var ellAnnot = annotations[index] as? EllipseAnnotation {
                    ellAnnot.isFilled = newValue
                    annotations[index] = ellAnnot
                    needsDisplay = true
                }
            }
        }
    }
    
    var currentIsRounded: Bool {
        get { currentConfig.isRounded }
        set {
            if currentTool != .select {
                currentConfig.isRounded = newValue
            }
            if let id = selectedAnnotationID, let index = annotations.firstIndex(where: { $0.id == id }) {
                if var rectAnnot = annotations[index] as? RectangleAnnotation {
                    rectAnnot.isRounded = newValue
                    annotations[index] = rectAnnot
                    needsDisplay = true
                }
            }
        }
    }
    
    var onSelectionChange: ((Annotation?) -> Void)?
    
    var onToolChange: ((AnnotationType) -> Void)?
    
    var hasSelection: Bool { selectedAnnotationID != nil }
    
    private var annotations: [Annotation] = []
    private var currentAnnotation: Annotation?
    private var selectedAnnotationID: UUID? {
        didSet {
            needsDisplay = true
            if let id = selectedAnnotationID, let annotation = annotations.first(where: { $0.id == id }) {
                onSelectionChange?(annotation)
            } else {
                onSelectionChange?(nil)
            }
        }
    }
    
    private var dragStartPoint: CGPoint?
    private var dragAction: DragAction = .none
    
    // Text Editing
    private var activeTextView: NSTextView?
    
    // MARK: - Init
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
        self.layer?.masksToBounds = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Drawing
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // Draw all committed annotations
        for annotation in annotations {
            annotation.draw(in: context)
        }
        
        // Draw current annotation being created
        currentAnnotation?.draw(in: context)
        
        // Draw selection highlight and handles
        if let id = selectedAnnotationID, let annotation = annotations.first(where: { $0.id == id }) {
            drawSelection(for: annotation, in: context)
        }
    }
    
    private func drawSelection(for annotation: Annotation, in context: CGContext) {
        context.saveGState()
        
        // Draw bounding box
        context.setStrokeColor(NSColor.selectedControlColor.cgColor)
        context.setLineWidth(1.0)
        let bounds = annotation.bounds
        context.stroke(bounds)
        
        // Draw handles
        context.setFillColor(NSColor.white.cgColor)
        context.setStrokeColor(NSColor.selectedControlColor.cgColor)
        
        let handles = getHandleRects(for: annotation)
        for (_, rect) in handles {
            context.fill(rect)
            context.stroke(rect)
        }
        
        context.restoreGState()
    }
    
    private func getHandleRects(for annotation: Annotation) -> [ResizeHandle: CGRect] {
        var handles: [ResizeHandle: CGRect] = [:]
        let handleSize: CGFloat = 8
        let half = handleSize / 2
        
        if annotation.type == .line || annotation.type == .arrow {
            if let line = annotation as? LineAnnotation {
                handles[.start] = CGRect(x: line.startPoint.x - half, y: line.startPoint.y - half, width: handleSize, height: handleSize)
                handles[.end] = CGRect(x: line.endPoint.x - half, y: line.endPoint.y - half, width: handleSize, height: handleSize)
            } else if let arrow = annotation as? ArrowAnnotation {
                handles[.start] = CGRect(x: arrow.startPoint.x - half, y: arrow.startPoint.y - half, width: handleSize, height: handleSize)
                handles[.end] = CGRect(x: arrow.endPoint.x - half, y: arrow.endPoint.y - half, width: handleSize, height: handleSize)
            }
        } else if annotation.type == .pen || annotation.type == .text {
             // Pen and Text: only bounds handles (corners)
             // For simplicity, Pen/Text just 4 corners?
             // Let's do 4 corners for now.
            let b = annotation.bounds
            handles[.topLeft] = CGRect(x: b.minX - half, y: b.minY - half, width: handleSize, height: handleSize)
            handles[.topRight] = CGRect(x: b.maxX - half, y: b.minY - half, width: handleSize, height: handleSize)
            handles[.bottomLeft] = CGRect(x: b.minX - half, y: b.maxY - half, width: handleSize, height: handleSize)
            handles[.bottomRight] = CGRect(x: b.maxX - half, y: b.maxY - half, width: handleSize, height: handleSize)
        } else {
            // Rect / Ellipse: 8 handles
            let b = annotation.bounds
            handles[.topLeft] = CGRect(x: b.minX - half, y: b.minY - half, width: handleSize, height: handleSize)
            handles[.top] = CGRect(x: b.midX - half, y: b.minY - half, width: handleSize, height: handleSize)
            handles[.topRight] = CGRect(x: b.maxX - half, y: b.minY - half, width: handleSize, height: handleSize)
            handles[.right] = CGRect(x: b.maxX - half, y: b.midY - half, width: handleSize, height: handleSize)
            handles[.bottomRight] = CGRect(x: b.maxX - half, y: b.maxY - half, width: handleSize, height: handleSize)
            handles[.bottom] = CGRect(x: b.midX - half, y: b.maxY - half, width: handleSize, height: handleSize)
            handles[.bottomLeft] = CGRect(x: b.minX - half, y: b.maxY - half, width: handleSize, height: handleSize)
            handles[.left] = CGRect(x: b.minX - half, y: b.midY - half, width: handleSize, height: handleSize)
        }
        
        return handles
    }
    
    // MARK: - Public Methods
    
    /// Renders only the committed annotations into the provided context.
    /// Used for generating the final output image.
    func renderAnnotations(in context: CGContext) {
        context.saveGState()
        // Ensure we are drawing in the view's coordinate system if needed,
        // but typically the context passed in will be set up for the image size.
        // Since annotations store coordinates relative to the view/window (which matches selection rect),
        // we should be fine if the context represents the selection rect.
        
        for annotation in annotations {
            annotation.draw(in: context)
        }
        context.restoreGState()
    }
    
    func undo() {
        if !annotations.isEmpty {
            annotations.removeLast()
            needsDisplay = true
        }
    }
    
    func deleteSelected() {
        if let id = selectedAnnotationID {
            annotations.removeAll(where: { $0.id == id })
            selectedAnnotationID = nil
            needsDisplay = true
        }
    }
    
    func clear() {
        annotations.removeAll()
        currentAnnotation = nil
        selectedAnnotationID = nil
        needsDisplay = true
    }
    
    override func resetCursorRects() {
        if let tool = currentTool, tool != .select {
            addCursorRect(bounds, cursor: .crosshair)
        } else {
            super.resetCursorRects()
            // Add cursor rects for handles if selected
            if let id = selectedAnnotationID, let annotation = annotations.first(where: { $0.id == id }) {
                let handles = getHandleRects(for: annotation)
                for (_, rect) in handles {
                    // Logic to choose cursor based on handle position
                    addCursorRect(rect, cursor: .pointingHand) // Simplified
                }
            }
        }
    }
    
    // MARK: - Mouse Events
    
    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        dragStartPoint = p
        
        // Handle Text Creation
        if currentTool == .text {
            startTextEditing(at: p)
            return
        }
        
        // 1. Check Handles of selected annotation (Priority 1)
        if let id = selectedAnnotationID, let annotation = annotations.first(where: { $0.id == id }) {
            let handles = getHandleRects(for: annotation)
            for (handle, rect) in handles {
                if rect.contains(p) {
                    dragAction = .resizing(handle: handle)
                    return
                }
            }
            
            // 2. Check Body of selected annotation (Priority 2) - Allow moving current selection
            if annotation.contains(point: p) {
                dragAction = .moving
                return
            }
        }
        
        // 3. Check Body of ANY annotation (Priority 3) - Select on click
        // Even if creating, if we click exactly on an existing annotation, we select it.
        if let index = annotations.lastIndex(where: { $0.contains(point: p) }) {
            let annot = annotations[index]
            selectedAnnotationID = annot.id
            dragAction = .moving
            
            // Switch tool to Select
            if currentTool != .select {
                currentTool = .select
                onToolChange?(.select)
            }
            
            // Update properties to match selected
            self.currentColor = annot.color
            self.currentLineWidth = annot.lineWidth
            if let textAnnot = annot as? TextAnnotation {
                self.currentIsBold = textAnnot.isBold
            }
            
            needsDisplay = true
            return
        }
        
        // 4. Creation Mode (Priority 4)
        if currentTool != .select && currentTool != nil {
             // Deselect current if starting new creation
             selectedAnnotationID = nil
             dragAction = .creating
             
             switch currentTool {
             case .rectangle:
                 currentAnnotation = RectangleAnnotation(rect: CGRect(origin: p, size: .zero), color: currentColor, lineWidth: currentLineWidth, isFilled: currentIsFilled, isRounded: currentIsRounded)
             case .ellipse:
                 currentAnnotation = EllipseAnnotation(rect: CGRect(origin: p, size: .zero), color: currentColor, lineWidth: currentLineWidth, isFilled: currentIsFilled)
             case .arrow:
                  currentAnnotation = ArrowAnnotation(startPoint: p, endPoint: p, color: currentColor, lineWidth: currentLineWidth)
             case .line:
                 currentAnnotation = LineAnnotation(startPoint: p, endPoint: p, color: currentColor, lineWidth: currentLineWidth)
             case .pen:
                 currentAnnotation = PenAnnotation(points: [p], color: currentColor, lineWidth: currentLineWidth)
             default:
                 break
             }
             
             needsDisplay = true
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        
        if dragAction == .creating {
            guard let start = dragStartPoint, var annot = currentAnnotation else { return }
            
            // Handle Shift Key constraints
            let isShift = event.modifierFlags.contains(.shift)
            
            switch annot.type {
            case .rectangle, .ellipse:
                var w = p.x - start.x
                var h = p.y - start.y
                if isShift {
                    let s = max(abs(w), abs(h))
                    w = w < 0 ? -s : s
                    h = h < 0 ? -s : s
                }
                let rect = CGRect(x: min(start.x, start.x + w), y: min(start.y, start.y + h), width: abs(w), height: abs(h))
                
                if var r = annot as? RectangleAnnotation { r.rect = rect; currentAnnotation = r }
                if var e = annot as? EllipseAnnotation { e.rect = rect; currentAnnotation = e }
                
            case .line, .arrow:
                var end = p
                if isShift {
                    // Snap to 45 degrees
                    let dx = end.x - start.x
                    let dy = end.y - start.y
                    let angle = atan2(dy, dx)
                    let snappedAngle = round(angle / (.pi / 4)) * (.pi / 4)
                    let dist = hypot(dx, dy)
                    end = CGPoint(x: start.x + dist * cos(snappedAngle), y: start.y + dist * sin(snappedAngle))
                }
                
                if var l = annot as? LineAnnotation { l.endPoint = end; currentAnnotation = l }
                if var a = annot as? ArrowAnnotation { a.endPoint = end; currentAnnotation = a }
                
            case .pen:
                if var pen = annot as? PenAnnotation {
                    pen.points.append(p)
                    currentAnnotation = pen
                }
            default: break
            }
            needsDisplay = true
        } else if dragAction == .moving {
            guard let start = dragStartPoint, let id = selectedAnnotationID, let index = annotations.firstIndex(where: { $0.id == id }) else { return }
            let delta = CGPoint(x: p.x - start.x, y: p.y - start.y)
            annotations[index] = annotations[index].move(by: delta)
            dragStartPoint = p // Reset start point for incremental move
            needsDisplay = true
        } else if case .resizing(let handle) = dragAction {
            // Resize logic
            guard let id = selectedAnnotationID, let index = annotations.firstIndex(where: { $0.id == id }) else { return }
            var annot = annotations[index]
            let isShift = event.modifierFlags.contains(.shift)
            
            if var rectAnnot = annot as? RectangleAnnotation {
                rectAnnot.rect = resizeRect(rectAnnot.rect, handle: handle, to: p, maintainAspectRatio: isShift)
                annot = rectAnnot
            } else if var ellAnnot = annot as? EllipseAnnotation {
                ellAnnot.rect = resizeRect(ellAnnot.rect, handle: handle, to: p, maintainAspectRatio: isShift)
                annot = ellAnnot
            } else if var lineAnnot = annot as? LineAnnotation {
                var p = p
                if isShift {
                    // Snap to 45 degrees relative to startPoint or endPoint
                    let fixedPoint = (handle == .start) ? lineAnnot.endPoint : lineAnnot.startPoint
                    let dx = p.x - fixedPoint.x
                    let dy = p.y - fixedPoint.y
                    let angle = atan2(dy, dx)
                    let snappedAngle = round(angle / (.pi / 4)) * (.pi / 4)
                    let dist = hypot(dx, dy)
                    p = CGPoint(x: fixedPoint.x + dist * cos(snappedAngle), y: fixedPoint.y + dist * sin(snappedAngle))
                }
                
                if handle == .start { lineAnnot.startPoint = p }
                if handle == .end { lineAnnot.endPoint = p }
                annot = lineAnnot
            } else if var arrowAnnot = annot as? ArrowAnnotation {
                var p = p
                if isShift {
                     // Snap to 45 degrees relative to startPoint or endPoint
                     let fixedPoint = (handle == .start) ? arrowAnnot.endPoint : arrowAnnot.startPoint
                     let dx = p.x - fixedPoint.x
                     let dy = p.y - fixedPoint.y
                     let angle = atan2(dy, dx)
                     let snappedAngle = round(angle / (.pi / 4)) * (.pi / 4)
                     let dist = hypot(dx, dy)
                     p = CGPoint(x: fixedPoint.x + dist * cos(snappedAngle), y: fixedPoint.y + dist * sin(snappedAngle))
                }
                
                if handle == .start { arrowAnnot.startPoint = p }
                if handle == .end { arrowAnnot.endPoint = p }
                annot = arrowAnnot
            }
            
            annotations[index] = annot
            needsDisplay = true
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        if dragAction == .creating {
            if let annotation = currentAnnotation {
                annotations.append(annotation)
                currentAnnotation = nil
                // Auto-select the newly created annotation
                selectedAnnotationID = annotation.id
                // Do not switch tool, allowing immediate adjustment or new drawing
            }
        }
        
        dragAction = .none
        dragStartPoint = nil
        needsDisplay = true
    }
    
    // MARK: - Helpers
    
    private func resizeRect(_ rect: CGRect, handle: ResizeHandle, to point: CGPoint, maintainAspectRatio: Bool = false) -> CGRect {
        var r = rect
        // Simple implementation: Just update the side being dragged.
        // Aspect Ratio constraint is complex because it depends on which handle and maintaining ratio of w/h.
        
        var newX = r.origin.x
        var newY = r.origin.y
        var newW = r.width
        var newH = r.height
        
        switch handle {
        case .topLeft:
            newW = r.maxX - point.x
            newH = r.maxY - point.y
            newX = point.x
            newY = point.y
        case .top:
            newH = r.maxY - point.y
            newY = point.y
        case .topRight:
            newW = point.x - r.minX
            newH = r.maxY - point.y
            newY = point.y
        case .right:
            newW = point.x - r.minX
        case .bottomRight:
            newW = point.x - r.minX
            newH = point.y - r.minY
        case .bottom:
            newH = point.y - r.minY
        case .bottomLeft:
            newW = r.maxX - point.x
            newH = point.y - r.minY
            newX = point.x
        case .left:
            newW = r.maxX - point.x
            newX = point.x
        default: break
        }
        
        // Normalize negative width/height
        if newW < 0 { newX += newW; newW = -newW }
        if newH < 0 { newY += newH; newH = -newH }
        
        // Aspect Ratio Logic
        if maintainAspectRatio {
            // Force 1:1 Aspect Ratio (Square/Circle)
            // Instead of maintaining original ratio, we enforce ratio = 1.0
            let ratio: CGFloat = 1.0
            
            if handle == .top || handle == .bottom {
                // Adjust Width to match Height change
                let newW_ratio = newH * ratio
                let deltaW = newW_ratio - newW
                newW = newW_ratio
                newX -= deltaW / 2 // Center horizontally
            } else if handle == .left || handle == .right {
                // Adjust Height to match Width change
                let newH_ratio = newW / ratio
                let deltaH = newH_ratio - newH
                newH = newH_ratio
                newY -= deltaH / 2 // Center vertically
            } else {
                // Corners: Take the larger change or project
                // For "Square" behavior, usually creating takes max(w, h).
                // Resizing should probably behave similarly, or project onto diagonal.
                // Let's take the max dimension and force square.
                let s = max(newW, newH)
                
                // Adjust origin based on handle to grow in correct direction
                // We have newX/newY which are the "fixed" or "dragged" points depending on handle logic above.
                // Re-calculating based on fixed opposite corner is safer.
                
                // Get opposite corner (fixed point)
                var fixedX = r.origin.x
                var fixedY = r.origin.y
                if handle == .topLeft { fixedX = r.maxX; fixedY = r.maxY }
                else if handle == .topRight { fixedX = r.minX; fixedY = r.maxY }
                else if handle == .bottomLeft { fixedX = r.maxX; fixedY = r.minY }
                else if handle == .bottomRight { fixedX = r.minX; fixedY = r.minY }
                
                // New size
                newW = s
                newH = s
                
                // New origin
                if handle == .topLeft { newX = fixedX - s; newY = fixedY - s }
                else if handle == .topRight { newX = fixedX; newY = fixedY - s }
                else if handle == .bottomLeft { newX = fixedX - s; newY = fixedY }
                else if handle == .bottomRight { newX = fixedX; newY = fixedY }
            }
        }
        
        return CGRect(x: newX, y: newY, width: max(1, newW), height: max(1, newH))
    }
    
    // MARK: - Text Editing
    
    private func startTextEditing(at point: CGPoint) {
        let textView = NSTextView(frame: CGRect(origin: point, size: CGSize(width: 100, height: 24)))
        textView.font = NSFont.systemFont(ofSize: 14) // Should use size property
        textView.textColor = currentColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isRichText = false
        textView.delegate = self
        self.addSubview(textView)
        self.window?.makeFirstResponder(textView)
        activeTextView = textView
    }
    
    private func endTextEditing() {
        guard let textView = activeTextView else { return }
        
        if !textView.string.isEmpty {
            let annot = TextAnnotation(
                text: textView.string,
                origin: textView.frame.origin,
                color: currentColor,
                lineWidth: 0,
                font: textView.font ?? NSFont.systemFont(ofSize: 14),
                isBold: currentIsBold
            )
            annotations.append(annot)
            selectedAnnotationID = annot.id
            // Do not switch tool, keep text tool active
        }
        
        textView.removeFromSuperview()
        activeTextView = nil
        needsDisplay = true
    }
}

extension AnnotationOverlayView: NSTextViewDelegate {
    func textDidEndEditing(_ notification: Notification) {
        endTextEditing()
    }
    
    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            if let event = NSApp.currentEvent, event.modifierFlags.contains(.shift) {
                return false // Allow new line with Shift+Enter
            }
            endTextEditing()
            return true
        }
        return false
    }
}
