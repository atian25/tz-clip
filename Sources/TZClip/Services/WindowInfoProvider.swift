import Cocoa
@preconcurrency import ScreenCaptureKit
import CoreGraphics

struct DetectedWindow {
    let id: UInt32
    let frame: CGRect
    let title: String?
    let appName: String?
    let zOrder: Int
    let originalFrame: CGRect
}

@available(macOS 12.3, *)
@MainActor
class WindowInfoProvider {
    private var windows: [DetectedWindow] = []
    private var isReady: Bool = false
    private var primaryScreenHeight: CGFloat = 1080
    init() {
        let mainDisplayID = CGMainDisplayID()
        let bounds = CGDisplayBounds(mainDisplayID)
        self.primaryScreenHeight = bounds.height
    }
    func captureWindows() async -> Bool {
        do {
            let content = try await SCShareableContent.current
            let myPID = ProcessInfo.processInfo.processIdentifier
            self.windows = content.windows.filter { window in
                if window.owningApplication?.processID == myPID { return false }
                return window.isOnScreen
            }.map { convert(scWindow: $0) }.filter { w in w.frame.width > 10 && w.frame.height > 10 }
            self.isReady = true
            return true
        } catch {
            print("Failed to capture windows: \(error)")
            return false
        }
    }
    func window(at point: NSPoint) -> DetectedWindow? {
        guard isReady else { return nil }
        let candidates = windows.enumerated().filter { $0.element.frame.contains(point) }
        if candidates.isEmpty { return nil }
        let sortedCandidates = candidates.sorted { (p1, p2) in
            let w1 = p1.element
            let w2 = p2.element
            if w1.zOrder != w2.zOrder { return w1.zOrder > w2.zOrder }
            return p1.offset < p2.offset
        }
        guard let topMost = sortedCandidates.first(where: {
            let w = $0.element
            let name = w.appName ?? ""
            let title = w.title ?? ""
            if name.contains("Dock") || name.contains("程序坞") || title == "Dock" || name == "Wallpaper" || title.contains("Wallpaper") {
                if w.frame.width > 1000 && w.frame.height > 800 { return false }
            }
            return true
        })?.element else { return nil }
        let sameAppWindows = sortedCandidates.map { $0.element }.filter { $0.appName == topMost.appName && $0.appName != nil }
        if let container = sameAppWindows.max(by: { ($0.frame.width * $0.frame.height) < ($1.frame.width * $1.frame.height) }) { return container }
        return topMost
    }
    func allWindows() -> [DetectedWindow] { windows }
    func debugWindows(at point: NSPoint) {
        print("🔍 Debugging Hit Test at \(point)")
        let candidates = windows.enumerated().filter { $0.element.frame.contains(point) }
        print("   Found \(candidates.count) raw candidates containing point:")
        for (i, c) in candidates.enumerated() { print("   [\(i)] (OrigIndex: \(c.offset)) App: \(c.element.appName ?? "nil"), Title: \(c.element.title ?? "nil"), Layer: \(c.element.zOrder), Rect: \(c.element.frame)") }
    }
    private func convert(scWindow: SCWindow) -> DetectedWindow {
        let qRect = scWindow.frame
        var cRect = qRect
        cRect.origin.y = primaryScreenHeight - qRect.maxY
        return DetectedWindow(id: scWindow.windowID, frame: cRect, title: scWindow.title, appName: scWindow.owningApplication?.applicationName, zOrder: scWindow.windowLayer, originalFrame: qRect)
    }
}
