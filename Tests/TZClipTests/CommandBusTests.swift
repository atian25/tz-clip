import XCTest
@testable import TZClip

final class CommandBusTests: XCTestCase {
    func testExecuteCallsClosures() {
        var undoCalled = false
        var closeCalled = false
        var saveCalled = false
        var copyCalled = false
        let image = NSImage(size: NSSize(width: 10, height: 10))
        let bus = CommandBus(getImage: { image }, onUndo: { undoCalled = true }, onClose: { closeCalled = true }, onSave: { _ in saveCalled = true }, onCopy: { _ in copyCalled = true })
        bus.execute(action: .undo)
        bus.execute(action: .close)
        bus.execute(action: .save)
        bus.execute(action: .copy)
        XCTAssertTrue(undoCalled)
        XCTAssertTrue(closeCalled)
        XCTAssertTrue(saveCalled)
        XCTAssertTrue(copyCalled)
    }
    func testSaveCopySkipWhenNoImage() {
        var saveCalled = false
        var copyCalled = false
        let bus = CommandBus(getImage: { nil }, onUndo: { }, onClose: { }, onSave: { _ in saveCalled = true }, onCopy: { _ in copyCalled = true })
        bus.execute(action: .save)
        bus.execute(action: .copy)
        XCTAssertFalse(saveCalled)
        XCTAssertFalse(copyCalled)
    }
}
