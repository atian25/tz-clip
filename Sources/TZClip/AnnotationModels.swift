import Cocoa

enum AnnotationType {
    case select // New select tool
    case rectangle
    case ellipse
    case arrow
    case line
    case pen
    case text
    case counter
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

struct CounterAnnotation: Annotation {
    let id: UUID = UUID()
    let type: AnnotationType = .counter
    var number: Int
    var badgeCenter: CGPoint
    var labelOrigin: CGPoint?
    var text: String?
    var label: TextAnnotation? = nil
    
    var color: NSColor
    var lineWidth: CGFloat // Now used as Font Size (similar to TextAnnotation)
    
    // Label properties
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
        // Dynamic scaling:
        // Small text (e.g. 10pt) -> Ratio ~0.8 (Radius 8)
        // Large text (e.g. 80pt) -> Ratio ~0.4 (Radius 32)
        // Formula: Base 8 + (lineWidth * scalingFactor)
        // Let's use a log-like or decaying growth.
        // Or simple piecewise:
        
        let size = lineWidth
        var radius: CGFloat
        
        if size <= 20 {
            // Linear growth for small sizes: 10->8, 20->12
            radius = 8.0 + (size - 10.0) * 0.4
        } else {
            // Slower growth for larger sizes: 20->12, 100->30
            // Delta size = 80, Delta radius = 18. Rate = 0.225
            radius = 12.0 + (size - 20.0) * 0.25
        }
        
        // Cap max radius to keep it sane
        return min(35.0, max(8.0, radius))
    }
    
    var badgeRect: CGRect {
        let r = badgeRadius
        return CGRect(x: badgeCenter.x - r, y: badgeCenter.y - r, width: r * 2, height: r * 2)
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
        // Use lineWidth directly as font size (matching TextAnnotation behavior)
        let size = max(10.0, min(100.0, lineWidth))
        
        var baseFont: NSFont
        if fontName == "System Default" || fontName == "系统默认" {
            baseFont = NSFont.systemFont(ofSize: size)
        } else {
            baseFont = NSFont(name: fontName, size: size) ?? NSFont.systemFont(ofSize: size)
        }
        
        var newFont = NSFontManager.shared.convert(baseFont, toSize: size)
        if isBold {
            newFont = NSFontManager.shared.convert(newFont, toHaveTrait: .boldFontMask)
        } else {
            newFont = NSFontManager.shared.convert(newFont, toNotHaveTrait: .boldFontMask)
        }
        return newFont
    }
    
    func draw(in context: CGContext) {
        context.saveGState()
        
        // 1. Draw Connector Line if Label exists
        if let labelRect = labelRect {
            let labelCenter = CGPoint(x: labelRect.midX, y: labelRect.midY)
            let dx = labelCenter.x - badgeCenter.x
            let dy = labelCenter.y - badgeCenter.y
            
            var targetPoint = labelCenter
            
            // Calculate intersection with label rectangle
            // The line goes from badgeCenter to labelCenter.
            // We need to find where this line intersects the labelRect edges.
            
            // Equation of line: P = badgeCenter + t * (labelCenter - badgeCenter)
            // We want to find t such that P is on the boundary of labelRect.
            // labelRect bounds: x in [minX, maxX], y in [minY, maxY]
            
            let halfW = labelRect.width / 2.0
            let halfH = labelRect.height / 2.0
            
            // Avoid division by zero
            if halfW > 0 && halfH > 0 {
                // Calculate t for X edges
                // if dx > 0, intersection is at maxX (right edge), t = (maxX - badgeX) / dx
                // BUT easier: intersect line from center (0,0 relative) to (dx, dy) with rectangle [-w/2, -h/2] to [w/2, h/2]
                
                // Slope m = dy / dx
                // Intersect vertical edges x = +/- halfW: y = m * (+/- halfW)
                // If |y| <= halfH, then it hits the vertical edge.
                
                let slope = abs(dy / dx)
                if slope * halfW <= halfH {
                    // Hits vertical edge (Left or Right)
                    targetPoint.x = dx > 0 ? labelRect.maxX : labelRect.minX
                    targetPoint.y = labelCenter.y - (dx > 0 ? 1 : -1) * (labelCenter.x - targetPoint.x) * (dy/dx)
                    // Simplify: y = badgeY + (targetX - badgeX) * slope_original
                    // Let's just project.
                    
                    // Re-calc using ratios to be safe and smooth
                    // Vector V = (dx, dy).
                    // Scale factor to reach edge:
                    // tx = (halfW) / abs(dx)
                    // ty = (halfH) / abs(dy)
                    // t = min(tx, ty)
                    
                    let tx = halfW / abs(dx)
                    let ty = halfH / abs(dy)
                    let t = min(tx, ty)
                    
                    targetPoint.x = labelCenter.x - dx * t
                    targetPoint.y = labelCenter.y - dy * t
                    
                    // Actually we want the point on the rect closest to badgeCenter? 
                    // No, we want the intersection of the segment (BadgeCenter -> LabelCenter) with LabelRect.
                    // Vector from LabelCenter to BadgeCenter is (-dx, -dy).
                    // We start at LabelCenter and move towards BadgeCenter until we hit the edge.
                    // Ray: R(t) = LabelCenter + t * (-dx, -dy)
                    // We want min positive t such that R(t) is on boundary.
                    // Boundaries: |x - cx| = halfW OR |y - cy| = halfH
                    // |t * (-dx)| = halfW  => t_x = halfW / abs(dx)
                    // |t * (-dy)| = halfH  => t_y = halfH / abs(dy)
                    // t = min(t_x, t_y)
                    
                    // targetPoint = LabelCenter + t * (-dx, -dy)
                    //             = LabelCenter - t * (dx, dy)
                    
                    targetPoint = CGPoint(
                        x: labelCenter.x - t * dx,
                        y: labelCenter.y - t * dy
                    )
                } else {
                    // Fallback to previous logic if calc fails, but the above covers all angles smoothly
                    let tx = halfW / abs(dx)
                    let ty = halfH / abs(dy)
                    let t = min(tx, ty)
                    targetPoint = CGPoint(
                        x: labelCenter.x - t * dx,
                        y: labelCenter.y - t * dy
                    )
                }
            }
            
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(2.0)
            context.move(to: badgeCenter)
            context.addLine(to: targetPoint)
            context.strokePath()
        }
        
        // 2. Draw Badge
        let r = badgeRadius
        let rect = badgeRect
        
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: rect)
        
