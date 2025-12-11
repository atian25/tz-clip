import Cocoa

@MainActor
    protocol AnnotationPropertiesDelegate: AnyObject {
        func didChangeColor(_ color: NSColor)
        func didChangeLineWidth(_ width: CGFloat)
        func didChangeIsBold(_ isBold: Bool)
        func didChangeIsFilled(_ isFilled: Bool)
        func didChangeIsRounded(_ isRounded: Bool)
        func didChangeOutlineStyle(_ style: Int)
        func didChangeOutlineColor(_ color: NSColor)
        func didChangeFontName(_ name: String)
        func didChangeTextBackgroundColor(_ color: NSColor?)
    }

class ColorButton: NSButton {
    var color: NSColor = .red {
        didSet { needsDisplay = true }
    }
    
    var isSelected: Bool = false {
        didSet { needsDisplay = true }
    }
    
    var isCustom: Bool = false {
        didSet { needsDisplay = true }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        // Draw circle
        let path = NSBezierPath(ovalIn: bounds.insetBy(dx: 4, dy: 4))
        
        if isCustom {
            // Draw gradient/spectrum for custom color button
            // Simple approach: Draw a gradient or an image
            NSGraphicsContext.saveGraphicsState()
            path.addClip()
            let gradient = NSGradient(colors: [.red, .yellow, .green, .cyan, .blue, .magenta])
            gradient?.draw(in: bounds, angle: 45)
            NSGraphicsContext.restoreGraphicsState()
        } else {
            color.setFill()
            path.fill()
        }
        
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
    private var sizeSlider: NSSlider?
    private var sizeValueLabel: NSTextField?
    private var opacitySlider: NSSlider?
    private var opacityValueLabel: NSTextField?
    private var colorButtons: [ColorButton] = []
    private var boldButton: NSButton?
    private var fillCheckbox: NSButton?
    private var roundedCheckbox: NSButton?
    
    // Text specific controls
    private var outlineStylePopup: NSPopUpButton?
    private var outlineColorWell: NSColorWell?
    private var fontPopup: NSPopUpButton?
    private var backgroundPopup: NSPopUpButton?
    
    // State
    private let colors: [NSColor] = [.red, .magenta, .blue, .yellow, .green] // 5 fixed colors + 1 custom
    private var currentType: AnnotationType = .rectangle
    
    var selectedColor: NSColor = .red {
        didSet {
            updateUIFromSelection()
        }
    }
    
    var selectedWidth: CGFloat = 4.0 {
        didSet {
            updateUIFromSelection()
        }
    }
    
    var isBold: Bool = false {
        didSet {
            // Checkbox logic for bold? Or button?
            // If Text, we might reuse checkbox or keep button?
            // User screenshot shows checkboxes for Rect.
            // Let's assume Text uses "Bold" checkbox if we unify.
            // Or keep boldButton for Text.
            boldButton?.state = isBold ? .on : .off
        }
    }
    
    var isFilled: Bool = false {
        didSet {
            fillCheckbox?.state = isFilled ? .on : .off
        }
    }
    
    var isRounded: Bool = false {
        didSet {
            roundedCheckbox?.state = isRounded ? .on : .off
        }
    }
    
    var outlineStyle: Int = 0 {
        didSet {
            outlineStylePopup?.selectItem(at: outlineStyle)
        }
    }
    
    var outlineColor: NSColor = .black {
        didSet {
            outlineColorWell?.color = outlineColor
        }
    }
    
    var fontName: String = "系统默认" {
        didSet {
            if let item = fontPopup?.item(withTitle: fontName) {
                fontPopup?.select(item)
            } else {
                fontPopup?.selectItem(at: 0)
            }
        }
    }

    var textBackgroundColor: NSColor? = nil {
        didSet {
            updateBackgroundPopupSelection()
        }
    }
    
    // Internal state to decouple slider from color picking
    private var currentOpacity: CGFloat = 1.0
    private var baseColor: NSColor = .red
    
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
        // --- Layout Constants ---
        // Reference screenshot layout
        
        let padding: CGFloat = 8
        let leftSectionWidth: CGFloat = 140 // Size/Opacity (避免被压缩)
        let middleSectionWidth: CGFloat = 72 // Colors (3 cols)
        let rightSectionWidth: CGFloat = 112 // 右侧更紧凑，避免越界
        let height: CGFloat = 64
        
        self.frame.size = CGSize(width: padding + leftSectionWidth + padding + middleSectionWidth + padding + rightSectionWidth + padding, height: height)
        
        // --- Left Section: Sliders ---
        let rowHeight: CGFloat = 20
        let rowSpacing: CGFloat = 8
        let row1Y = height - padding - rowHeight // Top row
        let row2Y = row1Y - rowHeight - rowSpacing // Bottom row
        
        // Font for labels
        let labelFont = NSFont.systemFont(ofSize: 11)
        let valueFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        
        // Size Slider
        let sizeIcon = NSTextField(labelWithString: "大小")
        sizeIcon.font = labelFont
        sizeIcon.frame = CGRect(x: padding, y: row1Y, width: 30, height: 16)
        sizeIcon.textColor = .secondaryLabelColor
        addSubview(sizeIcon)
        
        let sSlider = NSSlider(value: 4.0, minValue: 1.0, maxValue: 20.0, target: self, action: #selector(sizeSliderChanged(_:)))
        sSlider.frame = CGRect(x: padding + 32, y: row1Y, width: 70, height: 16)
        sSlider.controlSize = .small
        addSubview(sSlider)
        self.sizeSlider = sSlider
        
        let sLabel = NSTextField(labelWithString: "4")
        sLabel.frame = CGRect(x: sSlider.frame.maxX + 4, y: row1Y, width: 24, height: 16)
        sLabel.font = valueFont
        sLabel.textColor = .secondaryLabelColor
        addSubview(sLabel)
        self.sizeValueLabel = sLabel
        
        // Opacity Slider
        let opIcon = NSTextField(labelWithString: "不透明度")
        opIcon.font = labelFont
        opIcon.frame = CGRect(x: padding, y: row2Y, width: 48, height: 16)
        opIcon.textColor = .secondaryLabelColor
        addSubview(opIcon)
        
        let oSlider = NSSlider(value: 100.0, minValue: 0.0, maxValue: 100.0, target: self, action: #selector(opacitySliderChanged(_:)))
        oSlider.frame = CGRect(x: padding + 50, y: row2Y, width: 52, height: 16)
        oSlider.controlSize = .small
        addSubview(oSlider)
        self.opacitySlider = oSlider
        
        let oLabel = NSTextField(labelWithString: "100")
        oLabel.frame = CGRect(x: oSlider.frame.maxX + 4, y: row2Y, width: 24, height: 16)
        oLabel.font = valueFont
        oLabel.textColor = .secondaryLabelColor
        addSubview(oLabel)
        self.opacityValueLabel = oLabel
        
        // --- Separator 1 ---
        let sep1 = NSView(frame: CGRect(x: padding + leftSectionWidth + padding/2, y: padding, width: 1, height: height - padding*2))
        sep1.wantsLayer = true
        sep1.layer?.backgroundColor = NSColor.separatorColor.cgColor
        addSubview(sep1)
        
        // --- Middle Section: Colors ---
        // 6 Colors, 3 Cols x 2 Rows
        let colorSize: CGFloat = 18 // Larger dots as per screenshot
        let colorSpacing: CGFloat = 8
        let colorStartX = sep1.frame.maxX + padding/2
        
        // 左对齐颜色矩阵
        let colorsPaddingX: CGFloat = 0
        
        // Center color block vertically
        // Content height = 18 + 8 + 18 = 44
        // View height 64. Margin = (64-44)/2 = 10.
        let colorBlockY = (height - (colorSize * 2 + colorSpacing)) / 2
        
        for (index, color) in colors.enumerated() {
            let row = index < 3 ? 0 : 1
            let col = index < 3 ? index : index - 3
            
            let x = colorStartX + colorsPaddingX + CGFloat(col) * (colorSize + colorSpacing)
            let y = row == 0 ? (colorBlockY + colorSize + colorSpacing) : colorBlockY
            
            let btn = ColorButton(frame: CGRect(x: x, y: y, width: colorSize, height: colorSize))
            btn.color = color
            btn.target = self
            btn.action = #selector(colorTapped(_:))
            btn.isBordered = false
            btn.title = ""
            addSubview(btn)
            colorButtons.append(btn)
        }
        
        // Custom Color Button (Last spot: Row 1, Col 2 -> Index 5)
        let customX = colorStartX + colorsPaddingX + 2 * (colorSize + colorSpacing)
        let customY = colorBlockY // Bottom row
        
        let customBtn = ColorButton(frame: CGRect(x: customX, y: customY, width: colorSize, height: colorSize))
        customBtn.color = NSColor.systemTeal // Placeholder, will be rainbow or wheel
        customBtn.isCustom = true // We need to add this property
        customBtn.target = self
        customBtn.action = #selector(customColorTapped(_:))
        customBtn.isBordered = false
        customBtn.title = ""
        addSubview(customBtn)
        colorButtons.append(customBtn)
        
        // --- Separator 2 ---
        let sep2 = NSView(frame: CGRect(x: colorStartX + middleSectionWidth, y: padding, width: 1, height: height - padding*2))
        sep2.wantsLayer = true
        sep2.layer?.backgroundColor = NSColor.separatorColor.cgColor
        addSubview(sep2)
        
        // --- Right Section: Checkboxes ---
        // Add slightly more padding after separator
        let checkStartX = sep2.frame.maxX + 10
        
        // Row 1: Fill (for shapes), Bold (for text), Background (for text)
        let fillCheck = NSButton(checkboxWithTitle: "实心", target: self, action: #selector(fillTapped(_:)))
        fillCheck.frame = CGRect(x: checkStartX, y: row1Y, width: 60, height: 16)
        fillCheck.font = labelFont
        fillCheck.controlSize = .small
        addSubview(fillCheck)
        self.fillCheckbox = fillCheck

        let boldCheck = NSButton(checkboxWithTitle: "粗体", target: self, action: #selector(boldTapped(_:)))
        boldCheck.frame = CGRect(x: checkStartX, y: row1Y - 1, width: 48, height: 18)
        boldCheck.font = labelFont
        boldCheck.controlSize = .small
        boldCheck.isHidden = true
        addSubview(boldCheck)
        self.boldButton = boldCheck

        let bgPop = NSPopUpButton(frame: CGRect(x: checkStartX + 56, y: row1Y - 1, width: 68, height: 18), pullsDown: false)
        bgPop.addItems(withTitles: ["透明", "白", "黑", "黄", "蓝", "红"])
        bgPop.controlSize = .small
        bgPop.font = labelFont
        bgPop.target = self
        bgPop.action = #selector(backgroundChanged(_:))
        bgPop.isHidden = true
        addSubview(bgPop)
        self.backgroundPopup = bgPop

        // Row 2: Rounded (for rectangle), Font popup (for text)
        let roundCheck = NSButton(checkboxWithTitle: "圆角", target: self, action: #selector(roundedTapped(_:)))
        roundCheck.frame = CGRect(x: checkStartX, y: row2Y, width: 60, height: 16)
        roundCheck.font = labelFont
        roundCheck.controlSize = .small
        addSubview(roundCheck)
        self.roundedCheckbox = roundCheck
        
        // 文本描边样式与颜色：按最新规范移除（不创建控件）
        self.outlineStylePopup = nil
        self.outlineColorWell = nil
        
        // Font Popup (Bottom Row)
        let fontPop = NSPopUpButton(frame: CGRect(x: checkStartX, y: row2Y - 1, width: 100, height: 18), pullsDown: false)
        fontPop.addItem(withTitle: "系统默认")
        // Add common fonts (含中文)
        let commonFonts = [
            "Helvetica", "Arial", "Times New Roman", "Courier New", "Verdana",
            "PingFang SC", "苹方-简", "SimSun", "宋体", "SimHei", "黑体",
            "Microsoft YaHei", "微软雅黑", "Source Han Sans SC", "思源黑体"
        ]
        fontPop.addItems(withTitles: commonFonts)
        fontPop.controlSize = .small
        fontPop.font = labelFont
        fontPop.target = self
        fontPop.action = #selector(fontChanged(_:))
        fontPop.isHidden = true
        addSubview(fontPop)
        self.fontPopup = fontPop
        
        // Initial State
        updateUIFromSelection()
    }
    
    // MARK: - Configuration
    
    func configure(for type: AnnotationType) {
        self.currentType = type
        
        // Recalculate layout constants needed for dynamic adjustments
        let height: CGFloat = 64
        let padding: CGFloat = 8
        let rowHeight: CGFloat = 20
        let rowSpacing: CGFloat = 8
        let row1Y = height - padding - rowHeight
        let row2Y = row1Y - rowHeight - rowSpacing
        // checkStartX matches the X of fillCheckbox
        let checkStartX = fillCheckbox?.frame.minX ?? 238
        
        // Update Size Slider Range
        if type == .text || type == .counter {
            sizeSlider?.minValue = 10.0
            sizeSlider?.maxValue = 100.0
            sizeValueLabel?.stringValue = "\(Int(selectedWidth))pt"
        } else {
            sizeSlider?.minValue = 1.0
            sizeSlider?.maxValue = 20.0
            sizeValueLabel?.stringValue = "\(Int(selectedWidth))px"
        }
        
        // Toggle Bold Button (Text or Counter)
        let isTextOrCounter = (type == .text || type == .counter)
        boldButton?.isHidden = !isTextOrCounter
        backgroundPopup?.isHidden = !isTextOrCounter || (type == .counter)
        
        // Toggle Checkboxes (Rectangle/Ellipse)
        let isShape = (type == .rectangle || type == .ellipse)
        fillCheckbox?.isHidden = !isShape
        
        // Rounded only for Rectangle
        roundedCheckbox?.isHidden = (type != .rectangle)
        
        // Text/Counter Specific Controls
        // 最新规范：文字工具不显示描边样式/颜色
        outlineStylePopup?.isHidden = true
        outlineColorWell?.isHidden = true
        fontPopup?.isHidden = !isTextOrCounter
        
        if isTextOrCounter {
            // Re-layout for Text/Counter Mode（去除描边控件）
            
            // Row1 additions for Text: Bold + Background
            boldButton?.frame.origin = CGPoint(x: checkStartX, y: row1Y - 1)
            backgroundPopup?.frame.origin = CGPoint(x: checkStartX + 56, y: row1Y - 1)
            
            // Font Popup (Row2)
            fontPopup?.frame.size.width = 100
            fontPopup?.frame.origin = CGPoint(x: checkStartX, y: row2Y - 1)
            boldButton?.isHidden = false
        } else {
            // Reset logic for other tools? Bold is hidden anyway.
        }
        sizeSlider?.doubleValue = selectedWidth
    }
    
    private func updateUIFromSelection() {
        // Extract Opacity & Base Color
        currentOpacity = selectedColor.alphaComponent
        baseColor = selectedColor.withAlphaComponent(1.0)
        
        // Update Sliders
        sizeSlider?.doubleValue = selectedWidth
        if currentType == .text || currentType == .counter {
            sizeValueLabel?.stringValue = "\(Int(selectedWidth))pt"
        } else {
            sizeValueLabel?.stringValue = "\(Int(selectedWidth))px"
        }
        
        opacitySlider?.doubleValue = Double(currentOpacity * 100)
        opacityValueLabel?.stringValue = "\(Int(currentOpacity * 100))"
        
        // Update Color Buttons (compare base color)
        // We compare RGB values to handle slight float diffs
        for btn in colorButtons {
            // If custom button, don't auto-select unless logic requires (for now just clear selection if custom)
            if btn.isCustom {
                // If current color is not in preset, select custom?
                // Let's keep it simple: if no preset matches, select custom.
                let anyMatch = colorButtons.dropLast().contains(where: { areColorsSimilar($0.color, baseColor) })
                btn.isSelected = !anyMatch
            } else {
                btn.isSelected = areColorsSimilar(btn.color, baseColor)
            }
        }
        
        // Update Style Buttons
        if isBold {
            boldButton?.state = .on
        } else {
            boldButton?.state = .off
        }
        
        if isFilled {
            fillCheckbox?.state = .on
        } else {
            fillCheckbox?.state = .off
        }
        
        if isRounded {
            roundedCheckbox?.state = .on
        } else {
            roundedCheckbox?.state = .off
        }
        
        // Update Text Controls（去除描边控件）
        if let item = fontPopup?.item(withTitle: fontName) {
            fontPopup?.select(item)
        }
        updateBackgroundPopupSelection()
    }

    private func updateBackgroundPopupSelection() {
        guard let bgPop = backgroundPopup else { return }
        let title: String
        if let c = textBackgroundColor {
            // Map to titles
            if areColorsSimilar(c, .white) { title = "白" }
            else if areColorsSimilar(c, .black) { title = "黑" }
            else if areColorsSimilar(c, .yellow) { title = "黄" }
            else if areColorsSimilar(c, .blue) { title = "蓝" }
            else if areColorsSimilar(c, .red) { title = "红" }
            else { title = "透明" }
        } else {
            title = "透明"
        }
        bgPop.selectItem(withTitle: title)
    }
    
    private func areColorsSimilar(_ c1: NSColor, _ c2: NSColor) -> Bool {
        guard let rc1 = c1.usingColorSpace(.sRGB), let rc2 = c2.usingColorSpace(.sRGB) else { return false }
        return abs(rc1.redComponent - rc2.redComponent) < 0.01 &&
               abs(rc1.greenComponent - rc2.greenComponent) < 0.01 &&
               abs(rc1.blueComponent - rc2.blueComponent) < 0.01
    }
    
    // MARK: - Actions
    
    @objc private func sizeSliderChanged(_ sender: NSSlider) {
        selectedWidth = CGFloat(sender.doubleValue)
        if currentType == .text || currentType == .counter {
            sizeValueLabel?.stringValue = "\(Int(selectedWidth))pt"
        } else {
            sizeValueLabel?.stringValue = "\(Int(selectedWidth))px"
        }
        delegate?.didChangeLineWidth(selectedWidth)
    }
    
    @objc private func opacitySliderChanged(_ sender: NSSlider) {
        currentOpacity = CGFloat(sender.doubleValue / 100.0)
        opacityValueLabel?.stringValue = "\(Int(sender.doubleValue))"
        
        // Reconstruct effective color
        selectedColor = baseColor.withAlphaComponent(currentOpacity)
        delegate?.didChangeColor(selectedColor)
    }
    
    @objc private func colorTapped(_ sender: ColorButton) {
        baseColor = sender.color
        // Update selection UI immediately for feedback
        for btn in colorButtons {
            btn.isSelected = (btn == sender)
        }
        
        // Apply current opacity
        selectedColor = baseColor.withAlphaComponent(currentOpacity)
        delegate?.didChangeColor(selectedColor)
    }
    
    @objc private func boldTapped(_ sender: NSButton) {
        isBold.toggle()
        delegate?.didChangeIsBold(isBold)
    }

    @objc private func backgroundChanged(_ sender: NSPopUpButton) {
        let title = sender.titleOfSelectedItem ?? "透明"
        switch title {
        case "白": textBackgroundColor = .white
        case "黑": textBackgroundColor = .black
        case "黄": textBackgroundColor = .yellow
        case "蓝": textBackgroundColor = .blue
        case "红": textBackgroundColor = .red
        default:
            textBackgroundColor = nil
        }
        delegate?.didChangeTextBackgroundColor(textBackgroundColor)
    }

    @objc private func fillTapped(_ sender: NSButton) {
        isFilled.toggle()
        delegate?.didChangeIsFilled(isFilled)
    }
    
    @objc private func roundedTapped(_ sender: NSButton) {
        isRounded.toggle()
        delegate?.didChangeIsRounded(isRounded)
    }
    
    @objc private func customColorTapped(_ sender: ColorButton) {
        // Show Color Panel
        let panel = NSColorPanel.shared
        panel.setTarget(self)
        panel.setAction(#selector(colorPanelChanged(_:)))
        panel.color = baseColor
        panel.orderFront(self)
        
        // Update selection to custom button
        for btn in colorButtons {
            btn.isSelected = (btn == sender)
        }
    }
    
    @objc private func colorPanelChanged(_ sender: NSColorPanel) {
        baseColor = sender.color
        selectedColor = baseColor.withAlphaComponent(currentOpacity)
        delegate?.didChangeColor(selectedColor)
    }
    
    @objc private func outlineStyleChanged(_ sender: NSPopUpButton) {
        outlineStyle = sender.indexOfSelectedItem
        delegate?.didChangeOutlineStyle(outlineStyle)
    }
    
    @objc private func outlineColorChanged(_ sender: NSColorWell) {
        outlineColor = sender.color
        delegate?.didChangeOutlineColor(outlineColor)
    }
    
    @objc private func fontChanged(_ sender: NSPopUpButton) {
        let title = sender.titleOfSelectedItem ?? "系统默认"
        fontName = (title == "系统默认") ? "System Default" : title
        delegate?.didChangeFontName(fontName)
    }
}
