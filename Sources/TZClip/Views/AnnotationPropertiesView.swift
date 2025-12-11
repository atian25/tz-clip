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
    var color: NSColor = .red { didSet { needsDisplay = true } }
    var isSelected: Bool = false { didSet { needsDisplay = true } }
    var isCustom: Bool = false { didSet { needsDisplay = true } }
    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(ovalIn: bounds.insetBy(dx: 4, dy: 4))
        if isCustom {
            NSGraphicsContext.saveGraphicsState()
            path.addClip()
            let gradient = NSGradient(colors: [.red, .yellow, .green, .cyan, .blue, .magenta])
            gradient?.draw(in: bounds, angle: 45)
            NSGraphicsContext.restoreGraphicsState()
        } else {
            color.setFill()
            path.fill()
        }
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
    private var sizeSlider: NSSlider?
    private var sizeValueLabel: NSTextField?
    private var opacitySlider: NSSlider?
    private var opacityValueLabel: NSTextField?
    private var colorButtons: [ColorButton] = []
    private var boldButton: NSButton?
    private var fillCheckbox: NSButton?
    private var roundedCheckbox: NSButton?
    private var outlineStylePopup: NSPopUpButton?
    private var outlineColorWell: NSColorWell?
    private var fontPopup: NSPopUpButton?
    private var backgroundPopup: NSPopUpButton?
    private var backgroundLabel: NSTextField?
    private let colors: [NSColor] = [.red, .magenta, .blue, .yellow, .green]
    private var currentType: AnnotationType = .rectangle
    var selectedColor: NSColor = .red { didSet { updateUIFromSelection() } }
    var selectedWidth: CGFloat = 4.0 { didSet { updateUIFromSelection() } }
    var isBold: Bool = false { didSet { boldButton?.state = isBold ? .on : .off } }
    var isFilled: Bool = false { didSet { fillCheckbox?.state = isFilled ? .on : .off } }
    var isRounded: Bool = false { didSet { roundedCheckbox?.state = isRounded ? .on : .off } }
    var outlineStyle: Int = 0 { didSet { outlineStylePopup?.selectItem(at: outlineStyle) } }
    var outlineColor: NSColor = .black { didSet { outlineColorWell?.color = outlineColor } }
    var fontName: String = "系统默认" { didSet { if let item = fontPopup?.item(withTitle: fontName) { fontPopup?.select(item) } else { fontPopup?.selectItem(at: 0) } } }
    var textBackgroundColor: NSColor? = nil { didSet { updateBackgroundPopupSelection() } }
    private var currentOpacity: CGFloat = 1.0
    private var baseColor: NSColor = .red
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        setupControls()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.white.cgColor
        layer?.cornerRadius = 8
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.3
        layer?.shadowOffset = CGSize(width: 0, height: -2)
        layer?.shadowRadius = 8
    }
    private func setupControls() {
        let padding: CGFloat = 8
        let leftSectionWidth: CGFloat = 140
        let middleSectionWidth: CGFloat = 72
        let rightSectionWidth: CGFloat = 176
        let height: CGFloat = 64
        frame.size = CGSize(width: padding + leftSectionWidth + padding + middleSectionWidth + padding + rightSectionWidth + padding, height: height)
        let rowHeight: CGFloat = 20
        let rowSpacing: CGFloat = 8
        let row1Y = height - padding - rowHeight
        let row2Y = row1Y - rowHeight - rowSpacing
        let labelFont = NSFont.systemFont(ofSize: 11)
        let valueFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        let sizeIcon = NSTextField(labelWithString: "大小")
        sizeIcon.font = labelFont
        sizeIcon.frame = CGRect(x: padding, y: row1Y, width: 30, height: 16)
        sizeIcon.textColor = .secondaryLabelColor
        addSubview(sizeIcon)
        let sSlider = NSSlider(value: 4.0, minValue: 1.0, maxValue: 20.0, target: self, action: #selector(sizeSliderChanged(_:)))
        sSlider.frame = CGRect(x: padding + 32, y: row1Y, width: 70, height: 16)
        sSlider.controlSize = .small
        addSubview(sSlider)
        sizeSlider = sSlider
        let sLabel = NSTextField(labelWithString: "4")
        sLabel.frame = CGRect(x: sSlider.frame.maxX + 4, y: row1Y, width: 24, height: 16)
        sLabel.font = valueFont
        sLabel.textColor = .secondaryLabelColor
        addSubview(sLabel)
        sizeValueLabel = sLabel
        let opIcon = NSTextField(labelWithString: "不透明度")
        opIcon.font = labelFont
        opIcon.frame = CGRect(x: padding, y: row2Y, width: 48, height: 16)
        opIcon.textColor = .secondaryLabelColor
        addSubview(opIcon)
        let oSlider = NSSlider(value: 100.0, minValue: 0.0, maxValue: 100.0, target: self, action: #selector(opacitySliderChanged(_:)))
        oSlider.frame = CGRect(x: padding + 50, y: row2Y, width: 52, height: 16)
        oSlider.controlSize = .small
        addSubview(oSlider)
        opacitySlider = oSlider
        let oLabel = NSTextField(labelWithString: "100")
        oLabel.frame = CGRect(x: oSlider.frame.maxX + 4, y: row2Y, width: 24, height: 16)
        oLabel.font = valueFont
        oLabel.textColor = .secondaryLabelColor
        addSubview(oLabel)
        opacityValueLabel = oLabel
        let sep1 = NSView(frame: CGRect(x: padding + leftSectionWidth + padding/2, y: padding, width: 1, height: height - padding*2))
        sep1.wantsLayer = true
        sep1.layer?.backgroundColor = NSColor.separatorColor.cgColor
        addSubview(sep1)
        let colorSize: CGFloat = 18
        let colorSpacing: CGFloat = 8
        let colorStartX = sep1.frame.maxX + padding/2
        let colorBlockY = (height - (colorSize * 2 + colorSpacing)) / 2
        for (index, color) in colors.enumerated() {
            let row = index < 3 ? 0 : 1
            let col = index < 3 ? index : index - 3
            let x = colorStartX + CGFloat(col) * (colorSize + colorSpacing)
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
        let customX = colorStartX + 2 * (colorSize + colorSpacing)
        let customY = colorBlockY
        let customBtn = ColorButton(frame: CGRect(x: customX, y: customY, width: colorSize, height: colorSize))
        customBtn.color = NSColor.systemTeal
        customBtn.isCustom = true
        customBtn.target = self
        customBtn.action = #selector(customColorTapped(_:))
        customBtn.isBordered = false
        customBtn.title = ""
        addSubview(customBtn)
        colorButtons.append(customBtn)
        let sep2 = NSView(frame: CGRect(x: colorStartX + 72, y: padding, width: 1, height: height - padding*2))
        sep2.wantsLayer = true
        sep2.layer?.backgroundColor = NSColor.separatorColor.cgColor
        addSubview(sep2)
        let checkStartX = sep2.frame.maxX + 10
        let fillCheck = NSButton(checkboxWithTitle: "实心", target: self, action: #selector(fillTapped(_:)))
        fillCheck.frame = CGRect(x: checkStartX, y: row1Y, width: 60, height: 16)
        fillCheck.font = labelFont
        fillCheck.controlSize = .small
        addSubview(fillCheck)
        fillCheckbox = fillCheck
        let boldCheck = NSButton(checkboxWithTitle: "粗体", target: self, action: #selector(boldTapped(_:)))
        boldCheck.frame = CGRect(x: checkStartX, y: row1Y - 1, width: 52, height: 18)
        boldCheck.font = labelFont
        boldCheck.controlSize = .small
        boldCheck.isHidden = true
        addSubview(boldCheck)
        boldButton = boldCheck
        let bgLabel = NSTextField(labelWithString: "底色")
        bgLabel.font = labelFont
        bgLabel.textColor = .secondaryLabelColor
        bgLabel.frame = CGRect(x: checkStartX, y: row1Y, width: 32, height: 16)
        bgLabel.isHidden = true
        addSubview(bgLabel)
        backgroundLabel = bgLabel
        let bgPop = NSPopUpButton(frame: CGRect(x: checkStartX + 36, y: row1Y - 1, width: 76, height: 18), pullsDown: false)
        bgPop.addItems(withTitles: ["透明", "白", "黑", "黄", "蓝", "红"])
        bgPop.controlSize = .small
        bgPop.font = labelFont
        bgPop.target = self
        bgPop.action = #selector(backgroundChanged(_:))
        bgPop.isHidden = true
        addSubview(bgPop)
        backgroundPopup = bgPop
        let roundCheck = NSButton(checkboxWithTitle: "圆角", target: self, action: #selector(roundedTapped(_:)))
        roundCheck.frame = CGRect(x: checkStartX, y: row2Y, width: 60, height: 16)
        roundCheck.font = labelFont
        roundCheck.controlSize = .small
        addSubview(roundCheck)
        roundedCheckbox = roundCheck
        outlineStylePopup = nil
        outlineColorWell = nil
        let fontPop = NSPopUpButton(frame: CGRect(x: checkStartX + 60, y: row2Y - 1, width: 76, height: 18), pullsDown: false)
        fontPop.addItem(withTitle: "系统默认")
        let commonFonts = ["Helvetica", "Arial", "Times New Roman", "Courier New", "Verdana", "PingFang SC", "苹方-简", "SimSun", "宋体", "SimHei", "黑体", "Microsoft YaHei", "微软雅黑", "Source Han Sans SC", "思源黑体"]
        fontPop.addItems(withTitles: commonFonts)
        fontPop.controlSize = .small
        fontPop.font = labelFont
        fontPop.target = self
        fontPop.action = #selector(fontChanged(_:))
        fontPop.isHidden = true
        addSubview(fontPop)
        fontPopup = fontPop
        updateUIFromSelection()
    }
    func configure(for type: AnnotationType) {
        currentType = type
        let height: CGFloat = 64
        let padding: CGFloat = 8
        let rowHeight: CGFloat = 20
        let rowSpacing: CGFloat = 8
        let row1Y = height - padding - rowHeight
        let row2Y = row1Y - rowHeight - rowSpacing
        let checkStartX = fillCheckbox?.frame.minX ?? 238
        if type == .text || type == .counter {
            sizeSlider?.minValue = 12.0
            sizeSlider?.maxValue = 100.0
            sizeValueLabel?.stringValue = "\(Int(selectedWidth))pt"
        } else {
            sizeSlider?.minValue = 1.0
            sizeSlider?.maxValue = 20.0
            sizeValueLabel?.stringValue = "\(Int(selectedWidth))px"
        }
        let isTextOrCounter = (type == .text || type == .counter)
        boldButton?.isHidden = !isTextOrCounter
        backgroundPopup?.isHidden = !isTextOrCounter
        backgroundLabel?.isHidden = !isTextOrCounter
        fontPopup?.isHidden = !isTextOrCounter
        let isShape = (type == .rectangle || type == .ellipse)
        fillCheckbox?.isHidden = !isShape
        roundedCheckbox?.isHidden = (type != .rectangle)
        outlineStylePopup?.isHidden = true
        outlineColorWell?.isHidden = true
        if isTextOrCounter {
            backgroundLabel?.frame.origin = CGPoint(x: checkStartX, y: row1Y)
            backgroundPopup?.frame.origin = CGPoint(x: checkStartX + 36, y: row1Y - 1)
            boldButton?.frame.origin = CGPoint(x: checkStartX, y: row2Y - 1)
            fontPopup?.frame.size.width = 76
            fontPopup?.frame.origin = CGPoint(x: checkStartX + 60, y: row2Y - 1)
            boldButton?.isHidden = false
            fontPopup?.isHidden = false
        }
        sizeSlider?.doubleValue = selectedWidth

        let leftSectionWidth: CGFloat = 140
        let middleSectionWidth: CGFloat = 72
        let rightSectionWidth: CGFloat = 176
        let showRight = isTextOrCounter || isShape
        let newWidth = padding + leftSectionWidth + padding + middleSectionWidth + padding + (showRight ? rightSectionWidth : 0) + padding
        self.frame.size.width = newWidth
    }
    private func updateUIFromSelection() {
        currentOpacity = selectedColor.alphaComponent
        baseColor = selectedColor.withAlphaComponent(1.0)
        sizeSlider?.doubleValue = selectedWidth
        sizeValueLabel?.stringValue = (currentType == .text || currentType == .counter) ? "\(Int(selectedWidth))pt" : "\(Int(selectedWidth))px"
        opacitySlider?.doubleValue = Double(currentOpacity * 100)
        opacityValueLabel?.stringValue = "\(Int(currentOpacity * 100))"
        for btn in colorButtons {
            if btn.isCustom {
                let anyMatch = colorButtons.dropLast().contains { areColorsSimilar($0.color, baseColor) }
                btn.isSelected = !anyMatch
            } else {
                btn.isSelected = areColorsSimilar(btn.color, baseColor)
            }
        }
        boldButton?.state = isBold ? .on : .off
        fillCheckbox?.state = isFilled ? .on : .off
        roundedCheckbox?.state = isRounded ? .on : .off
        if let item = fontPopup?.item(withTitle: fontName) { fontPopup?.select(item) }
        updateBackgroundPopupSelection()
    }
    private func updateBackgroundPopupSelection() {
        guard let bgPop = backgroundPopup else { return }
        let title: String
        if let c = textBackgroundColor {
            if areColorsSimilar(c, .white) { title = "白" }
            else if areColorsSimilar(c, .black) { title = "黑" }
            else if areColorsSimilar(c, .yellow) { title = "黄" }
            else if areColorsSimilar(c, .blue) { title = "蓝" }
            else if areColorsSimilar(c, .red) { title = "红" }
            else { title = "透明" }
        } else { title = "透明" }
        bgPop.selectItem(withTitle: title)
    }
    private func areColorsSimilar(_ c1: NSColor, _ c2: NSColor) -> Bool {
        guard let rc1 = c1.usingColorSpace(.sRGB), let rc2 = c2.usingColorSpace(.sRGB) else { return false }
        return abs(rc1.redComponent - rc2.redComponent) < 0.01 && abs(rc1.greenComponent - rc2.greenComponent) < 0.01 && abs(rc1.blueComponent - rc2.blueComponent) < 0.01
    }
    @objc private func sizeSliderChanged(_ sender: NSSlider) {
        selectedWidth = CGFloat(sender.doubleValue)
        sizeValueLabel?.stringValue = (currentType == .text || currentType == .counter) ? "\(Int(selectedWidth))pt" : "\(Int(selectedWidth))px"
        delegate?.didChangeLineWidth(selectedWidth)
    }
    @objc private func opacitySliderChanged(_ sender: NSSlider) {
        currentOpacity = CGFloat(sender.doubleValue / 100.0)
        opacityValueLabel?.stringValue = "\(Int(sender.doubleValue))"
        selectedColor = baseColor.withAlphaComponent(currentOpacity)
        delegate?.didChangeColor(selectedColor)
    }
    @objc private func colorTapped(_ sender: ColorButton) {
        baseColor = sender.color
        for btn in colorButtons { btn.isSelected = (btn == sender) }
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
        default: textBackgroundColor = nil
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
        let panel = NSColorPanel.shared
        panel.setTarget(self)
        panel.setAction(#selector(colorPanelChanged(_:)))
        panel.color = baseColor
        panel.orderFront(self)
        for btn in colorButtons { btn.isSelected = (btn == sender) }
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
