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
*   **无停靠栏模式**: `LSUIElement = YES` (Info.plist)，应用启动后不显示在 Dock 上，仅驻留 Menu Bar。

### 2.2 安全网 (Safety Net)
*   **全局 ESC 监听**:
    *   在 `NSApplication` 层级或通过 `CGEventTap` 注册一个最高优先级的事件监听器。
    *   **逻辑**: 只要按下 `ESC` (或 `Cmd+Q` / `Cmd+W` 组合)，强制调用 `exit(0)` 或重置所有 UI 状态。这在开发“全屏遮罩”类应用时至关重要，防止 UI 锁死导致无法操作电脑。

### 2.3 模块化 (Modularity)
*   **Core**: 包含截图引擎、窗口管理、权限管理等底层逻辑。
*   **UI**: 包含 SwiftUI 视图、工具栏、标注画板。
*   **Features**: 独立的业务模块（如 PinWindow, OCRService）。

## 3. 关键技术决策
*   **最低版本**: macOS 13.0 (Ventura)。
*   **语言版本**: Swift 5.9。
