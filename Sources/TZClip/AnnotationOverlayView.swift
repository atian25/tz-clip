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
        var outlineStyle: Int = 0
        var outlineColor: NSColor = .black
        var fontName: String = "System Default"
    }
    
    private var toolConfigs: [AnnotationType: ToolConfig] = [:]
    
    // Helper to get/set config for current tool
    private var currentConfig: ToolConfig {
        get {
            guard let tool = currentTool else { return ToolConfig() }
            if let config = toolConfigs[tool] {
                return config
            }
            // Default logic
            var config = ToolConfig()
            if tool == .text {
                config.lineWidth = 18.0 // Default font size
            }
            return config
        }
        set {
            guard let tool = currentTool else { return }
            toolConfigs[tool] = newValue
        }
    }
    
    var currentTool: AnnotationType? {
        willSet {
             // If we are switching tools (or cancelling), we must end any active text editing session.
             // We do this in willSet so that `endTextEditing` runs with the OLD config (e.g. text tool config)
             // before the new config (e.g. line tool config) is loaded.
             if let _ = activeTextView {
                 endTextEditing()
             }
        }
        didSet {
            window?.invalidateCursorRects(for: self)
            
            if currentTool != .select {
                selectedAnnotationID = nil
            }
        }
    }
    
    var currentColor: NSColor {
        get { currentConfig.color }
        set {
            currentConfig.color = newValue
            // Also update selected annotation if any
            if let id = selectedAnnotationID, let index = annotations.firstIndex(where: { $0.id == id }) {
                annotations[index].color = newValue
                needsDisplay = true
            }
            updateActiveTextView()
        }
    }
    
    var currentLineWidth: CGFloat {
        get { currentConfig.lineWidth }
        set {
            currentConfig.lineWidth = newValue
            if let id = selectedAnnotationID, let index = annotations.firstIndex(where: { $0.id == id }) {
                annotations[index].lineWidth = newValue
                needsDisplay = true
            }
            updateActiveTextView()
        }
    }
    
    var currentIsBold: Bool {
        get { currentConfig.isBold }
        set {
            currentConfig.isBold = newValue
            if let id = selectedAnnotationID, let index = annotations.firstIndex(where: { $0.id == id }) {
                if var textAnnot = annotations[index] as? TextAnnotation {
                    textAnnot.isBold = newValue
                    annotations[index] = textAnnot
                    needsDisplay = true
                }
            }
            updateActiveTextView()
        }
    }
    
    var currentIsFilled: Bool {
        get { currentConfig.isFilled }
        set {
            currentConfig.isFilled = newValue
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
            currentConfig.isRounded = newValue
            if let id = selectedAnnotationID, let index = annotations.firstIndex(where: { $0.id == id }) {
                if var rectAnnot = annotations[index] as? RectangleAnnotation {
                    rectAnnot.isRounded = newValue
                    annotations[index] = rectAnnot
                    needsDisplay = true
                }
            }
        }
    }
    
    var currentOutlineStyle: Int {
        get { currentConfig.outlineStyle }
        set {
            currentConfig.outlineStyle = newValue
            if let id = selectedAnnotationID, let index = annotations.firstIndex(where: { $0.id == id }) {
                if var textAnnot = annotations[index] as? TextAnnotation {
                    textAnnot.outlineStyle = newValue
                    annotations[index] = textAnnot
                    needsDisplay = true
                }
            }
        }
    }
    
    var currentOutlineColor: NSColor {
        get { currentConfig.outlineColor }
        set {
            currentConfig.outlineColor = newValue
            if let id = selectedAnnotationID, let index = annotations.firstIndex(where: { $0.id == id }) {
                if var textAnnot = annotations[index] as? TextAnnotation {
                    textAnnot.outlineColor = newValue
                    annotations[index] = textAnnot
                    needsDisplay = true
                }
            }
        }
    }
    
    var currentFontName: String {
        get { currentConfig.fontName }
        set {
            currentConfig.fontName = newValue
            if let id = selectedAnnotationID, let index = annotations.firstIndex(where: { $0.id == id }) {
                if var textAnnot = annotations[index] as? TextAnnotation {
                    textAnnot.fontName = newValue
                    annotations[index] = textAnnot
                    needsDisplay = true
                }
            }
            updateActiveTextView()
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
    
    // Text Editing State Snapshot
    private struct TextEditingState {
        var isBold: Bool
        var outlineStyle: Int
        var outlineColor: NSColor
        var fontName: String
    }
    private var currentEditingState: TextEditingState?

    // MARK: - Text Editing Helper
    
    private func updateActiveTextView() {
        guard let textView = activeTextView else { return }
        
        // If we are editing, we should respect the current tool's config OR the selected annotation's config.
        // But if currentTool switched to something else (e.g. Line), we should NOT update activeTextView.
        // This is a safety check.
        if currentTool != .text && currentTool != .select {
            return
        }
        
        let size = max(10.0, min(100.0, currentLineWidth))
        
        var font: NSFont
        if currentFontName == "System Default" {
            font = NSFont.systemFont(ofSize: size)
        } else {
            font = NSFont(name: currentFontName, size: size) ?? NSFont.systemFont(ofSize: size)
        }
        
        if currentIsBold {
            font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        } else {
            font = NSFontManager.shared.convert(font, toNotHaveTrait: .boldFontMask)
        }
        
        textView.font = font
        textView.textColor = currentColor
        
        // Update Snapshot
        currentEditingState = TextEditingState(
            isBold: currentIsBold,
            outlineStyle: currentOutlineStyle,
            outlineColor: currentOutlineColor,
            fontName: currentFontName
        )
    }
    
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
        // 0. Check if we are currently editing text.
        // If so, any click outside the text view (which ends up here) should commit the edit.
        // We swallow the event to prevent accidental creation/selection of others immediately.
        if activeTextView != nil {
            endTextEditing()
            return
        }

        let p = convert(event.locationInWindow, from: nil)
        dragStartPoint = p
        
        // Priority 0: Handle Double Click for Editing
        if event.clickCount == 2 {
             if let index = annotations.lastIndex(where: { $0.contains(point: p) }) {
                 let annot = annotations[index]
                 if let textAnnot = annot as? TextAnnotation {
                     // Deselect current annotation to prevent property setters from modifying it
                     // (e.g. if A was selected, updating lineWidth for B should not resize A)
                     selectedAnnotationID = nil
                     
                     // Sync properties to global state so editor uses correct style
                     self.currentColor = textAnnot.color
                     self.currentLineWidth = textAnnot.lineWidth
                     self.currentIsBold = textAnnot.isBold
                     self.currentFontName = textAnnot.fontName
                     self.currentOutlineStyle = textAnnot.outlineStyle
                     self.currentOutlineColor = textAnnot.outlineColor
                     
                     // Start Editing existing text
                     startTextEditing(at: textAnnot.origin, existingText: textAnnot.text, existingAnnotID: textAnnot.id)
                     return
                 }
             }
        }
        
        // Priority 1: Check Handles of selected annotation
        if let id = selectedAnnotationID, let annotation = annotations.first(where: { $0.id == id }) {
            let handles = getHandleRects(for: annotation)
            for (handle, rect) in handles {
                if rect.contains(p) {
                    dragAction = .resizing(handle: handle)
                    return
                }
            }
            
            // Priority 2: Check Body of selected annotation (Moving)
            if annotation.contains(point: p) {
                dragAction = .moving
                return
            }
        }
        
        // Priority 3: Check Body of ANY annotation (Selection)
        // Even if we are in Creation Mode (e.g. Text), if we click ON an existing annotation,
        // we should select it (and switch to Select tool) instead of creating new on top.
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
                self.currentFontName = textAnnot.fontName
                self.currentOutlineStyle = textAnnot.outlineStyle
                self.currentOutlineColor = textAnnot.outlineColor
            }
            
            needsDisplay = true
            return
        }
        
        // Handle Text Creation (Only if NOT clicking on existing annotation)
        if currentTool == .text {
            startTextEditing(at: p)
            return
        }
        
        // Priority 4: Creation Mode (Shapes/Lines)
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
    
    private func startTextEditing(at point: CGPoint, existingText: String? = nil, existingAnnotID: UUID? = nil) {
        // ... (existing configuration code) ...
        
        let initialWidth: CGFloat = existingText == nil ? 50 : 200 // Will resize anyway
        
        // Ensure the text view frame doesn't exceed the overlay bounds initially
        // But since we want auto-resize, we should start small and let it grow.
        // The issue is likely `containerSize` being too large or clipview not set up.
        // NSTextView is complex.
        
        let textView = NSTextView(frame: CGRect(origin: point, size: CGSize(width: initialWidth, height: 24)))
        
        // ... Font configuration ...
        // Ensure we use the correct size if we are editing existing text
        // If editing, currentLineWidth should have been updated by mouseDown logic already.
        // But let's double check logic.
        let size = max(10.0, min(100.0, currentLineWidth)) // Enforce 10-100 range
        var font: NSFont
        if currentFontName == "System Default" {
            font = NSFont.systemFont(ofSize: size)
        } else {
            font = NSFont(name: currentFontName, size: size) ?? NSFont.systemFont(ofSize: size)
        }
        
        if currentIsBold {
            font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        } else {
            font = NSFontManager.shared.convert(font, toNotHaveTrait: .boldFontMask)
        }
        
        textView.font = font
        textView.textColor = currentColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isRichText = false
        textView.delegate = self
        
        // Auto-resizing configuration
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = false // Allow growing horizontally
        textView.textContainer?.containerSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        
        if let text = existingText {
            textView.string = text
            if let id = existingAnnotID {
                annotations.removeAll(where: { $0.id == id })
                needsDisplay = true
            }
            // Explicitly resize for existing text
            // Important: We must ensure layoutManager has done its job
            if let layoutManager = textView.layoutManager, let textContainer = textView.textContainer {
                layoutManager.ensureLayout(for: textContainer)
                let usedRect = layoutManager.usedRect(for: textContainer)
                textView.frame.size = CGSize(width: max(50, usedRect.width + 10), height: max(size + 4, usedRect.height))
            } else {
                textView.sizeToFit()
            }
        }
        
        self.addSubview(textView)
        self.window?.makeFirstResponder(textView)
        activeTextView = textView
        
        // Initial resize to fit content or minimum
        if existingText == nil {
             // For new text, start with a reasonable minimum width but ensure height matches font
             if let layoutManager = textView.layoutManager, let textContainer = textView.textContainer {
                 layoutManager.ensureLayout(for: textContainer)
                 let height = layoutManager.usedRect(for: textContainer).height
                 textView.frame.size.height = max(height, size + 4) // Ensure enough height
             }
             textView.frame.size.width = 50
        }
        
        // Initialize Snapshot
        currentEditingState = TextEditingState(
            isBold: currentIsBold,
            outlineStyle: currentOutlineStyle,
            outlineColor: currentOutlineColor,
            fontName: currentFontName
        )
    }
    
    private func endTextEditing() {
        guard let textView = activeTextView else { return }
        
        if !textView.string.isEmpty {
            // Calculate font size from actual view font
            let fontSize = textView.font?.pointSize ?? 14.0
            
            // Use snapshot state if available, otherwise fallback to current config (risky but fallback)
            let isBold = currentEditingState?.isBold ?? currentIsBold
            let outlineStyle = currentEditingState?.outlineStyle ?? currentOutlineStyle
            let outlineColor = currentEditingState?.outlineColor ?? currentOutlineColor
            let fontName = currentEditingState?.fontName ?? currentFontName
            
            let annot = TextAnnotation(
                text: textView.string,
                origin: textView.frame.origin,
                color: textView.textColor ?? .black, // Use actual color
                lineWidth: fontSize, // Use actual font size
                font: textView.font ?? NSFont.systemFont(ofSize: 14),
                isBold: isBold,
                outlineStyle: outlineStyle,
                outlineColor: outlineColor,
                fontName: fontName
            )
            annotations.append(annot)
            
            // Only select the new annotation IF we are NOT in Text Tool mode (e.g. Double Click Edit).
            // If we are in Text Tool mode, we generally want to be ready to create NEW text, not select the old one.
            // BUT, if we select it, changing properties will change IT.
            // Standard drawing app behavior for Text Tool:
            // - Click to type.
            // - Click elsewhere to finish and start NEW text.
            // - The previous text is finalized and Deselected.
            
            if currentTool == .text {
                selectedAnnotationID = nil
            } else {
                selectedAnnotationID = annot.id
            }
        }
        
        textView.removeFromSuperview()
        activeTextView = nil
        currentEditingState = nil
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

    func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
        return true
    }
    
    func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView else { return }
        textView.sizeToFit()
        // Ensure minimum width
        if textView.frame.width < 50 {
            textView.frame.size.width = 50
        }
    }
}
