# 项目初始化与开发计划

## 1. 项目初始化 (Initialization)

### 1.1 基础结构
- [x] **Swift Package**: 使用 `swift package init --type executable --name TZClip` 初始化项目。
- [x] **Package.swift 配置**:
    - [x] 设置 `platforms: [.macOS(.v13)]`。
    - [x] 定义 Target `TZClip`。
- [x] **Info.plist**:
    - [x] 创建 `Sources/TZClip/Info.plist`。
    - [x] 设置 `LSUIElement` = `true` (无 Dock 模式)。
    - [x] 设置 `NSSupportsAutomaticTermination` = `true`。
    - [x] 设置 `NSHighResolutionCapable` = `true`。

### 1.2 构建与调试系统
- [x] **Makefile**:
    - [x] `make build`: 编译项目。
    - [x] `make run`: 运行项目。
    - [x] `make clean`: 清理构建产物。
    - [x] `make sign`: 使用 Ad-hoc 证书对二进制进行签名（解决权限重置问题）。
    - [x] `make stop`: 停止进程 (`pkill -f TZClip`)。
- [x] **Entitlements**:
    - [x] 创建 `TZClip.entitlements`。
    - [x] 添加 `com.apple.security.device.screen-recording` (虽然是非沙盒，但作为占位符)。
- [x] **开发脚本**:
    - [x] 编写 `scripts/dev.sh` (或 `make watch`)：监听文件变动 -> 自动构建 -> 签名 -> 重启应用。

## 2. 核心功能 MVP 开发 (Phase 1)

### 2.1 应用入口与生命周期
- [x] **main.swift**:
    - [x] 替换默认的 Hello World。
    - [x] 初始化 `NSApplication`。
    - [x] 设置 `AppDelegate`。
- [x] **AppDelegate**:
    - [x] `applicationDidFinishLaunching`: 启动入口（静默启动）。
    - [x] **全局安全网**: 注册全局 `ESC` 键盘监听，触发 `NSApp.terminate(nil)`。
    - [x] **菜单栏常驻 (Status Bar)**:
        - [x] 创建 `NSStatusItem` 常驻右上角。
        - [x] 添加菜单：`Start Capture`, `About`, `Quit (Cmd+Q)`。
        - [x] 确保在无 Dock 模式下也能通过菜单退出。
    - [x] **焦点抢占优化**: 截图开始时临时切换 `ActivationPolicy` 为 `.regular` 并强制激活，解决 ESC 失效问题。

### 2.2 截图遮罩窗口 (Overlay Window)
- [x] **OverlayWindowController**:
    - [x] 创建全屏无边框窗口 (`NSWindow.StyleMask.borderless`)。
    - [x] 设置窗口级别 (`.screenSaver`)。
    - [x] 设置背景色为半透明黑色。
    - [x] **智能激活**: 根据鼠标所在屏幕，优先激活对应的 Overlay Window。
- [x] **多屏支持**:
    - [x] 遍历 `NSScreen.screens`，为每个屏幕创建一个 Overlay Window。

### 2.3 选区交互 (Selection)
- [x] **SelectionView (NSView)**:
    - [x] 响应 `mouseDown`, `mouseDragged`, `mouseUp`。
    - [x] 绘制橡胶圈选框 (Rubber band selection)。
    - [x] **工具栏**:
        - [x] 显示 Cancel / Confirm 按钮。
        - [x] 自动吸附选区右下角（或上方），确保可见性。
        - [x] Cancel 直接退出截图模式。
    - [x] **防误触优化**:
        - [x] 重写 `hitTest` 确保工具栏点击有效。
        - [x] 点击选区外部不重置选区，只有拖拽 (>3px) 才重置。
- [ ] **混合模式基础**:
    - [ ] 引入 `ScreenCaptureKit` 获取窗口信息 (先打通数据获取流程)。

## 3. 后续规划
*   Phase 2: 实现截图捕获与保存。
*   Phase 3: 工具栏与基础标注。
*   Phase 4: Pin 图功能。
