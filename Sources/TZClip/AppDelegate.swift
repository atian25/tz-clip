import Cocoa

extension Notification.Name {
    static let stopCapture = Notification.Name("TZClip.stopCapture")
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var overlayControllers: [OverlayWindowController] = []
    var statusItem: NSStatusItem?
    
    // Window Detection Provider
    var windowInfoProvider: Any? // Using Any to avoid availability check issues in property declaration if simpler
    // Or better:
    private var _windowInfoProvider: Any?
    
    @available(macOS 12.3, *)
    var windowProvider: WindowInfoProvider {
        if _windowInfoProvider == nil {
            _windowInfoProvider = WindowInfoProvider()
        }
        return _windowInfoProvider as! WindowInfoProvider
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("Application did finish launching")
        
        // 初始状态为 Accessory
        NSApp.setActivationPolicy(.accessory)
        
        setupStatusBar()
        setupGlobalShortcuts()
        
        NotificationCenter.default.addObserver(forName: .stopCapture, object: nil, queue: .main) { [weak self] _ in
            self?.stopCapture()
        }
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "viewfinder", accessibilityDescription: "TZClip")
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Start Capture", action: #selector(startCapture), keyEquivalent: "1"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "About TZClip", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit TZClip", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem?.menu = menu
    }
    
    @objc func startCapture() {
        print("Starting capture...")
        stopCapture()
        
        // 【关键修改】临时切换为 Regular 模式以强制抢占焦点
        NSApp.setActivationPolicy(.regular)
        
        // 异步启动流程，避免阻塞主线程（虽然 startCapture 是 @objc，但我们可以用 Task）
        Task {
            // 0. 预检查权限 (macOS 10.15+)
            let preflight = CGPreflightScreenCaptureAccess()
            if !preflight {
                print("CGPreflightScreenCaptureAccess returned false. System dialog MIGHT appear, or we might be blocked.")
                // 不立即返回，尝试继续，因为有时候 preflight 不准
            }
            
            // 1. 尝试获取窗口信息。
            var success = false
            if #available(macOS 12.3, *) {
                print("Requesting window info...")
                let provider = self.windowProvider
                // 如果 preflight 失败，这里的调用可能会再次触发系统弹窗，或者直接失败
                success = await provider.captureWindows()
                if success {
                    print("Window info captured successfully.")
                } else {
                    print("Failed to capture window info.")
                }
            }
            
            // 2. 显示 Overlay
            // 逻辑修改：只要 captureWindows 成功，就显示。
            // 如果 captureWindows 失败，且 preflight 也失败，那才弹我们的 Alert。
            if success {
                await MainActor.run {
                    self.showOverlayWindows()
                }
            } else {
                // 只有在真的拿不到数据时，才恢复状态并提示
                await MainActor.run {
                     NSApp.setActivationPolicy(.accessory)
                     if !preflight {
                         self.showPermissionAlert()
                     }
                }
            }
        }
    }
    
    private func showPermissionAlert() {
        // 确保 Alert 在前台显示
        NSApp.activate(ignoringOtherApps: true)
        
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = "Please allow screen recording in System Settings -> Privacy & Security -> Screen Recording, then restart the app."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    private func showOverlayWindows() {
        let mouseLocation = NSEvent.mouseLocation
        
        for screen in NSScreen.screens {
            var controller: OverlayWindowController
            if #available(macOS 12.3, *) {
                controller = OverlayWindowController(screen: screen, windowProvider: self.windowProvider)
            } else {
                controller = OverlayWindowController(screen: screen)
            }
            
            overlayControllers.append(controller)
            
            // 关键：根据鼠标位置决定哪个窗口是 Key Window
            if NSMouseInRect(mouseLocation, screen.frame, false) {
                print("Mouse on screen: \(screen.localizedName)")
                // 强制提升层级并激活
                controller.window?.makeKeyAndOrderFront(nil)
                controller.window?.makeFirstResponder(controller.window?.contentView)
            } else {
                controller.window?.orderFront(nil)
            }
        }
        
        // 强制激活应用，确保第一次点击就能响应
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func stopCapture() {
        print("Stopping capture...")
        for controller in overlayControllers {
            controller.close()
        }
        overlayControllers.removeAll()
        
        // 恢复为 Accessory 模式
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true) // 再次激活以刷新状态
    }
    
    private func setupGlobalShortcuts() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC
                if let self = self, !self.overlayControllers.isEmpty {
                    self.stopCapture()
                    return nil
                }
            }
            return event
        }
    }
    
    @objc func quitApp() {
        NSApp.terminate(nil)
    }
    
    @objc func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }
}
