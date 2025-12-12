import XCTest
@testable import TZClip

final class ShapeHitTestTests: XCTestCase {
    func testFilledRectangleCenterHit() {
        var rect = RectangleAnnotation(rect: CGRect(x: 10, y: 10, width: 100, height: 80), color: .red, lineWidth: 4)
        rect.isFilled = true
        XCTAssertTrue(rect.contains(point: CGPoint(x: 60, y: 50)))
        rect.isFilled = false
        XCTAssertFalse(rect.contains(point: CGPoint(x: 60, y: 50)))
    }

    func testFilledEllipseCenterHit() {
        var ell = EllipseAnnotation(rect: CGRect(x: 0, y: 0, width: 100, height: 100), color: .blue, lineWidth: 3)
        ell.isFilled = true
        XCTAssertTrue(ell.contains(point: CGPoint(x: 50, y: 50)))
        ell.isFilled = false
        XCTAssertFalse(ell.contains(point: CGPoint(x: 50, y: 50)))
    }
}
