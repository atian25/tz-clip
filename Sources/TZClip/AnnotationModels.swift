import Cocoa

enum AnnotationType {
    case select // New select tool
    case rectangle
    case ellipse
    case arrow
    case line
    case pen
    case text
}

protocol Annotation {
    var id: UUID { get }
    var type: AnnotationType { get }
    var color: NSColor { get set }
    var lineWidth: CGFloat { get set }
    var bounds: CGRect { get }
    
    func draw(in context: CGContext)
    func contains(point: CGPoint) -> Bool
    func move(by translation: CGPoint) -> Annotation
}

struct RectangleAnnotation: Annotation {
    let id: UUID = UUID()
    let type: AnnotationType = .rectangle
    var rect: CGRect
    var color: NSColor
    var lineWidth: CGFloat
    
    var bounds: CGRect { rect }
    
    func draw(in context: CGContext) {
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.stroke(rect)
    }
    
    func contains(point: CGPoint) -> Bool {
        // Hit test on the stroke
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

struct EllipseAnnotation: Annotation {
    let id: UUID = UUID()
    let type: AnnotationType = .ellipse
    var rect: CGRect
    var color: NSColor
    var lineWidth: CGFloat
    
    var bounds: CGRect { rect }
    
    func draw(in context: CGContext) {
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.strokeEllipse(in: rect)
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
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.move(to: startPoint)
        context.addLine(to: endPoint)
        context.strokePath()
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
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY).insetBy(dx: -10, dy: -10) // Approx
    }
    
    func draw(in context: CGContext) {
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        
        // Draw main line
        context.move(to: startPoint)
        context.addLine(to: endPoint)
        context.strokePath()
        
        // Draw arrow head
        let angle = atan2(endPoint.y - startPoint.y, endPoint.x - startPoint.x)
        let arrowLength: CGFloat = 15.0 + lineWidth * 2
        let arrowAngle: CGFloat = .pi / 6 // 30 degrees
        
        let p1 = CGPoint(
            x: endPoint.x - arrowLength * cos(angle - arrowAngle),
            y: endPoint.y - arrowLength * sin(angle - arrowAngle)
        )
        let p2 = CGPoint(
            x: endPoint.x - arrowLength * cos(angle + arrowAngle),
            y: endPoint.y - arrowLength * sin(angle + arrowAngle)
        )
        
        context.move(to: endPoint)
        context.addLine(to: p1)
        context.move(to: endPoint)
        context.addLine(to: p2)
        context.strokePath()
    }
    
    func contains(point: CGPoint) -> Bool {
        let path = CGMutablePath()
        path.move(to: startPoint)
        path.addLine(to: endPoint)
        
        // Add arrow head for hit test
        let angle = atan2(endPoint.y - startPoint.y, endPoint.x - startPoint.x)
        let arrowLength: CGFloat = 15.0 + lineWidth * 2
        let arrowAngle: CGFloat = .pi / 6
        
        let p1 = CGPoint(
            x: endPoint.x - arrowLength * cos(angle - arrowAngle),
            y: endPoint.y - arrowLength * sin(angle - arrowAngle)
        )
        let p2 = CGPoint(
            x: endPoint.x - arrowLength * cos(angle + arrowAngle),
            y: endPoint.y - arrowLength * sin(angle + arrowAngle)
        )
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
        
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        
        context.move(to: points[0])
        for i in 1..<points.count {
            context.addLine(to: points[i])
        }
        context.strokePath()
    }
    
    func contains(point: CGPoint) -> Bool {
        guard points.count > 1 else { return false }
        let path = CGMutablePath()
        path.move(to: points[0])
        for i in 1..<points.count {
            path.addLine(to: points[i])
        }
        let strokedPath = path.copy(strokingWithWidth: max(lineWidth, 10), lineCap: .round, lineJoin: .round, miterLimit: 10)
        return strokedPath.contains(point)
    }
    
    func move(by translation: CGPoint) -> Annotation {
        var new = self
        new.points = points.map { CGPoint(x: $0.x + translation.x, y: $0.y + translation.y) }
        return new
    }
}

struct TextAnnotation: Annotation {
    let id: UUID = UUID()
    let type: AnnotationType = .text
    var text: String
    var origin: CGPoint // Bottom-left origin of text
    var color: NSColor
    var lineWidth: CGFloat // Unused for drawing, but kept for protocol. Can be used for Font Size?
    var font: NSFont
    var isBold: Bool = false
    
    var bounds: CGRect {
        let attributes: [NSAttributedString.Key: Any] = [.font: effectiveFont]
        let size = (text as NSString).size(withAttributes: attributes)
        return CGRect(origin: origin, size: size)
    }
    
    var effectiveFont: NSFont {
        if isBold {
            return NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        }
        return font
    }
    
    func draw(in context: CGContext) {
        NSGraphicsContext.saveGraphicsState()
        let nsContext = NSGraphicsContext(cgContext: context, flipped: true)
        NSGraphicsContext.current = nsContext
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: effectiveFont,
            .foregroundColor: color
        ]
        
        // Text drawing
        text.draw(at: origin, withAttributes: attributes)
        
        NSGraphicsContext.restoreGraphicsState()
    }
    
    func contains(point: CGPoint) -> Bool {
        return bounds.contains(point)
    }
    
    func move(by translation: CGPoint) -> Annotation {
        var new = self
        new.origin.x += translation.x
        new.origin.y += translation.y
        return new
    }
}
