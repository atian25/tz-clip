import Cocoa

@MainActor
protocol AnnotationToolbarDelegate: AnyObject {
    func didSelectTool(_ tool: AnnotationType)
    func didSelectAction(_ action: ToolbarAction)
}

enum ToolbarAction {
    case undo
    case close
    case save
    case copy
}

class HoverButton: NSButton {
    private var trackingArea: NSTrackingArea?
    
    // External state to know if this button is currently "selected" (active tool)
    var isSelected: Bool = false {
        didSet {
            updateBackgroundColor()
        }
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
        trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        if !isSelected {
            layer?.backgroundColor = NSColor.lightGray.withAlphaComponent(0.2).cgColor
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        updateBackgroundColor()
    }
    
    private func updateBackgroundColor() {
        if isSelected {
            layer?.backgroundColor = NSColor.selectedControlColor.withAlphaComponent(0.2).cgColor
        } else {
            layer?.backgroundColor = NSColor.clear.cgColor
        }
    }
}

class AnnotationToolbar: NSView {
    weak var delegate: AnnotationToolbarDelegate?
    private var toolButtons: [HoverButton] = []
    private var actionButtons: [HoverButton] = []
    private var selectedTool: AnnotationType?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        setupButtons()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.white.cgColor
        self.layer?.cornerRadius = 4
        self.layer?.shadowColor = NSColor.black.cgColor
        self.layer?.shadowOpacity = 0.3
        self.layer?.shadowOffset = CGSize(width: 0, height: -2)
        self.layer?.shadowRadius = 4
    }
    
    private func setupButtons() {
        let tools: [(String, AnnotationType)] = [
            ("↖", .select), // Select tool
            ("□", .rectangle),
            ("○", .ellipse),
            ("╱", .line),
            ("↗", .arrow),
            ("✎", .pen),
            ("T", .text)
        ]
        
        let actions: [(String, ToolbarAction)] = [
            ("↩", .undo),
            ("✕", .close),
            ("⬇", .save),
            ("✓", .copy)
        ]
        
        var xOffset: CGFloat = 8
        let buttonSize: CGFloat = 32
        let spacing: CGFloat = 4
        
        // Tool Buttons
        for (title, type) in tools {
            let btn = createButton(title: title)
            btn.frame = CGRect(x: xOffset, y: 4, width: buttonSize, height: buttonSize)
            btn.tag = getTag(for: type)
            btn.target = self
            btn.action = #selector(toolButtonTapped(_:))
            addSubview(btn)
            toolButtons.append(btn)
            xOffset += buttonSize + spacing
        }
        
        // Separator
        let separator = NSView(frame: CGRect(x: xOffset, y: 8, width: 1, height: 24))
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.lightGray.cgColor
        addSubview(separator)
        xOffset += spacing + 1
        
        // Action Buttons
        for (title, action) in actions {
            let btn = createButton(title: title)
            btn.frame = CGRect(x: xOffset, y: 4, width: buttonSize, height: buttonSize)
            btn.tag = getTag(for: action)
            btn.target = self
            btn.action = #selector(actionButtonTapped(_:))
            addSubview(btn)
            actionButtons.append(btn)
            xOffset += buttonSize + spacing
        }
        
        // Adjust frame width
        var frame = self.frame
        frame.size.width = xOffset + 4
        frame.size.height = 40
        self.frame = frame
    }
    
    private func createButton(title: String) -> HoverButton {
        let btn = HoverButton()
        btn.title = title
        btn.bezelStyle = .inline
        btn.isBordered = false
        btn.wantsLayer = true
        btn.layer?.backgroundColor = NSColor.clear.cgColor
        btn.layer?.cornerRadius = 4
        btn.font = NSFont.systemFont(ofSize: 16)
        return btn
    }
    
    private func getTag(for type: AnnotationType) -> Int {
        switch type {
        case .select: return 100
        case .rectangle: return 101
        case .ellipse: return 102
        case .line: return 103
        case .arrow: return 104
        case .pen: return 105
        case .text: return 106
        }
    }
    
    private func getTag(for action: ToolbarAction) -> Int {
        switch action {
        case .undo: return 201
        case .close: return 202
        case .save: return 203
        case .copy: return 204
        }
    }
    
    func selectTool(_ tool: AnnotationType) {
        let tag = getTag(for: tool)
        for btn in toolButtons {
            if btn.tag == tag {
                btn.isSelected = true
                selectedTool = tool
            } else {
                btn.isSelected = false
            }
        }
    }
    
    @objc private func toolButtonTapped(_ sender: HoverButton) {
        // Reset all tool buttons state
        for btn in toolButtons {
            btn.isSelected = false
        }
        
        // Highlight selected
        sender.isSelected = true
        
        // Notify delegate
        var type: AnnotationType?
        switch sender.tag {
        case 100: type = .select
        case 101: type = .rectangle
        case 102: type = .ellipse
        case 103: type = .line
        case 104: type = .arrow
        case 105: type = .pen
        case 106: type = .text
        default: break
        }
        
        if let type = type {
            selectedTool = type
            delegate?.didSelectTool(type)
        }
    }
    
    @objc private func actionButtonTapped(_ sender: NSButton) {
        var action: ToolbarAction?
        switch sender.tag {
        case 201: action = .undo
        case 202: action = .close
        case 203: action = .save
        case 204: action = .copy
        default: break
        }
        
        if let action = action {
            delegate?.didSelectAction(action)
        }
    }
}
