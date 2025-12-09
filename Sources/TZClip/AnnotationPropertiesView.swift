import Cocoa

@MainActor
protocol AnnotationPropertiesDelegate: AnyObject {
    func didChangeColor(_ color: NSColor)
    func didChangeLineWidth(_ width: CGFloat)
    func didChangeIsBold(_ isBold: Bool)
}

class ColorButton: NSButton {
    var color: NSColor = .red {
        didSet { needsDisplay = true }
    }
    
    var isSelected: Bool = false {
        didSet { needsDisplay = true }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        // Draw circle
        let path = NSBezierPath(ovalIn: bounds.insetBy(dx: 4, dy: 4))
        color.setFill()
        path.fill()
        
        // Draw selection ring
        if isSelected {
            let ringPath = NSBezierPath(ovalIn: bounds.insetBy(dx: 2, dy: 2))
            ringPath.lineWidth = 2
            NSColor.selectedControlColor.setStroke()
            ringPath.stroke()
        }
    }
}

class AnnotationPropertiesView: NSView {
    weak var delegate: AnnotationPropertiesDelegate?
    
    private var colorButtons: [ColorButton] = []
    private var widthButtons: [NSButton] = []
    private var boldButton: NSButton?
    private var sizeLabel: NSTextField?
    
    private let colors: [NSColor] = [.red, .yellow, .green, .blue, .white, .black]
    private let widths: [CGFloat] = [2.0, 4.0, 8.0]
    
    var selectedColor: NSColor = .red {
        didSet { updateColorSelection() }
    }
    
    var selectedWidth: CGFloat = 4.0 {
        didSet { updateWidthSelection() }
    }
    
    var isBold: Bool = false {
        didSet { updateBoldSelection() }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        setupControls()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.white.cgColor
        self.layer?.cornerRadius = 8
        self.layer?.shadowColor = NSColor.black.cgColor
        self.layer?.shadowOpacity = 0.3
        self.layer?.shadowOffset = CGSize(width: 0, height: -2)
        self.layer?.shadowRadius = 8
    }
    
    private func setupControls() {
        // We'll create all controls but hide/show them in configure(for:)
        
        let buttonSize: CGFloat = 24
        let spacing: CGFloat = 8
        let padding: CGFloat = 8
        let rowHeight: CGFloat = 32
        
        // --- Row 1: Width/Size Selection ---
        let row1Y: CGFloat = padding + rowHeight + 4
        
        let label = NSTextField(labelWithString: "大小")
        label.font = NSFont.systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.frame = CGRect(x: padding, y: row1Y + 4, width: 30, height: 16)
        addSubview(label)
        self.sizeLabel = label
        
        var xOffset = label.frame.maxX + spacing
        
        for (index, _) in widths.enumerated() {
            let btn = NSButton(frame: CGRect(x: xOffset, y: row1Y, width: buttonSize, height: buttonSize))
            btn.bezelStyle = .inline
            btn.isBordered = false
            btn.wantsLayer = true
            btn.layer?.cornerRadius = 4
            btn.tag = index
            btn.target = self
            btn.action = #selector(widthTapped(_:))
            
            let titles = ["S", "M", "L"]
            btn.title = titles[index]
            
            addSubview(btn)
            widthButtons.append(btn)
            xOffset += buttonSize + spacing
        }
        
        // Add Bold Button (initially hidden, shown for Text)
        let boldBtn = NSButton(frame: CGRect(x: xOffset, y: row1Y, width: buttonSize, height: buttonSize))
        boldBtn.bezelStyle = .inline
        boldBtn.isBordered = false
        boldBtn.wantsLayer = true
        boldBtn.layer?.cornerRadius = 4
        boldBtn.image = NSImage(systemSymbolName: "bold", accessibilityDescription: "Bold")
        boldBtn.target = self
        boldBtn.action = #selector(boldTapped(_:))
        addSubview(boldBtn)
        self.boldButton = boldBtn
        
        // --- Row 2: Color Selection ---
        let row2Y: CGFloat = padding
        
        let colorLabel = NSTextField(labelWithString: "颜色")
        colorLabel.font = NSFont.systemFont(ofSize: 12)
        colorLabel.textColor = .secondaryLabelColor
        colorLabel.frame = CGRect(x: padding, y: row2Y + 4, width: 30, height: 16)
        addSubview(colorLabel)
        
        xOffset = colorLabel.frame.maxX + spacing
        
        for color in colors {
            let btn = ColorButton(frame: CGRect(x: xOffset, y: row2Y, width: buttonSize, height: buttonSize))
            btn.color = color
            btn.target = self
            btn.action = #selector(colorTapped(_:))
            btn.isBordered = false
            btn.title = ""
            addSubview(btn)
            colorButtons.append(btn)
            xOffset += buttonSize + spacing
        }
        
        // Default Configuration
        configure(for: .rectangle) // Default to generic shape
    }
    
