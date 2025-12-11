import Cocoa

struct LineAnnotation: Annotation {
    let id: UUID = UUID()
    let type: AnnotationType = .line
    var startPoint: CGPoint
    var endPoint: CGPoint
    var color: NSColor
    var lineWidth: CGFloat
    var bounds: CGRect {
        let minX = min(startPoint.x, endPoint.x)
        let minY = min(startPoint.y, endPoint.y)
        let maxX = max(startPoint.x, endPoint.x)
        let maxY = max(startPoint.y, endPoint.y)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    func draw(in context: CGContext) {
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.move(to: startPoint)
        context.addLine(to: endPoint)
        context.strokePath()
        context.restoreGState()
    }
    func contains(point: CGPoint) -> Bool {
        let path = CGMutablePath()
        path.move(to: startPoint)
        path.addLine(to: endPoint)
        let strokedPath = path.copy(strokingWithWidth: max(lineWidth, 10), lineCap: .round, lineJoin: .miter, miterLimit: 10)
        return strokedPath.contains(point)
    }
    func move(by translation: CGPoint) -> Annotation {
        var new = self
        new.startPoint.x += translation.x
        new.startPoint.y += translation.y
        new.endPoint.x += translation.x
        new.endPoint.y += translation.y
        return new
    }
}
