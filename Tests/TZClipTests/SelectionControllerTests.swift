import XCTest
@testable import TZClip

@MainActor
final class SelectionControllerTests: XCTestCase {
    func testPropertyPropagationToOverlay() {
        let overlay = AnnotationOverlayView(frame: .zero)
        let controller = SelectionController(overlay: overlay, propertiesView: nil, commandBus: nil)
        controller.didSelectTool(.rectangle)
        controller.didChangeColor(.blue)
        controller.didChangeLineWidth(12)
        controller.didChangeIsBold(true)
        XCTAssertEqual(overlay.currentColor, .blue)
        XCTAssertEqual(overlay.currentLineWidth, 12)
        XCTAssertTrue(overlay.currentIsBold)
    }
    func testToolSelectionConfiguresOverlay() {
        let overlay = AnnotationOverlayView(frame: .zero)
        let controller = SelectionController(overlay: overlay, propertiesView: nil, commandBus: nil)
        controller.didSelectTool(.text)
        XCTAssertEqual(overlay.currentTool, .text)
    }
}
