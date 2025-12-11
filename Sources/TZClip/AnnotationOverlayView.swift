import Cocoa

class AnnotationOverlayView: NSView {
    
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
    
    // Counter State
    private var nextCounterValue: Int = 1
    
    // Counter Dragging State
    private enum CounterPart {
        case badge
        case label
    }
    private var draggedCounterPart: CounterPart?
    private var selectedCounterPart: CounterPart?
    
    private struct ToolConfig {
        var color: NSColor = .red
        var lineWidth: CGFloat = 4.0
        var isBold: Bool = false
        var isFilled: Bool = false
        var isRounded: Bool = false
        var outlineStyle: Int = 0
        var outlineColor: NSColor = .black
        var fontName: String = "系统默认"
        var textBackgroundColor: NSColor? = nil
    }
    
    private var currentConfig: ToolConfig = ToolConfig()
    
    var currentTool: AnnotationType? {
        willSet {
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
            if let id = selectedAnnotationID, let index = annotations.firstIndex(where: { $0.id == id }) {
                var annot = annotations[index]
                if var counter = annot as? CounterAnnotation {
                    if var l = counter.label { l.color = newValue; counter.label = l } else { counter.color = newValue }
                    annotations[index] = counter
                } else {
                    annot.color = newValue
                    annotations[index] = annot
                }
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
                var annot = annotations[index]
                
                if var counter = annot as? CounterAnnotation {
                    let oldRadius = counter.badgeRadius
                    let oldLineWidth = counter.lineWidth
                    counter.lineWidth = newValue
                    let newRadius = counter.badgeRadius
                    
                    if let labelOrigin = counter.labelOrigin, let labelRect = counter.labelRect {
                        let badgeCenter = counter.badgeCenter
                        let labelCenter = CGPoint(x: labelRect.midX, y: labelRect.midY)
                        
                        let vX = labelCenter.x - badgeCenter.x
                        let vY = labelCenter.y - badgeCenter.y
                        let dist = hypot(vX, vY)
                        
                        if dist > 1.0 {
                            let dirX = vX / dist
                            let dirY = vY / dist
                            
                            let deltaBadge = newRadius - oldRadius
                            let deltaText = (newValue - oldLineWidth) * 0.5
                            let push = deltaBadge + deltaText
                            
                            counter.labelOrigin = CGPoint(
                                x: labelOrigin.x + dirX * push,
                                y: labelOrigin.y + dirY * push
                            )
                        }
                    }
                    annot = counter
                } else {
                    annot.lineWidth = newValue
                }
                
                annotations[index] = annot
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
                } else if var counter = annotations[index] as? CounterAnnotation {
                    if var l = counter.label { l.isBold = newValue; counter.label = l } else { counter.isBold = newValue }
                    annotations[index] = counter
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
                } else if var counter = annotations[index] as? CounterAnnotation {
                    if var l = counter.label { l.outlineStyle = newValue; counter.label = l } else { counter.outlineStyle = newValue }
                    annotations[index] = counter
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
                } else if var counter = annotations[index] as? CounterAnnotation {
                    if var l = counter.label { l.outlineColor = newValue; counter.label = l } else { counter.outlineColor = newValue }
                    annotations[index] = counter
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
                } else if var counter = annotations[index] as? CounterAnnotation {
                    if var l = counter.label { l.fontName = newValue; counter.label = l } else { counter.fontName = newValue }
                    annotations[index] = counter
                    needsDisplay = true
                }
            }
            updateActiveTextView()
        }
    }
    
    var currentTextBackgroundColor: NSColor? {
        get { currentConfig.textBackgroundColor }
        set {
            currentConfig.textBackgroundColor = newValue
            updateActiveTextView()
            if let id = selectedAnnotationID, let index = annotations.firstIndex(where: { $0.id == id }) {
                if var textAnnot = annotations[index] as? TextAnnotation {
                    textAnnot.backgroundColor = newValue
                    annotations[index] = textAnnot
                    needsDisplay = true
                } else if var counterAnnot = annotations[index] as? CounterAnnotation {
                    if var l = counterAnnot.label { l.backgroundColor = newValue; counterAnnot.label = l }
                    else { counterAnnot.backgroundColor = newValue }
                    annotations[index] = counterAnnot
                    needsDisplay = true
                }
            }
        }
    }
    
    var onSelectionChange: ((Annotation?) -> Void)?
    var onToolChange: ((AnnotationType) -> Void)?
    var hasSelection: Bool { selectedAnnotationID != nil }
    
    private var annotations: [Annotation] = []
    private var redoStack: [Annotation] = []
    private var skipNextBlankClickCreation: Bool = false
    private var currentAnnotation: Annotation?
    private var selectedAnnotationID: UUID? {
        didSet {
            needsDisplay = true
            if let id = selectedAnnotationID, let annotation = annotations.first(where: { $0.id == id }) {
                onSelectionChange?(annotation)
            } else {
                onSelectionChange?(nil)
                selectedCounterPart = nil
            }
        }
    }
    
    private var dragStartPoint: CGPoint?
    private var dragAction: DragAction = .none
    
    private var activeTextView: NSTextView?
    private var editingAnnotationID: UUID?
    
    private struct TextEditingState {
        var isBold: Bool
        var outlineStyle: Int
        var outlineColor: NSColor
        var fontName: String
    }
    private var currentEditingState: TextEditingState?
    
    private func updateActiveTextView() {
        guard let textView = activeTextView else { return }
        if currentTool != .text && currentTool != .select && currentTool != .counter {
            return
        }
        
        let size = max(10.0, min(100.0, currentLineWidth))
        
        var font: NSFont
        if currentFontName == "System Default" || currentFontName == "系统默认" {
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
        if let bg = currentConfig.textBackgroundColor {
            textView.drawsBackground = true
            textView.backgroundColor = bg.withAlphaComponent(currentColor.alphaComponent)
        } else {
            textView.drawsBackground = false
            textView.backgroundColor = .clear
        }
        
        currentEditingState = TextEditingState(
            isBold: currentIsBold,
            outlineStyle: currentOutlineStyle,
            outlineColor: currentOutlineColor,
            fontName: currentFontName
        )
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
        self.layer?.masksToBounds = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
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
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if let tv = activeTextView, event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "a" {
            tv.selectAll(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
    
    private func drawSelection(for annotation: Annotation, in context: CGContext) {
        context.saveGState()
        
        // Determine bounds to draw based on selection state
        var boundsToDraw = annotation.bounds
        if let counter = annotation as? CounterAnnotation, let part = selectedCounterPart {
            if part == .badge {
                boundsToDraw = counter.badgeRect
            } else if let labelRect = counter.labelRect {
                boundsToDraw = labelRect
            }
        }
        
        // Draw bounding box
        context.setStrokeColor(NSColor.selectedControlColor.cgColor)
        context.setLineWidth(1.0)
        context.stroke(boundsToDraw)
        
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
        
        var bounds = annotation.bounds
        if let counter = annotation as? CounterAnnotation, let part = selectedCounterPart {
            if part == .badge {
                bounds = counter.badgeRect
            } else if let labelRect = counter.labelRect {
                bounds = labelRect
            }
        }
        
        if annotation.type == .line || annotation.type == .arrow {
            if let line = annotation as? LineAnnotation {
                handles[.start] = CGRect(x: line.startPoint.x - half, y: line.startPoint.y - half, width: handleSize, height: handleSize)
                handles[.end] = CGRect(x: line.endPoint.x - half, y: line.endPoint.y - half, width: handleSize, height: handleSize)
            } else if let arrow = annotation as? ArrowAnnotation {
                handles[.start] = CGRect(x: arrow.startPoint.x - half, y: arrow.startPoint.y - half, width: handleSize, height: handleSize)
                handles[.end] = CGRect(x: arrow.endPoint.x - half, y: arrow.endPoint.y - half, width: handleSize, height: handleSize)
            }
        } else if annotation.type == .pen || annotation.type == .text {
             let b = annotation.bounds
            handles[.topLeft] = CGRect(x: b.minX - half, y: b.minY - half, width: handleSize, height: handleSize)
            handles[.topRight] = CGRect(x: b.maxX - half, y: b.minY - half, width: handleSize, height: handleSize)
            handles[.bottomLeft] = CGRect(x: b.minX - half, y: b.maxY - half, width: handleSize, height: handleSize)
            handles[.bottomRight] = CGRect(x: b.maxX - half, y: b.maxY - half, width: handleSize, height: handleSize)
        } else if let _ = annotation as? CounterAnnotation {
             let b = bounds
             handles[.topLeft] = CGRect(x: b.minX - half, y: b.minY - half, width: handleSize, height: handleSize)
             handles[.topRight] = CGRect(x: b.maxX - half, y: b.minY - half, width: handleSize, height: handleSize)
             handles[.bottomLeft] = CGRect(x: b.minX - half, y: b.maxY - half, width: handleSize, height: handleSize)
             handles[.bottomRight] = CGRect(x: b.maxX - half, y: b.maxY - half, width: handleSize, height: handleSize)
        } else {
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
    
    func renderAnnotations(in context: CGContext) {
        context.saveGState()
        for annotation in annotations {
            annotation.draw(in: context)
        }
        context.restoreGState()
    }
    
    func undo() {
        if !annotations.isEmpty {
            let removed = annotations.removeLast()
            redoStack.append(removed)
            needsDisplay = true
        }
    }
    func redo() {
        if let last = redoStack.popLast() {
            annotations.append(last)
            selectedAnnotationID = last.id
            needsDisplay = true
        }
    }
    
    func deleteSelected() {
        if let id = selectedAnnotationID, let index = annotations.firstIndex(where: { $0.id == id }) {
            if var counter = annotations[index] as? CounterAnnotation, selectedCounterPart == .label {
                counter.label = nil
                counter.text = nil
                counter.labelOrigin = nil
                annotations[index] = counter
                selectedCounterPart = .badge
            } else {
                let removed = annotations.remove(at: index)
                redoStack.append(removed)
                selectedAnnotationID = nil
            }
            needsDisplay = true
        }
    }
    
    func clear() {
        annotations.removeAll()
        currentAnnotation = nil
        selectedAnnotationID = nil
        nextCounterValue = 1
        needsDisplay = true
    }
    
    override func resetCursorRects() {
        if let tool = currentTool, tool != .select {
            addCursorRect(bounds, cursor: .crosshair)
        } else {
            super.resetCursorRects()
            if let id = selectedAnnotationID, let annotation = annotations.first(where: { $0.id == id }) {
                let handles = getHandleRects(for: annotation)
                for (_, rect) in handles {
                    addCursorRect(rect, cursor: .pointingHand)
                }
            }
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        if let selectionView = self.superview {
            self.window?.makeFirstResponder(selectionView)
        }

        if activeTextView != nil {
            endTextEditing()
            return
        }

        let p = convert(event.locationInWindow, from: nil)
        
        if event.clickCount == 2 {
             if let index = annotations.lastIndex(where: { $0.contains(point: p) }) {
                 let annot = annotations[index]
                 
                 if let textAnnot = annot as? TextAnnotation {
                     selectedAnnotationID = nil
                     self.currentColor = textAnnot.color
                     self.currentLineWidth = textAnnot.lineWidth
                     self.currentIsBold = textAnnot.isBold
                     self.currentFontName = textAnnot.fontName
                     self.currentOutlineStyle = textAnnot.outlineStyle
                     self.currentOutlineColor = textAnnot.outlineColor
                     
                     startTextEditing(at: textAnnot.origin, existingText: textAnnot.text, existingAnnotID: textAnnot.id)
                     return
                } else if let counterAnnot = annot as? CounterAnnotation {
                     selectedAnnotationID = nil
                     self.currentColor = counterAnnot.color
                     self.currentLineWidth = counterAnnot.lineWidth
                     
                     let origin = counterAnnot.label?.origin ?? counterAnnot.labelOrigin ?? CGPoint(x: counterAnnot.badgeCenter.x, y: counterAnnot.badgeCenter.y + counterAnnot.badgeRadius + 5)
                     
                     self.currentFontName = counterAnnot.label?.fontName ?? counterAnnot.fontName
                     self.currentIsBold = counterAnnot.label?.isBold ?? counterAnnot.isBold
                     self.currentOutlineStyle = counterAnnot.label?.outlineStyle ?? counterAnnot.outlineStyle
                     self.currentOutlineColor = counterAnnot.label?.outlineColor ?? counterAnnot.outlineColor
                     self.currentTextBackgroundColor = counterAnnot.label?.backgroundColor ?? counterAnnot.backgroundColor
                     
                     startTextEditing(at: origin, existingText: counterAnnot.label?.text ?? counterAnnot.text, existingAnnotID: counterAnnot.id, isCounter: true)
                     return
                 }
             }
        }
        
        if let id = selectedAnnotationID, let annotation = annotations.first(where: { $0.id == id }) {
            let handles = getHandleRects(for: annotation)
            for (handle, rect) in handles {
                if rect.contains(p) {
                    dragAction = .resizing(handle: handle)
                    dragStartPoint = p
                    return
                }
            }
            
            if let counter = annotation as? CounterAnnotation {
                 if let labelRect = counter.labelRect, labelRect.contains(p) {
                     if selectedCounterPart != .label {
                         selectedCounterPart = .label
                         draggedCounterPart = .label
                         needsDisplay = true
                     }
                     dragAction = .moving
                     dragStartPoint = p
                     return
                 } else if counter.badgeRect.contains(p) {
                     if selectedCounterPart != .badge {
                         selectedCounterPart = .badge
                         draggedCounterPart = .badge
                         needsDisplay = true
                     }
                     dragAction = .moving
                     dragStartPoint = p
                     return
                 }
            } else if annotation.contains(point: p) {
                dragAction = .moving
                dragStartPoint = p
                return
            }
        }
        
        if let index = annotations.lastIndex(where: { $0.contains(point: p) }) {
            let annot = annotations[index]
            
            if currentTool != .select {
                currentTool = .select
                onToolChange?(.select)
            }
            
            selectedAnnotationID = annot.id
            dragAction = .moving
            dragStartPoint = p
            
            if let counter = annot as? CounterAnnotation {
                if let labelRect = counter.labelRect, labelRect.contains(p) {
                    selectedCounterPart = .label
                } else {
                    selectedCounterPart = .badge
                }
                draggedCounterPart = selectedCounterPart
            } else {
                selectedCounterPart = nil
                draggedCounterPart = nil
            }
            
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
        
        dragStartPoint = p
        
        if currentTool == .text {
            dragAction = .none
            dragStartPoint = p
            return
        }
        
        if currentTool == .counter {
            dragAction = .none
            dragStartPoint = p
            return
        }
        
        if let tool = currentTool {
            switch tool {
            case .rectangle, .ellipse, .arrow, .line, .pen:
                // Avoid immediate creation on click; require drag threshold in mouseDragged
                dragAction = .none
            default:
                break
            }
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        
        if dragAction == .none {
            if let start = dragStartPoint, let tool = currentTool {
                let dist = hypot(p.x - start.x, p.y - start.y)
                if dist > 3.0 {
                    switch tool {
                    case .rectangle:
                        currentAnnotation = RectangleAnnotation(rect: CGRect(origin: start, size: .zero), color: currentColor, lineWidth: currentLineWidth, isFilled: currentIsFilled, isRounded: currentIsRounded)
                    case .ellipse:
                        currentAnnotation = EllipseAnnotation(rect: CGRect(origin: start, size: .zero), color: currentColor, lineWidth: currentLineWidth, isFilled: currentIsFilled)
                    case .arrow:
                        currentAnnotation = ArrowAnnotation(startPoint: start, endPoint: start, color: currentColor, lineWidth: currentLineWidth)
                    case .line:
                        currentAnnotation = LineAnnotation(startPoint: start, endPoint: start, color: currentColor, lineWidth: currentLineWidth)
                    case .pen:
                        currentAnnotation = PenAnnotation(points: [start], color: currentColor, lineWidth: currentLineWidth)
                    default:
                        break
                    }
                    dragAction = .creating
                }
            }
        } else if dragAction == .creating {
            guard let start = dragStartPoint, var annot = currentAnnotation else { return }
            
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
            
            var annot = annotations[index]
            
            if var counter = annot as? CounterAnnotation, let part = draggedCounterPart {
                if part == .label {
                    if var l = counter.label {
                        l.origin = CGPoint(x: l.origin.x + delta.x, y: l.origin.y + delta.y)
                        counter.label = l
                        annot = counter
                    } else if let origin = counter.labelOrigin {
                        counter.labelOrigin = CGPoint(x: origin.x + delta.x, y: origin.y + delta.y)
                        annot = counter
                    }
                } else {
                    counter.badgeCenter = CGPoint(x: counter.badgeCenter.x + delta.x, y: counter.badgeCenter.y + delta.y)
                    annot = counter
                }
            } else {
                annot = annot.move(by: delta)
            }
            
            annotations[index] = annot
            dragStartPoint = p
            needsDisplay = true
        } else if case .resizing(let handle) = dragAction {
            guard let id = selectedAnnotationID, let index = annotations.firstIndex(where: { $0.id == id }) else { return }
            var annot = annotations[index]
            let isShift = event.modifierFlags.contains(.shift)
            
            if var counter = annot as? CounterAnnotation {
                 if selectedCounterPart == .badge {
                      let oldBounds = counter.badgeRect
                      let newBounds = resizeRect(oldBounds, handle: handle, to: p, maintainAspectRatio: true)
                      let newRadius = newBounds.width / 2.0
                      counter.lineWidth = max(10.0, min(100.0, (newRadius - 4.0) / 0.6))
                      counter.badgeCenter = CGPoint(x: newBounds.midX, y: newBounds.midY)
                 } else if selectedCounterPart == .label, let oldLabelRect = counter.labelRect {
                      let newBounds = resizeRect(oldLabelRect, handle: handle, to: p, maintainAspectRatio: true)
                      let scale = newBounds.height / max(1.0, oldLabelRect.height)
                      counter.lineWidth = max(10.0, min(100.0, counter.lineWidth * scale))
                      if var l = counter.label { l.origin = newBounds.origin; counter.label = l } else { counter.labelOrigin = newBounds.origin }
                 }
                annot = counter
            } else if var rectAnnot = annot as? RectangleAnnotation {
                rectAnnot.rect = resizeRect(rectAnnot.rect, handle: handle, to: p, maintainAspectRatio: isShift)
                annot = rectAnnot
            } else if var ellAnnot = annot as? EllipseAnnotation {
                ellAnnot.rect = resizeRect(ellAnnot.rect, handle: handle, to: p, maintainAspectRatio: isShift)
                annot = ellAnnot
            } else if var lineAnnot = annot as? LineAnnotation {
                var p2 = p
                if isShift {
                    let fixedPoint = (handle == .start) ? lineAnnot.endPoint : lineAnnot.startPoint
                    let dx = p2.x - fixedPoint.x
                    let dy = p2.y - fixedPoint.y
                    let angle = atan2(dy, dx)
                    let snappedAngle = round(angle / (.pi / 4)) * (.pi / 4)
                    let dist = hypot(dx, dy)
                    p2 = CGPoint(x: fixedPoint.x + dist * cos(snappedAngle), y: fixedPoint.y + dist * sin(snappedAngle))
                }
                
                if handle == .start { lineAnnot.startPoint = p2 }
                if handle == .end { lineAnnot.endPoint = p2 }
                annot = lineAnnot
            } else if var arrowAnnot = annot as? ArrowAnnotation {
                var p2 = p
                if isShift {
                     let fixedPoint = (handle == .start) ? arrowAnnot.endPoint : arrowAnnot.startPoint
                     let dx = p2.x - fixedPoint.x
                     let dy = p2.y - fixedPoint.y
                     let angle = atan2(dy, dx)
                     let snappedAngle = round(angle / (.pi / 4)) * (.pi / 4)
                     let dist = hypot(dx, dy)
                     p2 = CGPoint(x: fixedPoint.x + dist * cos(snappedAngle), y: fixedPoint.y + dist * sin(snappedAngle))
                }
                
                if handle == .start { arrowAnnot.startPoint = p2 }
                if handle == .end { arrowAnnot.endPoint = p2 }
                annot = arrowAnnot
            }
            
            annotations[index] = annot
            needsDisplay = true
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        if dragAction == .none {
            if currentTool == .text {
                if skipNextBlankClickCreation {
                    skipNextBlankClickCreation = false
                } else {
                    let origin = dragStartPoint ?? convert(event.locationInWindow, from: nil)
                    startTextEditing(at: origin)
                    skipNextBlankClickCreation = true
                }
                dragAction = .none
                dragStartPoint = nil
                needsDisplay = true
                return
            } else if currentTool == .counter {
                if skipNextBlankClickCreation {
                    skipNextBlankClickCreation = false
                } else {
                    let originPoint = dragStartPoint ?? convert(event.locationInWindow, from: nil)
                    var c = CounterAnnotation(number: nextCounterValue, badgeCenter: originPoint, labelOrigin: nil, text: nil, color: currentColor, lineWidth: currentLineWidth)
                    c.fontName = currentFontName
                    c.isBold = currentIsBold
                    c.outlineStyle = currentOutlineStyle
                    c.outlineColor = currentOutlineColor
                    c.backgroundColor = currentConfig.textBackgroundColor
                    annotations.append(c)
                    nextCounterValue += 1
                    selectedAnnotationID = c.id
                    let textOrigin = CGPoint(x: c.badgeCenter.x, y: c.badgeCenter.y + c.badgeRadius + 5)
                    self.currentFontName = c.fontName
                    self.currentIsBold = c.isBold
                    self.currentOutlineStyle = c.outlineStyle
                    self.currentOutlineColor = c.outlineColor
                    self.currentTextBackgroundColor = c.backgroundColor
                    startTextEditing(at: textOrigin, existingText: nil, existingAnnotID: c.id, isCounter: true)
                    selectedCounterPart = .label
                    skipNextBlankClickCreation = true
                }
                needsDisplay = true
                return
            }
        } else if dragAction == .creating {
            if let annotation = currentAnnotation {
                annotations.append(annotation)
                currentAnnotation = nil
                selectedAnnotationID = annotation.id
                redoStack.removeAll()
                skipNextBlankClickCreation = true
            }
        }
        
        dragAction = .none
        dragStartPoint = nil
        needsDisplay = true
    }
    
    private func resizeRect(_ rect: CGRect, handle: ResizeHandle, to point: CGPoint, maintainAspectRatio: Bool = false) -> CGRect {
        var r = rect
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
        
        if newW < 0 { newX += newW; newW = -newW }
        if newH < 0 { newY += newH; newH = -newH }
        
        if maintainAspectRatio {
            let ratio = r.width / r.height
            if newW > newH {
                 let oldH = newH
                 newH = newW / ratio
                 if handle == .topLeft || handle == .top || handle == .topRight {
                     newY -= (newH - oldH)
                 }
            } else {
                 let oldW = newW
                 newW = newH * ratio
                 if handle == .topLeft || handle == .left || handle == .bottomLeft {
                     newX -= (newW - oldW)
                 }
            }
        }
        
        return CGRect(x: newX, y: newY, width: max(1, newW), height: max(1, newH))
    }
    
    private func startTextEditing(at point: CGPoint, existingText: String? = nil, existingAnnotID: UUID? = nil, isCounter: Bool = false) {
        editingAnnotationID = existingAnnotID
        
        let initialWidth: CGFloat = existingText == nil ? 50 : 200
        
        let textView = NSTextView(frame: CGRect(origin: point, size: CGSize(width: initialWidth, height: 24)))
        
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
        if let bg = currentConfig.textBackgroundColor {
            textView.backgroundColor = bg.withAlphaComponent(currentColor.alphaComponent)
            textView.drawsBackground = true
        } else {
            textView.backgroundColor = .clear
            textView.drawsBackground = false
        }
        textView.isRichText = false
        textView.delegate = self
        textView.textContainerInset = NSSize(width: 8, height: 3)
        textView.textContainer?.lineFragmentPadding = 4
        
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        
        if let text = existingText {
            textView.string = text
            if let id = existingAnnotID, !isCounter {
                annotations.removeAll(where: { $0.id == id })
                needsDisplay = true
            }
            if let layoutManager = textView.layoutManager, let textContainer = textView.textContainer {
                layoutManager.ensureLayout(for: textContainer)
                let usedRect = layoutManager.usedRect(for: textContainer)
                let insetW = textView.textContainerInset.width * 2 + (textView.textContainer?.lineFragmentPadding ?? 0) * 2
                let insetH = textView.textContainerInset.height * 2
                textView.frame.size = CGSize(width: max(50, usedRect.width + insetW + 4), height: max(size + 4, usedRect.height + insetH))
            } else {
                textView.sizeToFit()
            }
        }
        
        self.addSubview(textView)
        self.window?.makeFirstResponder(textView)
        activeTextView = textView
        
        if existingText == nil {
             if let layoutManager = textView.layoutManager, let textContainer = textView.textContainer {
                 layoutManager.ensureLayout(for: textContainer)
                 let height = layoutManager.usedRect(for: textContainer).height
                 textView.frame.size.height = max(height + textView.textContainerInset.height * 2, size + 4)
             }
             textView.frame.size.width = 50
        }
        
        currentEditingState = TextEditingState(
            isBold: currentIsBold,
            outlineStyle: currentOutlineStyle,
            outlineColor: currentOutlineColor,
            fontName: currentFontName
        )
    }
    
    private func endTextEditing() {
        guard let textView = activeTextView else { return }
        
        let isBold = currentEditingState?.isBold ?? currentIsBold
        let outlineStyle = currentEditingState?.outlineStyle ?? currentOutlineStyle
        let outlineColor = currentEditingState?.outlineColor ?? currentOutlineColor
        let fontName = currentEditingState?.fontName ?? currentFontName
        
        if !textView.string.isEmpty {
            if let id = editingAnnotationID, let index = annotations.firstIndex(where: { $0.id == id }), var counter = annotations[index] as? CounterAnnotation {
                let fontSize = textView.font?.pointSize ?? currentLineWidth
                let labelTA = TextAnnotation(
                    text: textView.string,
                    origin: textView.frame.origin,
                    color: textView.textColor ?? .black,
                    lineWidth: fontSize,
                    font: textView.font ?? NSFont.systemFont(ofSize: fontSize),
                    isBold: isBold,
                    outlineStyle: outlineStyle,
                    outlineColor: outlineColor,
                    fontName: fontName,
                    backgroundColor: currentConfig.textBackgroundColor
                )
                counter.label = labelTA
                counter.text = nil
                counter.labelOrigin = nil
                counter.lineWidth = fontSize
                counter.color = textView.textColor ?? counter.color
                annotations[index] = counter
                selectedAnnotationID = counter.id
                selectedCounterPart = .label
            } else {
                let fontSize = textView.font?.pointSize ?? 14.0
                
                let annot = TextAnnotation(
                    text: textView.string,
                    origin: textView.frame.origin,
                    color: textView.textColor ?? .black,
                    lineWidth: fontSize,
                    font: textView.font ?? NSFont.systemFont(ofSize: 14),
                    isBold: isBold,
                    outlineStyle: outlineStyle,
                    outlineColor: outlineColor,
                    fontName: fontName,
                    backgroundColor: currentConfig.textBackgroundColor
                )
                annotations.append(annot)
                
                if currentTool == .text {
                    selectedAnnotationID = nil
                } else {
                    selectedAnnotationID = annot.id
                }
            }
        } else {
             if let id = editingAnnotationID, let index = annotations.firstIndex(where: { $0.id == id }), var counter = annotations[index] as? CounterAnnotation {
                 counter.label = nil
                 counter.text = nil
                 counter.labelOrigin = nil
                 annotations[index] = counter
             }
        }
        
        textView.removeFromSuperview()
        activeTextView = nil
        editingAnnotationID = nil
        currentEditingState = nil
        needsDisplay = true
        
        if let selectionView = self.superview {
            self.window?.makeFirstResponder(selectionView)
        }
    }
}

extension AnnotationOverlayView: NSTextViewDelegate {
    func textDidEndEditing(_ notification: Notification) {
        endTextEditing()
    }
    
    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            if let event = NSApp.currentEvent, event.modifierFlags.contains(.shift) {
                return false
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
        if let layoutManager = textView.layoutManager, let textContainer = textView.textContainer {
            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            let insetW = textView.textContainerInset.width * 2 + (textView.textContainer?.lineFragmentPadding ?? 0) * 2
            let insetH = textView.textContainerInset.height * 2
            let newW = max(50, usedRect.width + insetW + 4)
            let newH = max(usedRect.height + insetH, (textView.font?.pointSize ?? 14) + 4)
            textView.frame.size = CGSize(width: newW, height: newH)
        } else {
            textView.sizeToFit()
            if textView.frame.width < 50 { textView.frame.size.width = 50 }
        }
    }
}
