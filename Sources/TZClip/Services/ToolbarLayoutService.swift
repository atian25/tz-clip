import Cocoa

struct ToolbarLayoutService {
    static func compute(selectionRect: NSRect, bounds: NSRect, toolbarSize: NSSize, propsSize: NSSize, padding: CGFloat) -> (NSPoint, NSPoint) {
        var toolbarX = selectionRect.maxX - toolbarSize.width
        toolbarX = max(padding, toolbarX)
        toolbarX = min(bounds.width - toolbarSize.width - padding, toolbarX)
        var toolbarY = selectionRect.minY - padding - toolbarSize.height
        let spaceBelow = selectionRect.minY
        let spaceAbove = bounds.height - selectionRect.maxY
        var isToolbarBelow = true
        if spaceBelow < (toolbarSize.height + padding + propsSize.height + padding) {
            if spaceAbove > (toolbarSize.height + padding + propsSize.height + padding) {
                toolbarY = selectionRect.maxY + padding
                isToolbarBelow = false
            } else if toolbarY < padding {
                toolbarY = padding
                isToolbarBelow = true
            }
        }
        var propsX = toolbarX
        propsX = min(bounds.width - propsSize.width - padding, max(padding, propsX))
        let propsY = isToolbarBelow ? (toolbarY - padding - propsSize.height) : (toolbarY + toolbarSize.height + padding)
        return (NSPoint(x: toolbarX, y: toolbarY), NSPoint(x: propsX, y: propsY))
    }
}
