import XCTest
@testable import TZClip

final class CounterAnnotationTests: XCTestCase {
    func testNumberFontSizeScalingAndCap() {
        var c1 = CounterAnnotation(number: 1, badgeCenter: CGPoint(x: 0, y: 0), labelOrigin: nil, text: nil, color: .red, lineWidth: 12)
        XCTAssertEqual(c1.numberFontSize, 7.2, accuracy: 0.01)
        c1.lineWidth = 50
        XCTAssertEqual(c1.numberFontSize, 20.0, accuracy: 0.01) // capped at 20
        c1.lineWidth = 100
        XCTAssertEqual(c1.numberFontSize, 20.0, accuracy: 0.01) // capped
    }

    func testEffectiveFontUsesLineWidth() {
        var c = CounterAnnotation(number: 1, badgeCenter: CGPoint(x: 0, y: 0), labelOrigin: CGPoint(x: 10, y: 10), text: "abc", color: .red, lineWidth: 18)
        let font = c.effectiveFont
        XCTAssertEqual(font.pointSize, 18, accuracy: 0.01)
        c.lineWidth = 8
        XCTAssertEqual(c.effectiveFont.pointSize, 12, accuracy: 0.01) // min clamp updated
        c.lineWidth = 120
        XCTAssertEqual(c.effectiveFont.pointSize, 100, accuracy: 0.01) // max clamp
    }

    func testBadgeRadiusFreezesAfterNumberCapThreshold() {
        var c = CounterAnnotation(number: 1, badgeCenter: CGPoint(x: 0, y: 0), labelOrigin: nil, text: nil, color: .red, lineWidth: 33.34)
        let r1 = c.badgeRadius
        c.lineWidth = 100
        let r2 = c.badgeRadius
        XCTAssertEqual(r1, r2, accuracy: 0.01)
    }
}
