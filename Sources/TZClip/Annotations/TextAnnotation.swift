import Cocoa

struct TextAnnotation: Annotation {
    let id: UUID = UUID()
    let type: AnnotationType = .text
    var text: String
    var origin: CGPoint
    var color: NSColor
    var lineWidth: CGFloat
    var font: NSFont
    var isBold: Bool = false
    var outlineStyle: Int = 0
    var outlineColor: NSColor = .black
    var fontName: String = "System Default"
    var backgroundColor: NSColor? = nil
    var bounds: CGRect {
        let attributes: [NSAttributedString.Key: Any] = [.font: effectiveFont]
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
        let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.current = nsContext
        if let bg = backgroundColor {
            context.setFillColor(bg.cgColor)
            context.fill(bounds)
        }
        var attributes: [NSAttributedString.Key: Any] = [ .font: effectiveFont, .foregroundColor: color ]
        if outlineStyle > 0 {
            let width: CGFloat = (outlineStyle == 1) ? -2.0 : -4.0
            attributes[.strokeWidth] = width
            attributes[.strokeColor] = outlineColor
        }
        (text as NSString).draw(in: bounds, withAttributes: attributes)
        context.restoreGState()
    }
    func contains(point: CGPoint) -> Bool { bounds.contains(point) }
    func move(by translation: CGPoint) -> Annotation {
        var new = self
        new.origin.x += translation.x
        new.origin.y += translation.y
        return new
    }
}