    // MARK: - Configuration
    
    func configure(for type: AnnotationType) {
        let padding: CGFloat = 8
        let rowHeight: CGFloat = 32
        
        // Layout constants
        let row1Y: CGFloat = padding + rowHeight + 4
        var xOffset: CGFloat = (sizeLabel?.frame.maxX ?? 38) + 8
        let buttonSize: CGFloat = 24
        let spacing: CGFloat = 8
        
        // 1. Configure Row 1 (Size/Style)
        if type == .text {
            // Text Mode: Show Font Size (reuse width buttons) and Bold
            sizeLabel?.stringValue = "字号"
            
            // Show S/M/L buttons
            for btn in widthButtons {
                btn.isHidden = false
                btn.frame.origin.x = xOffset
                xOffset += buttonSize + spacing
            }
            
            // Show Bold button
            boldButton?.isHidden = false
            boldButton?.frame.origin.x = xOffset
            xOffset += buttonSize + spacing
            
        } else {
            // Shape Mode: Show Line Width
            sizeLabel?.stringValue = "粗细"
            
            // Show S/M/L buttons
            for btn in widthButtons {
                btn.isHidden = false
                btn.frame.origin.x = xOffset
                xOffset += buttonSize + spacing
            }
            
            // Hide Bold button
            boldButton?.isHidden = true
        }
        
        // 2. Adjust Frame Width
        // Find max X between Row 1 and Row 2
        // Row 2 (Color) is constant width usually
        // Color row width approx: 8 + 30 + 8 + (24+8)*6 = 46 + 192 = 238
        // Row 1 width depends on buttons shown
        
        let row1Width = xOffset + padding
        // Recalculate color row width
        let colorRowWidth = 8.0 + 30.0 + 8.0 + CGFloat(colors.count) * (24.0 + 8.0) + 8.0
        
        let totalWidth = max(row1Width, colorRowWidth)
        let totalHeight = row1Y + rowHeight + padding
        
        var frame = self.frame
        frame.size.width = totalWidth
        frame.size.height = totalHeight
        self.frame = frame
        
        updateColorSelection()
        updateWidthSelection()
        updateBoldSelection()
    }
    
    private func updateColorSelection() {
        for btn in colorButtons {
            btn.isSelected = (btn.color == selectedColor)
        }
    }
    
    private func updateWidthSelection() {
        for (index, btn) in widthButtons.enumerated() {
            let width = widths[index]
            if width == selectedWidth {
                btn.layer?.backgroundColor = NSColor.selectedControlColor.withAlphaComponent(0.2).cgColor
            } else {
                btn.layer?.backgroundColor = NSColor.clear.cgColor
            }
        }
    }
    
    private func updateBoldSelection() {
        if isBold {
            boldButton?.layer?.backgroundColor = NSColor.selectedControlColor.withAlphaComponent(0.2).cgColor
        } else {
            boldButton?.layer?.backgroundColor = NSColor.clear.cgColor
        }
    }
    
    @objc private func colorTapped(_ sender: ColorButton) {
        selectedColor = sender.color
        delegate?.didChangeColor(selectedColor)
    }
    
    @objc private func widthTapped(_ sender: NSButton) {
        let width = widths[sender.tag]
        selectedWidth = width
        delegate?.didChangeLineWidth(width)
    }
    
    @objc private func boldTapped(_ sender: NSButton) {
        isBold.toggle()
        delegate?.didChangeIsBold(isBold)
    }
}
