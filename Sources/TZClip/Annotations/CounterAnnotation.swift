import Cocoa

struct CounterAnnotation: Annotation {
    let id: UUID = UUID()
    let type: AnnotationType = .counter
    var number: Int
    var badgeCenter: CGPoint
    var labelOrigin: CGPoint?
    var text: String?
    var label: TextAnnotation? = nil
    var color: NSColor
    var lineWidth: CGFloat
    var fontName: String = "System Default"
    var isBold: Bool = false
    var outlineStyle: Int = 0
    var outlineColor: NSColor = .black
    var backgroundColor: NSColor? = nil
    var bounds: CGRect {
        let badgeRect = self.badgeRect
        if let l = label { return badgeRect.union(l.bounds) }
        if let labelRect = self.labelRect { return badgeRect.union(labelRect) }
        return badgeRect
    }
    var badgeRadius: CGFloat {
        let freezeAtLineWidth: CGFloat = 20.0 / 0.6 // numberFontSize cap threshold (~33.33)
        let size = min(max(12.0, lineWidth), freezeAtLineWidth)
        var radius: CGFloat
        if size <= 20 {
            radius = 8.0 + (size - 10.0) * 0.4
        } else {
            radius = 12.0 + (size - 20.0) * 0.25
        }
        return min(35.0, max(8.0, radius))
    }
    var badgeRect: CGRect {
        let r = badgeRadius
        return CGRect(x: badgeCenter.x - r, y: badgeCenter.y - r, width: r * 2, height: r * 2)
    }
    var numberFontSize: CGFloat {
        let textSize = max(12.0, min(100.0, lineWidth))
        return min(textSize * 0.6, 20.0)
    }
    var labelRect: CGRect? {
        if let l = label { return l.bounds }
        guard let origin = labelOrigin, let text = text, !text.isEmpty else { return nil }
        let font = effectiveFont
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let size = (text as NSString).size(withAttributes: attributes)
        return CGRect(origin: origin, size: size)
    }
    var effectiveFont: NSFont {
        let size = max(12.0, min(100.0, lineWidth))
        var baseFont: NSFont
        if fontName == "System Default" || fontName == "系统默认" {
            baseFont = NSFont.systemFont(ofSize: size)
        } else {
            baseFont = NSFont(name: fontName, size: size) ?? NSFont.systemFont(ofSize: size)
        }
        var newFont = NSFontManager.shared.convert(baseFont, toSize: size)
        if isBold { newFont = NSFontManager.shared.convert(newFont, toHaveTrait: .boldFontMask) }
        else { newFont = NSFontManager.shared.convert(newFont, toNotHaveTrait: .boldFontMask) }
        return newFont
    }
    func draw(in context: CGContext) {
        context.saveGState()
        if let labelRect = labelRect {
            let labelCenter = CGPoint(x: labelRect.midX, y: labelRect.midY)
            let dx = labelCenter.x - badgeCenter.x
            let dy = labelCenter.y - badgeCenter.y
            var targetPoint = labelCenter
            let halfW = labelRect.width / 2.0
            let halfH = labelRect.height / 2.0
            if halfW > 0 && halfH > 0 {
                let tx = halfW / abs(dx)
                let ty = halfH / abs(dy)
                let t = min(tx, ty)
                targetPoint = CGPoint(x: labelCenter.x - t * dx, y: labelCenter.y - t * dy)
            }
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(2.0)
            context.move(to: badgeCenter)
            context.addLine(to: targetPoint)
            context.strokePath()
        }
        let r = badgeRadius
        let rect = badgeRect
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: rect)
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(1.5)
        context.strokeEllipse(in: rect)
        let numStr = "\(number)" as NSString
        let numFont = NSFont.boldSystemFont(ofSize: numberFontSize)
        let numAttrs: [NSAttributedString.Key: Any] = [ .font: numFont, .foregroundColor: NSColor.white ]
        let numSize = numStr.size(withAttributes: numAttrs)
        let numOrigin = CGPoint(x: badgeCenter.x - numSize.width / 2, y: badgeCenter.y - numSize.height / 2 + numSize.height * 0.1)
        let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.current = nsContext
        numStr.draw(at: numOrigin, withAttributes: numAttrs)
        if let l = label { l.draw(in: context) }
        else if let text = text, let origin = labelOrigin {
            let ta = TextAnnotation(text: text, origin: origin, color: color, lineWidth: lineWidth, font: effectiveFont, isBold: isBold, outlineStyle: outlineStyle, outlineColor: outlineColor, fontName: fontName, backgroundColor: backgroundColor)
            ta.draw(in: context)
        }
        context.restoreGState()
    }
    func contains(point: CGPoint) -> Bool {
        if badgeRect.contains(point) { return true }
        if let labelRect = labelRect, labelRect.contains(point) { return true }
        return false
    }
    func move(by translation: CGPoint) -> Annotation {
        var new = self
        new.badgeCenter.x += translation.x
        new.badgeCenter.y += translation.y
        if var l = new.label {
            l.origin.x += translation.x
            l.origin.y += translation.y
            new.label = l
        } else if let origin = labelOrigin {
            new.labelOrigin = CGPoint(x: origin.x + translation.x, y: origin.y + translation.y)
        }
        return new
    }
}
