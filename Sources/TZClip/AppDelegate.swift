import Cocoa

extension Notification.Name {
    static let stopCapture = Notification.Name("TZClip.stopCapture")
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var overlayControllers: [OverlayWindowController] = []
    var statusItem: NSStatusItem?
    
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
        
        // 稍微延迟一下，给系统一点反应时间（可选，但在某些旧系统上有用）
        // 这里直接执行，如果不行再加延迟
        
        let mouseLocation = NSEvent.mouseLocation
        
        for screen in NSScreen.screens {
            let controller = OverlayWindowController(screen: screen)
            overlayControllers.append(controller)
            
            if NSMouseInRect(mouseLocation, screen.frame, false) {
                print("Mouse on screen: \(screen.localizedName)")
                controller.window?.makeKeyAndOrderFront(nil)
            } else {
                controller.window?.orderFront(nil)
            }
        }
        
        // 强制激活
        NSApp.activate(ignoringOtherApps: true)
        
        // 【关键修改】切回 Accessory 模式，但在激活后执行
        // 注意：立即切回可能会导致焦点又丢了，所以我们保留 Regular 模式直到截图结束
        // 或者，我们可以尝试先不切回，看看效果。
        // 为了用户体验（不显示 Dock 图标），通常是在 activate 成功后切回。
        // 但为了解决您的问题，我先保持 Regular 模式，看看是否能解决焦点问题。
        // 如果能解决，说明方向对了，后面再优化 Dock 图标隐藏的问题。
        // 修正：保持 Regular 会显示 Dock 图标，这可能不是您想要的，但在 MVP 阶段为了功能优先，
        // 我先让它显示 Dock 图标，验证焦点问题。
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
