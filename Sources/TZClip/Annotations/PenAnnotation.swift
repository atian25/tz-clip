import Cocoa

struct PenAnnotation: Annotation {
    let id: UUID = UUID()
    let type: AnnotationType = .pen
    var points: [CGPoint]
    var color: NSColor
    var lineWidth: CGFloat
    var bounds: CGRect {
        guard !points.isEmpty else { return .zero }
        var minX = points[0].x, minY = points[0].y
        var maxX = points[0].x, maxY = points[0].y
        for p in points {
            if p.x < minX { minX = p.x }
            if p.y < minY { minY = p.y }
            if p.x > maxX { maxX = p.x }
            if p.y > maxY { maxY = p.y }
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    func draw(in context: CGContext) {
        guard points.count > 1 else { return }
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.move(to: points[0])
        for i in 1..<points.count { context.addLine(to: points[i]) }
        context.strokePath()
        context.restoreGState()
    }
    func contains(point: CGPoint) -> Bool {
        guard points.count > 1 else { return false }
        let path = CGMutablePath()
        path.move(to: points[0])
        for i in 1..<points.count { path.addLine(to: points[i]) }
        let strokedPath = path.copy(strokingWithWidth: max(lineWidth, 10), lineCap: .round, lineJoin: .round, miterLimit: 10)
        return strokedPath.contains(point)
    }
    func move(by translation: CGPoint) -> Annotation {
        var new = self
        new.points = points.map { CGPoint(x: $0.x + translation.x, y: $0.y + translation.y) }
        return new
    }
}
