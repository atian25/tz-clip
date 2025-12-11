import Cocoa

struct EllipseAnnotation: Annotation {
    let id: UUID = UUID()
    let type: AnnotationType = .ellipse
    var rect: CGRect
    var color: NSColor
    var lineWidth: CGFloat
    var isFilled: Bool = false
    var bounds: CGRect { rect }
    func draw(in context: CGContext) {
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        if isFilled {
            context.setFillColor(color.cgColor)
            context.fillEllipse(in: rect)
            context.strokeEllipse(in: rect)
        } else {
            context.strokeEllipse(in: rect)
        }
        context.restoreGState()
    }
    func contains(point: CGPoint) -> Bool {
        let path = CGPath(ellipseIn: rect, transform: nil)
        let strokedPath = path.copy(strokingWithWidth: max(lineWidth, 10), lineCap: .butt, lineJoin: .miter, miterLimit: 10)
        return strokedPath.contains(point)
    }
    func move(by translation: CGPoint) -> Annotation {
        var new = self
        new.rect = rect.offsetBy(dx: translation.x, dy: translation.y)
        return new
    }
}
