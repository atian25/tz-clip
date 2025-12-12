import Cocoa

struct RectangleAnnotation: Annotation {
    let id: UUID = UUID()
    let type: AnnotationType = .rectangle
    var rect: CGRect
    var color: NSColor
    var lineWidth: CGFloat
    var isFilled: Bool = false
    var isRounded: Bool = false
    var bounds: CGRect { rect }
    func draw(in context: CGContext) {
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        let path: CGPath
        if isRounded {
            let radius: CGFloat = 10.0
            path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        } else {
            path = CGPath(rect: rect, transform: nil)
        }
        context.addPath(path)
        if isFilled {
            context.setFillColor(color.cgColor)
            context.drawPath(using: .fillStroke)
        } else {
            context.drawPath(using: .stroke)
        }
        context.restoreGState()
    }
    func contains(point: CGPoint) -> Bool {
        if isFilled { return rect.contains(point) }
        let path = CGPath(rect: rect, transform: nil)
        let strokedPath = path.copy(strokingWithWidth: max(lineWidth, 10), lineCap: .butt, lineJoin: .miter, miterLimit: 10)
        return strokedPath.contains(point)
    }
    func move(by translation: CGPoint) -> Annotation {
        var new = self
        new.rect = rect.offsetBy(dx: translation.x, dy: translation.y)
        return new
    }
}
