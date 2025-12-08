import Cocoa
@preconcurrency import ScreenCaptureKit
import CoreGraphics

struct DetectedWindow {
    let id: UInt32
    let frame: CGRect // Cocoa global coordinate system
    let title: String?
    let appName: String?
    let zOrder: Int
    let originalFrame: CGRect // Quartz coordinate for debugging
}

@available(macOS 12.3, *)
@MainActor
class WindowInfoProvider {
    
    // Store raw windows in original Front-to-Back order
    private var windows: [DetectedWindow] = []
    private var isReady: Bool = false
    private var primaryScreenHeight: CGFloat = 1080
    
    init() {
        // Use CoreGraphics to get the absolute height of the main display
        let mainDisplayID = CGMainDisplayID()
        self.primaryScreenHeight = CGFloat(CGDisplayPixelsHigh(mainDisplayID))
        // Note: CGDisplayPixelsHigh returns pixels. If scaling is involved, we might need points.
        // SCWindow frame is in Points (usually). CGDisplayBounds is in Points.
        let bounds = CGDisplayBounds(mainDisplayID)
        self.primaryScreenHeight = bounds.height
    }
    
    func captureWindows() async -> Bool {
        do {
            let content = try await SCShareableContent.current
            let myPID = ProcessInfo.processInfo.processIdentifier
            
            self.windows = content.windows
                .filter { window in
                    // 1. Basic filtering
                    if window.owningApplication?.processID == myPID { return false }
                    
                    // 2. Filter out menu bar, dock, etc if possible.
                    // Usually layer 0 is normal application windows.
                    // But some apps use other layers.
                    // We keep everything that is on screen.
                    return window.isOnScreen
                }
                .map { convert(scWindow: $0) }
                // 3. Filter out tiny windows (likely noise, tooltips, hidden helper windows)
                .filter { w in
                    return w.frame.width > 10 && w.frame.height > 10
                }
            
            self.isReady = true
            return true
            
        } catch {
            print("Failed to capture windows: \(error)")
            return false
        }
    }
    
    func window(at point: NSPoint) -> DetectedWindow? {
        guard isReady else { return nil }
        
        // 1. Hit Test: Find all windows containing the point
        // windows array is MOSTLY Front-to-Back, but layers are mixed.
        // We need to sort candidates to find the true visual top-most.
        let candidates = windows.enumerated().filter { $0.element.frame.contains(point) }
        
        // Sort strategy:
        // 1. Layer (Z-Order) Descending: Higher layer means more "front" (e.g. Menu > Window > Desktop)
        // 2. Original Index Ascending: For same layer, SCK order is Front-to-Back.
        let sortedCandidates = candidates.sorted { (p1, p2) in
            let w1 = p1.element
            let w2 = p2.element
            if w1.zOrder != w2.zOrder {
                return w1.zOrder > w2.zOrder
            }
            return p1.offset < p2.offset
        }
        
        guard let topMost = sortedCandidates.first(where: { 
            let w = $0.element
            // Filter out system windows that might be overlaying everything
            // Dock usually has a high Z-order (e.g. 20) and might report full screen frame
            // Check both appName and title, and support localized names if possible
            let name = w.appName ?? ""
            let title = w.title ?? ""
            
            if name.contains("Dock") || name.contains("程序坞") || title == "Dock" || name == "Wallpaper" || title.contains("Wallpaper") {
                // If it covers the whole screen (or close to it), it's likely an overlay/background
                if w.frame.width > 1000 && w.frame.height > 800 {
                    return false
                }
            }
            return true
        })?.element else {
            return nil
        }
        
        // 2. Smart Expansion (Container Detection)
        // If we hit a window (e.g. content view), check if there is a larger window 
        // from the SAME App that also contains the point (e.g. main window).
        
        // We look for the "largest" window of the same App that contains the point.
        // But we must be careful: what if that larger window is occluded by ANOTHER App?
        // Since we hit `topMost` first, we know `topMost` is visible (or at least the top-most of what we know).
        // If `container` belongs to the same App and contains `topMost` (conceptually), 
        // it is safe to select `container`.
        
        let sameAppWindows = sortedCandidates.map { $0.element }.filter { 
            $0.appName == topMost.appName && $0.appName != nil
        }
        
        if let container = sameAppWindows.max(by: { ($0.frame.width * $0.frame.height) < ($1.frame.width * $1.frame.height) }) {
            // If the container is significantly larger, use it.
            // Also ensure the container actually contains the hit point (it must, per filter above).
            return container
        }
        
        return topMost
    }
    
    func allWindows() -> [DetectedWindow] {
        return windows
    }

    private func convert(scWindow: SCWindow) -> DetectedWindow {
        let qRect = scWindow.frame
        var cRect = qRect
        
        // Coordinate Conversion: Quartz (Top-Left) -> Cocoa (Bottom-Left)
        // Formula: CocoaY = MainScreenHeight - QuartzMaxY
        cRect.origin.y = primaryScreenHeight - qRect.maxY
        
        return DetectedWindow(
            id: scWindow.windowID,
            frame: cRect,
            title: scWindow.title,
            appName: scWindow.owningApplication?.applicationName,
            zOrder: scWindow.windowLayer,
            originalFrame: qRect
        )
    }
}
