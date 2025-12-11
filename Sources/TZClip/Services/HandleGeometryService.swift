import Cocoa

struct HandleGeometryService {
    static func rect(for handle: Handle, in selectionRect: NSRect, handleSize: CGFloat) -> NSRect {
        let x = selectionRect.origin.x
        let y = selectionRect.origin.y
        let w = selectionRect.size.width
        let h = selectionRect.size.height
        let half = handleSize / 2
        var center = NSPoint.zero
        switch handle {
        case .topLeft:     center = NSPoint(x: x, y: y + h)
        case .top:         center = NSPoint(x: x + w / 2, y: y + h)
        case .topRight:    center = NSPoint(x: x + w, y: y + h)
        case .left:        center = NSPoint(x: x, y: y + h / 2)
        case .right:       center = NSPoint(x: x + w, y: y + h / 2)
        case .bottomLeft:  center = NSPoint(x: x, y: y)
        case .bottom:      center = NSPoint(x: x + w / 2, y: y)
        case .bottomRight: center = NSPoint(x: x + w, y: y)
        }
        return NSRect(x: center.x - half, y: center.y - half, width: handleSize, height: handleSize)
    }

    static func handle(at point: NSPoint, selectionRect: NSRect, handleSize: CGFloat) -> Handle? {
        for h in Handle.allCases {
            if rect(for: h, in: selectionRect, handleSize: handleSize).contains(point) {
                return h
            }
        }
        return nil
    }
}
