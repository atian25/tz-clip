import Cocoa

struct ArrowAnnotation: Annotation {
    let id: UUID = UUID()
    let type: AnnotationType = .arrow
    var startPoint: CGPoint
    var endPoint: CGPoint
    var color: NSColor
    var lineWidth: CGFloat
    var bounds: CGRect {
        let minX = min(startPoint.x, endPoint.x)
        let minY = min(startPoint.y, endPoint.y)
        let maxX = max(startPoint.x, endPoint.x)
        let maxY = max(startPoint.y, endPoint.y)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY).insetBy(dx: -10, dy: -10)
    }
    func draw(in context: CGContext) {
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.move(to: startPoint)
        context.addLine(to: endPoint)
        context.strokePath()
        let angle = atan2(endPoint.y - startPoint.y, endPoint.x - startPoint.x)
        let arrowLength: CGFloat = 15.0 + lineWidth * 2
        let arrowAngle: CGFloat = .pi / 6
        let p1 = CGPoint(x: endPoint.x - arrowLength * cos(angle - arrowAngle), y: endPoint.y - arrowLength * sin(angle - arrowAngle))
        let p2 = CGPoint(x: endPoint.x - arrowLength * cos(angle + arrowAngle), y: endPoint.y - arrowLength * sin(angle + arrowAngle))
        context.move(to: endPoint)
        context.addLine(to: p1)
        context.move(to: endPoint)
        context.addLine(to: p2)
        context.strokePath()
        context.restoreGState()
    }
    func contains(point: CGPoint) -> Bool {
        let path = CGMutablePath()
        path.move(to: startPoint)
        path.addLine(to: endPoint)
        let angle = atan2(endPoint.y - startPoint.y, endPoint.x - startPoint.x)
        let arrowLength: CGFloat = 15.0 + lineWidth * 2
        let arrowAngle: CGFloat = .pi / 6
        let p1 = CGPoint(x: endPoint.x - arrowLength * cos(angle - arrowAngle), y: endPoint.y - arrowLength * sin(angle - arrowAngle))
        let p2 = CGPoint(x: endPoint.x - arrowLength * cos(angle + arrowAngle), y: endPoint.y - arrowLength * sin(angle + arrowAngle))
        path.move(to: endPoint)
        path.addLine(to: p1)
        path.move(to: endPoint)
        path.addLine(to: p2)
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
