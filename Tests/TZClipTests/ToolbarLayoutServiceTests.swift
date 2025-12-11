import XCTest
@testable import TZClip

final class ToolbarLayoutServiceTests: XCTestCase {
    func testLayoutBelowSelection() {
        let bounds = NSRect(x: 0, y: 0, width: 300, height: 300)
        let sel = NSRect(x: 50, y: 150, width: 100, height: 80)
        let toolbarSize = NSSize(width: 120, height: 40)
        let propsSize = NSSize(width: 180, height: 64)
        let (toolbarOrigin, propsOrigin) = ToolbarLayoutService.compute(selectionRect: sel, bounds: bounds, toolbarSize: toolbarSize, propsSize: propsSize, padding: 8)
        XCTAssertLessThanOrEqual(toolbarOrigin.y, sel.minY)
        XCTAssertLessThan(propsOrigin.y, toolbarOrigin.y)
    }
    func testLayoutAboveWhenSpaceInsufficient() {
        let bounds = NSRect(x: 0, y: 0, width: 300, height: 300)
        let sel = NSRect(x: 50, y: 20, width: 100, height: 40)
        let toolbarSize = NSSize(width: 120, height: 40)
        let propsSize = NSSize(width: 180, height: 64)
        let (toolbarOrigin, propsOrigin) = ToolbarLayoutService.compute(selectionRect: sel, bounds: bounds, toolbarSize: toolbarSize, propsSize: propsSize, padding: 8)
        XCTAssertGreaterThanOrEqual(toolbarOrigin.y, sel.maxY)
        XCTAssertGreaterThan(propsOrigin.y, toolbarOrigin.y)
    }
}