        // White border for badge
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(1.5) // Reduced from 2.0
        context.strokeEllipse(in: rect)
        
        // Draw Number
        let numStr = "\(number)" as NSString
        // Cap the number font size so it doesn't get too overwhelming even if badge is large
        // Max radius is 35.0. Let's cap font size at 24.0.
        let numFontSize = min(r * 1.0, 24.0)
        let numFont = NSFont.boldSystemFont(ofSize: numFontSize)
        let numAttrs: [NSAttributedString.Key: Any] = [
            .font: numFont,
            .foregroundColor: NSColor.white
        ]
        let numSize = numStr.size(withAttributes: numAttrs)
        let numOrigin = CGPoint(
            x: badgeCenter.x - numSize.width / 2,
            y: badgeCenter.y - numSize.height / 2 + numSize.height * 0.1
        )
        
        let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.current = nsContext
        numStr.draw(at: numOrigin, withAttributes: numAttrs)
        
        // 3. Draw Label：复用 TextAnnotation 渲染
        if let l = label {
            l.draw(in: context)
        } else if let text = text, let origin = labelOrigin {
            let ta = TextAnnotation(
                text: text,
                origin: origin,
                color: color,
                lineWidth: lineWidth,
                font: effectiveFont,
                isBold: isBold,
                outlineStyle: outlineStyle,
                outlineColor: outlineColor,
                fontName: fontName,
                backgroundColor: backgroundColor
            )
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
            let radius: CGFloat = 10.0 // Fixed radius or proportional? Fixed is safer for UI.
            path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        } else {
            path = CGPath(rect: rect, transform: nil)
        }
        
        context.addPath(path)
        
        if isFilled {
            // Fill with color (respecting its alpha)
            // If the color is fully opaque, we might want to reduce it slightly to not hide content underneath?
            // But user said "Solid fill". Let's assume user wants the color as is (which includes alpha slider value).
            // However, usually "Fill" implies the interior. If I set alpha to 100%, and fill, I get a solid block.
            // Let's use the color's alpha directly.
            context.setFillColor(color.cgColor)
            context.drawPath(using: .fillStroke)
        } else {
            context.drawPath(using: .stroke)
        }
        
        context.restoreGState()
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
        context.saveGState()
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
        context.restoreGState()
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
        
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        
        context.move(to: points[0])
        for i in 1..<points.count {
            context.addLine(to: points[i])
        }
        context.strokePath()
        context.restoreGState()
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
    var outlineStyle: Int = 0 // 0: None, 1: Thin, 2: Thick
    var outlineColor: NSColor = .black
    var fontName: String = "System Default" // "System Default" or Font Name
    var backgroundColor: NSColor? = nil
    
    var bounds: CGRect {
        let attributes: [NSAttributedString.Key: Any] = [.font: effectiveFont]
        let size = (text as NSString).size(withAttributes: attributes)
        // origin is stored as bottom-left of the text view
        return CGRect(origin: origin, size: size)
    }
    
    var effectiveFont: NSFont {
        // Use lineWidth as font size (mapping 10-100pt)
        let size = max(10.0, min(100.0, lineWidth))
        
        var baseFont: NSFont
        if fontName == "System Default" || fontName == "系统默认" {
            baseFont = NSFont.systemFont(ofSize: size)
        } else {
            baseFont = NSFont(name: fontName, size: size) ?? NSFont.systemFont(ofSize: size)
        }
        
        // Convert existing font to new size/traits if needed
        var newFont = NSFontManager.shared.convert(baseFont, toSize: size)
        
        if isBold {
            newFont = NSFontManager.shared.convert(newFont, toHaveTrait: .boldFontMask)
        } else {
            newFont = NSFontManager.shared.convert(newFont, toNotHaveTrait: .boldFontMask)
        }
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

        var attributes: [NSAttributedString.Key: Any] = [
            .font: effectiveFont,
            .foregroundColor: color
        ]
        
        if outlineStyle > 0 {
            // Negative value for stroke AND fill
            let width: CGFloat = (outlineStyle == 1) ? -2.0 : -4.0
            attributes[.strokeWidth] = width
            attributes[.strokeColor] = outlineColor
        }
        
        // Use draw(in:) to ensure it fills the bounds correctly (bottom-left origin + size)
        // Note: NSString.draw(in:) draws in the rectangle.
        // In non-flipped context, it draws from top of rect downwards?
        // Let's rely on draw(in:) handling the rect correctly.
        (text as NSString).draw(in: bounds, withAttributes: attributes)
        
        context.restoreGState()
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
