import XCTest
@testable import TZClip

final class HandleGeometryServiceTests: XCTestCase {
    func testHandleRectsPositions() {
        let rect = NSRect(x: 10, y: 20, width: 100, height: 50)
        let hs: CGFloat = 8
        let tl = HandleGeometryService.rect(for: .topLeft, in: rect, handleSize: hs)
        XCTAssertEqual(tl.midX, rect.minX)
        XCTAssertEqual(tl.midY, rect.maxY)
        let br = HandleGeometryService.rect(for: .bottomRight, in: rect, handleSize: hs)
        XCTAssertEqual(br.midX, rect.maxX)
        XCTAssertEqual(br.midY, rect.minY)
    }
    func testHandleHit() {
        let rect = NSRect(x: 0, y: 0, width: 100, height: 100)
        let hs: CGFloat = 8
        let h = HandleGeometryService.handle(at: NSPoint(x: 100, y: 100), selectionRect: rect, handleSize: hs)
        XCTAssertEqual(h, .topRight)
    }
}
