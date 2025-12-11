import Cocoa

struct SnapService {
    static func apply(rect: NSRect, in bounds: NSRect, threshold: CGFloat) -> (NSRect, Set<Int>) {
        var r = rect
        var edges: Set<Int> = []
        if abs(r.minX - bounds.minX) < threshold {
            r.origin.x = bounds.minX
            edges.insert(0)
        } else if abs(r.maxX - bounds.maxX) < threshold {
            r.origin.x = bounds.maxX - r.width
            edges.insert(1)
        }
        if abs(r.minY - bounds.minY) < threshold {
            r.origin.y = bounds.minY
            edges.insert(2)
        } else if abs(r.maxY - bounds.maxY) < threshold {
            r.origin.y = bounds.maxY - r.height
            edges.insert(3)
        }
        return (r, edges)
    }
}
