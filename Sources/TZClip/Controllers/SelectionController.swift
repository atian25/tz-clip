import Cocoa

class SelectionController: AnnotationToolbarDelegate, AnnotationPropertiesDelegate {
    private var toolState: ToolState
    private var selectionState: SelectionState
    private var overlayState: OverlayState
    private weak var overlay: AnnotationOverlayView?
    private weak var propertiesView: AnnotationPropertiesView?
    private var commandBus: CommandBus?
    
    func updateSelectionRect(_ rect: NSRect) {
        selectionState.rect = rect
        overlay?.frame = rect
    }
    
    func positionUI(selectionRect: NSRect, bounds: NSRect, toolbar: AnnotationToolbar, props: AnnotationPropertiesView) {
        let toolbarSize = toolbar.frame.size
        let propsSize = props.frame.size
        let padding: CGFloat = 8
        let origins = ToolbarLayoutService.compute(selectionRect: selectionRect, bounds: bounds, toolbarSize: toolbarSize, propsSize: propsSize, padding: padding)
        toolbar.frame.origin = origins.0
        props.frame.origin = origins.1
    }

    init(toolState: ToolState = ToolState(), selectionState: SelectionState = SelectionState(), overlayState: OverlayState = OverlayState(), overlay: AnnotationOverlayView?, propertiesView: AnnotationPropertiesView?, commandBus: CommandBus?) {
        self.toolState = toolState
        self.selectionState = selectionState
        self.overlayState = overlayState
        self.overlay = overlay
        self.propertiesView = propertiesView
        self.commandBus = commandBus
    }

    func didSelectTool(_ tool: AnnotationType) {
        toolState.currentTool = tool
        overlay?.currentTool = tool
        overlay?.resetBlankClickCreationProtection()
        propertiesView?.configure(for: tool)
        let cfg = toolState.config(for: tool)
        overlay?.currentColor = cfg.color
        overlay?.currentLineWidth = cfg.lineWidth
        overlay?.currentIsBold = cfg.isBold
        overlay?.currentIsFilled = cfg.isFilled
        overlay?.currentIsRounded = cfg.isRounded
        overlay?.currentOutlineStyle = cfg.outlineStyle
        overlay?.currentOutlineColor = cfg.outlineColor
        overlay?.currentFontName = cfg.fontName
        overlay?.currentTextBackgroundColor = cfg.textBackgroundColor
        propertiesView?.selectedColor = cfg.color
        propertiesView?.selectedWidth = cfg.lineWidth
        if tool == .text || tool == .counter {
            propertiesView?.isBold = cfg.isBold
            propertiesView?.fontName = cfg.fontName
            propertiesView?.textBackgroundColor = cfg.textBackgroundColor
        }
        if tool == .rectangle {
            propertiesView?.isRounded = cfg.isRounded
        }
        propertiesView?.isFilled = cfg.isFilled
        if tool == .select {
            propertiesView?.isHidden = !(overlay?.hasSelection ?? false)
        } else {
            propertiesView?.isHidden = false
        }
        if let props = propertiesView {
            let _ = props.frame
        }
    }

    func didSelectAction(_ action: ToolbarAction) {
        commandBus?.execute(action: action)
    }

    func didChangeColor(_ color: NSColor) {
        toolState.updateCurrent { $0.color = color }
        overlay?.currentColor = color
    }
    func didChangeLineWidth(_ width: CGFloat) {
        toolState.updateCurrent { $0.lineWidth = width }
        overlay?.currentLineWidth = width
    }
    func didChangeIsBold(_ isBold: Bool) {
        toolState.updateCurrent { $0.isBold = isBold }
        overlay?.currentIsBold = isBold
    }
    func didChangeIsFilled(_ isFilled: Bool) {
        toolState.updateCurrent { $0.isFilled = isFilled }
        overlay?.currentIsFilled = isFilled
    }
    func didChangeIsRounded(_ isRounded: Bool) {
        toolState.updateCurrent { $0.isRounded = isRounded }
        overlay?.currentIsRounded = isRounded
    }
    func didChangeOutlineStyle(_ style: Int) {
        toolState.updateCurrent { $0.outlineStyle = style }
        overlay?.currentOutlineStyle = style
    }
    func didChangeOutlineColor(_ color: NSColor) {
        toolState.updateCurrent { $0.outlineColor = color }
        overlay?.currentOutlineColor = color
    }
    func didChangeFontName(_ name: String) {
        toolState.updateCurrent { $0.fontName = name }
        overlay?.currentFontName = name
    }
    func didChangeTextBackgroundColor(_ color: NSColor?) {
        toolState.updateCurrent { $0.textBackgroundColor = color }
        overlay?.currentTextBackgroundColor = color
    }

    func attachOverlay(_ overlay: AnnotationOverlayView) {
        self.overlay = overlay
    }
    func attachPropertiesView(_ view: AnnotationPropertiesView) {
        self.propertiesView = view
    }
    func attachCommandBus(_ bus: CommandBus) {
        self.commandBus = bus
    }
}
