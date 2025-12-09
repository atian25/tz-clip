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
    
    // UI Components
    private var widthSlider: NSSlider?
    private var widthValueLabel: NSTextField?
    
    private var opacitySlider: NSSlider?
    private var opacityValueLabel: NSTextField?
    
    private var boldButton: NSButton?
    private var colorButtons: [ColorButton] = []
    private var colorPanelButton: NSButton?
    
    // Data
    private let colors: [NSColor] = [.red, .orange, .yellow, .green, .blue, .purple, .black, .white]
    
    var selectedColor: NSColor = .red {
        didSet { updateColorUI() }
    }
    
    var selectedWidth: CGFloat = 4.0 {
        didSet { updateWidthUI() }
    }
    
    var isBold: Bool = false {
        didSet { updateBoldUI() }
    }
    
    // State
    private var currentType: AnnotationType = .rectangle
    
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
        self.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor // Use system window bg
        self.layer?.cornerRadius = 8
        self.layer?.shadowColor = NSColor.black.cgColor
        self.layer?.shadowOpacity = 0.2
        self.layer?.shadowOffset = CGSize(width: 0, height: -2)
        self.layer?.shadowRadius = 8
        self.layer?.borderColor = NSColor.separatorColor.cgColor
        self.layer?.borderWidth = 1.0
    }
    
    private func setupControls() {
        let padding: CGFloat = 12
        let rowHeight: CGFloat = 24
        let rowSpacing: CGFloat = 8
        let labelWidth: CGFloat = 40
        let valueLabelWidth: CGFloat = 35
        let sliderWidth: CGFloat = 120
        
        var currentY: CGFloat = padding
        
        // --- Row 1: Width/Size ---
        let widthLabel = createLabel(text: "大小", frame: CGRect(x: padding, y: currentY, width: labelWidth, height: rowHeight))
        addSubview(widthLabel)
        
        let wSlider = NSSlider(value: 4.0, minValue: 1.0, maxValue: 20.0, target: self, action: #selector(widthSliderChanged(_:)))
        wSlider.frame = CGRect(x: widthLabel.frame.maxX, y: currentY, width: sliderWidth, height: rowHeight)
        addSubview(wSlider)
        self.widthSlider = wSlider
        
        let wValue = createLabel(text: "4px", frame: CGRect(x: wSlider.frame.maxX + 4, y: currentY, width: valueLabelWidth, height: rowHeight))
        addSubview(wValue)
        self.widthValueLabel = wValue
        
        // Bold Button (Initially hidden, shared row with Width or separate?)
        // Let's put Bold button next to width value if space permits, or replace width slider for text.
        let bBtn = NSButton(frame: CGRect(x: wValue.frame.maxX + 4, y: currentY, width: 24, height: 24))
        bBtn.bezelStyle = .inline
        bBtn.isBordered = false
        bBtn.image = NSImage(systemSymbolName: "bold", accessibilityDescription: "Bold")
        bBtn.target = self
        bBtn.action = #selector(boldTapped(_:))
        bBtn.isHidden = true // Default hidden
        addSubview(bBtn)
        self.boldButton = bBtn
        
        currentY += rowHeight + rowSpacing
        
        // --- Row 2: Opacity ---
        let opacityLabel = createLabel(text: "透明", frame: CGRect(x: padding, y: currentY, width: labelWidth, height: rowHeight))
        addSubview(opacityLabel)
        
        let oSlider = NSSlider(value: 100, minValue: 0, maxValue: 100, target: self, action: #selector(opacitySliderChanged(_:)))
        oSlider.frame = CGRect(x: opacityLabel.frame.maxX, y: currentY, width: sliderWidth, height: rowHeight)
        addSubview(oSlider)
        self.opacitySlider = oSlider
        
        let oValue = createLabel(text: "100%", frame: CGRect(x: oSlider.frame.maxX + 4, y: currentY, width: valueLabelWidth, height: rowHeight))
        addSubview(oValue)
        self.opacityValueLabel = oValue
        
        currentY += rowHeight + rowSpacing
        
        // --- Row 3: Colors ---
        let colorLabel = createLabel(text: "颜色", frame: CGRect(x: padding, y: currentY, width: labelWidth, height: rowHeight))
        addSubview(colorLabel)
        
        var xOffset = colorLabel.frame.maxX
        let colorBtnSize: CGFloat = 24
        let colorSpacing: CGFloat = 6
        
        for color in colors {
            let btn = ColorButton(frame: CGRect(x: xOffset, y: currentY, width: colorBtnSize, height: colorBtnSize))
            btn.color = color
            btn.target = self
            btn.action = #selector(colorTapped(_:))
            btn.isBordered = false
            btn.title = ""
            addSubview(btn)
            colorButtons.append(btn)
            xOffset += colorBtnSize + colorSpacing
        }
        
        // Color Panel Button
        let cpBtn = NSButton(frame: CGRect(x: xOffset, y: currentY, width: colorBtnSize, height: colorBtnSize))
        cpBtn.bezelStyle = .inline
        cpBtn.isBordered = false
        cpBtn.image = NSImage(systemSymbolName: "paintpalette", accessibilityDescription: "More Colors")
        cpBtn.target = self
        cpBtn.action = #selector(colorPanelTapped(_:))
        addSubview(cpBtn)
        self.colorPanelButton = cpBtn
        
        // Initial Configuration
        configure(for: .rectangle)
    }
    
    private func createLabel(text: String, frame: CGRect) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.frame = frame
        label.font = NSFont.systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.alignment = .left
        return label
    }
    
    // MARK: - Configuration
    
    func configure(for type: AnnotationType) {
        self.currentType = type
        
        // 1. Visibility Logic
        let isText = (type == .text)
        
        // Width Slider: Show for all except maybe Text (Text uses size for font size, which is similar)
        // Actually, for text, "Line Width" -> "Font Size"
        // For text, we might want to hide Opacity if not supported, but Text supports color alpha.
        
        if isText {
            // Reconfigure Width Slider as Font Size
            widthSlider?.minValue = 8
            widthSlider?.maxValue = 72
            boldButton?.isHidden = false
        } else {
            widthSlider?.minValue = 1
            widthSlider?.maxValue = 20
            boldButton?.isHidden = true
        }
        
        // Adjust Frame Size
        // Calculate required width and height
        let padding: CGFloat = 12
        let rowHeight: CGFloat = 24
        let rowSpacing: CGFloat = 8
        
        // Color row width
        let colorRowWidth = 40 + CGFloat(colors.count + 1) * (24 + 6) + padding * 2
        // Slider row width
        let sliderRowWidth = 40 + 120 + 4 + 35 + padding * 2 + (isText ? 28 : 0)
        
        let totalWidth = max(colorRowWidth, sliderRowWidth)
        let totalHeight = padding + (rowHeight + rowSpacing) * 3 // 3 Rows
        
        // Flip coordinates for NSView (0,0 is bottom-left)
        // But we positioned from top-down logic in setupControls? 
        // Wait, Cocoa coords are bottom-up. My setupControls logic with `currentY += ...` works if I start from top?
        // Actually, in setupControls, I started `currentY = padding`. In Cocoa, that's near bottom.
        // I need to reposition controls based on final height.
        
        // Let's reflow controls
        var y = totalHeight - padding - rowHeight
        
        // Row 1: Width
        widthSlider?.superview?.subviews.forEach { v in
            if v == widthSlider || v == widthValueLabel || v == boldButton || (v as? NSTextField)?.stringValue == "大小" {
                v.frame.origin.y = y
            }
        }
        
        y -= (rowHeight + rowSpacing)
        
        // Row 2: Opacity
        opacitySlider?.superview?.subviews.forEach { v in
            if v == opacitySlider || v == opacityValueLabel || (v as? NSTextField)?.stringValue == "透明" {
                v.frame.origin.y = y
            }
        }
        
        y -= (rowHeight + rowSpacing)
        
        // Row 3: Colors
        colorButtons.forEach { $0.frame.origin.y = y }
        colorPanelButton?.frame.origin.y = y
        self.subviews.compactMap { $0 as? NSTextField }.first(where: { $0.stringValue == "颜色" })?.frame.origin.y = y
        
        
        var frame = self.frame
        frame.size = CGSize(width: totalWidth, height: totalHeight)
        self.frame = frame
        
        updateWidthUI()
        updateColorUI()
        updateBoldUI()
    }
    
    // MARK: - UI Updates
    
    private func updateColorUI() {
        // Update slider based on current color alpha
        let alpha = selectedColor.alphaComponent
        opacitySlider?.doubleValue = Double(alpha * 100)
        opacityValueLabel?.stringValue = "\(Int(alpha * 100))%"
        
        // Update selection state of color buttons
        // We compare RGB values, ignoring alpha for "selection" visual
        for btn in colorButtons {
            btn.isSelected = btn.color.usingColorSpace(.sRGB)?.redComponent == selectedColor.usingColorSpace(.sRGB)?.redComponent &&
                             btn.color.usingColorSpace(.sRGB)?.greenComponent == selectedColor.usingColorSpace(.sRGB)?.greenComponent &&
                             btn.color.usingColorSpace(.sRGB)?.blueComponent == selectedColor.usingColorSpace(.sRGB)?.blueComponent
        }
    }
    
    private func updateWidthUI() {
        widthSlider?.doubleValue = Double(selectedWidth)
        widthValueLabel?.stringValue = String(format: "%.0fpx", selectedWidth)
    }
    
    private func updateBoldUI() {
        if isBold {
            boldButton?.contentTintColor = .selectedControlColor
            boldButton?.layer?.backgroundColor = NSColor.selectedControlColor.withAlphaComponent(0.1).cgColor
            boldButton?.layer?.cornerRadius = 4
        } else {
            boldButton?.contentTintColor = .labelColor
            boldButton?.layer?.backgroundColor = nil
        }
    }
    
    // MARK: - Actions
    
    @objc private func widthSliderChanged(_ sender: NSSlider) {
        selectedWidth = CGFloat(sender.doubleValue)
        widthValueLabel?.stringValue = String(format: "%.0fpx", selectedWidth)
        delegate?.didChangeLineWidth(selectedWidth)
    }
    
    @objc private func opacitySliderChanged(_ sender: NSSlider) {
        let alpha = CGFloat(sender.doubleValue / 100.0)
        opacityValueLabel?.stringValue = "\(Int(sender.doubleValue))%"
        
        // Update selected color with new alpha
        let newColor = selectedColor.withAlphaComponent(alpha)
        // We update the backing var directly to avoid triggering didSet loop if handled poorly, 
        // but here didSet calls updateColorUI which updates slider... safe.
        // Actually better to just notify delegate and update local.
        
        self.selectedColor = newColor
        delegate?.didChangeColor(newColor)
    }
    
    @objc private func colorTapped(_ sender: ColorButton) {
        // Keep current alpha
        let currentAlpha = opacitySlider?.doubleValue ?? 100.0
        let alpha = CGFloat(currentAlpha / 100.0)
        
        let newBase = sender.color
        let newColor = newBase.withAlphaComponent(alpha)
        
        selectedColor = newColor
        delegate?.didChangeColor(newColor)
    }
    
    @objc private func colorPanelTapped(_ sender: NSButton) {
        let panel = NSColorPanel.shared
        panel.setTarget(self)
        panel.setAction(#selector(colorPanelColorChanged(_:)))
        panel.color = selectedColor
        panel.orderFront(self)
    }
    
    @objc private func colorPanelColorChanged(_ sender: NSColorPanel) {
        selectedColor = sender.color
        delegate?.didChangeColor(selectedColor)
    }
    
    @objc private func boldTapped(_ sender: NSButton) {
        isBold.toggle()
        delegate?.didChangeIsBold(isBold)
    }
}
