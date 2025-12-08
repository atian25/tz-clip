# 全局技术架构与开发规范

## 1. 开发环境与构建 (Dev Environment & Build)

### 1.1 构建工具
*   **Swift Package Manager (SPM)**:
    *   作为项目的主构建系统，不使用 `.xcodeproj` 作为核心配置（虽然最终可能需要生成它以进行某些调试）。
    *   通过 `Package.swift` 管理依赖和 Target。
*   **构建脚本**:
    *   编写 `Makefile` 或 `Justfile` 封装常用命令（build, run, test, clean）。
    *   **自动构建与重启**: 提供一个 Watch 模式的脚本（基于 `fswatch` 或类似工具），监听源码变动 -> 自动编译 -> 杀死旧进程 -> 启动新进程。

### 1.2 权限调试痛点 (Permissions)
*   **问题**: macOS 的屏幕录制 (Screen Recording) 和辅助功能 (Accessibility) 权限是绑定到 **Bundle ID + 代码签名** 的。每次重新编译（特别是非 Xcode 环境下的临时构建）可能会改变二进制签名，导致系统认为是一个新应用，频繁弹窗或权限失效。
*   **解决方案**:
    1.  **固定代码签名 (Code Signing)**: 在构建脚本中，显式执行 `codesign` 命令，使用一个自签名的证书（Ad-hoc 或本地开发证书）对二进制文件进行签名，并保持 Entitlements 文件一致。
    2.  **TCC 数据库重置 (Fallback)**: 如果遇到顽固的权限问题，提供一个脚本命令 `make reset-perms`，使用 `tccutil reset ScreenCapture [BundleID]` 快速重置。
    3.  **调试模式**: 在开发阶段，可以通过 `Info.plist` 或启动参数注入，跳过部分非核心的权限检查逻辑，防止阻塞 UI 调试。

## 2. 核心架构模式 (Core Architecture)

### 2.1 应用生命周期
*   **Entry Point**: `@main` (SwiftUI App) 或 `NSApplicationDelegate`。
*   **无停靠栏模式**: `LSUIElement = YES` (Info.plist)，应用启动后不显示在 Dock 上。
*   **菜单栏常驻 (Status Bar)**:
    *   由于隐藏了 Dock 图标，必须在 macOS 菜单栏（右上角）提供一个常驻图标 (`NSStatusItem`)。
    *   **职责**: 提供应用状态指示、快速设置入口以及 **退出应用 (Quit)** 的显式途径。
    *   **实现**: 使用 `NSStatusBar.system.statusItem`，并配置下拉菜单 (`NSMenu`)。
*   **焦点抢占 (Activation)**:
    *   **问题**: `LSUIElement` 应用在后台启动后，难以通过 `NSApp.activate` 抢占系统焦点，导致无法响应全局快捷键（如 ESC）。
    *   **解决方案**: 在进入截图模式前，临时将 `ActivationPolicy` 切换为 `.regular`，调用 `activate(ignoringOtherApps: true)`，然后再切回（或在截图结束后切回）。

### 2.2 安全网 (Safety Net)
*   **退出机制**:
    *   **CMD+Q 支持**: 必须通过 `SelectionView.keyDown` 显式监听 `Cmd+Q`，调用 `NSApp.terminate`。
    *   **菜单项**: 状态栏菜单必须包含 "Quit TZClip" 选项。
*   **全局 ESC 监听**:
    *   **两级退出**: 
        1. 有选区时 -> 清除选区。
        2. 无选区时 -> 退出截图模式。
    *   **实现**: 在 `SelectionView` 和 `AppDelegate` 双重监听，确保无论焦点在哪里都能响应。

### 2.3 交互细节 (Interaction)
*   **工具栏事件分发**:
    *   由于 `SelectionView` 覆盖全屏，工具栏作为子视图容易被遮挡或事件被父视图拦截。
    *   **HitTest**: 必须重写 `SelectionView.hitTest`，优先检测并返回工具栏视图，确保按钮可点击。
*   **防误触**:
    *   点击选区外部不应立即重置选区，必须配合拖拽检测（阈值 > 3px）才开始新选区，防止用户误点导致选区丢失。

### 2.4 模块化 (Modularity)
*   **Core**: 包含截图引擎、窗口管理、权限管理等底层逻辑。
*   **UI**: 包含 SwiftUI 视图、工具栏、标注画板。
*   **Features**: 独立的业务模块（如 PinWindow, OCRService）。

## 3. 关键技术决策
*   **最低版本**: macOS 13.0 (Ventura)。
*   **语言版本**: Swift 5.9。
