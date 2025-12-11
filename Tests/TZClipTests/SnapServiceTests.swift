import XCTest
@testable import TZClip

final class SnapServiceTests: XCTestCase {
    func testSnapLeftEdge() {
        let bounds = NSRect(x: 0, y: 0, width: 100, height: 100)
        let rect = NSRect(x: 3, y: 40, width: 20, height: 20)
        let (r, edges) = SnapService.apply(rect: rect, in: bounds, threshold: 5)
        XCTAssertEqual(r.minX, bounds.minX)
        XCTAssertTrue(edges.contains(0))
    }
    func testSnapRightEdge() {
        let bounds = NSRect(x: 0, y: 0, width: 100, height: 100)
        let rect = NSRect(x: 79, y: 40, width: 20, height: 20)
        let (r, edges) = SnapService.apply(rect: rect, in: bounds, threshold: 5)
        XCTAssertEqual(r.maxX, bounds.maxX)
        XCTAssertTrue(edges.contains(1))
    }
    func testSnapTopBottom() {
        let bounds = NSRect(x: 0, y: 0, width: 100, height: 100)
        let rectTop = NSRect(x: 40, y: 79, width: 10, height: 20)
        let (rt, et) = SnapService.apply(rect: rectTop, in: bounds, threshold: 5)
        XCTAssertEqual(rt.maxY, bounds.maxY)
        XCTAssertTrue(et.contains(3))
        let rectBottom = NSRect(x: 40, y: 3, width: 10, height: 20)
        let (rb, eb) = SnapService.apply(rect: rectBottom, in: bounds, threshold: 5)
        XCTAssertEqual(rb.minY, bounds.minY)
        XCTAssertTrue(eb.contains(2))
    }
}
