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
    1.  **应用打包 (App Bundling)**: 提供 `scripts/package.sh` 脚本，将二进制文件封装为标准的 `.app` 包（包含 `Info.plist` 和资源），确保 Bundle ID 稳定。
    2.  **固定代码签名 (Code Signing)**: 在构建脚本中，显式执行 `codesign` 命令，使用一个自签名的证书（Ad-hoc 或本地开发证书）对二进制文件进行签名，并保持 Entitlements 文件一致。
    3.  **TCC 数据库重置 (Fallback)**: 如果遇到顽固的权限问题，提供一个脚本命令 `make reset-perms`，使用 `tccutil reset ScreenCapture [BundleID]` 快速重置。
    4.  **运行时检查**: 使用 `CGPreflightScreenCaptureAccess()` 预检权限，如果缺失则通过 `NSAlert` 引导用户前往系统设置，避免静默失败。

## 2. 核心架构模式 (Core Architecture)

### 2.1 模块与类职责
虽然目前所有代码都在 `Sources/TZClip` 下，但逻辑上分为以下几个核心模块：

*   **App Lifecycle (`AppDelegate`, `main.swift`)**:
    *   负责应用启动、菜单栏图标 (`NSStatusItem`) 管理、全局快捷键监听。
    *   协调截图会话的开始与结束（管理 `OverlayWindowController` 实例）。
*   **Window Management (`OverlayWindowController`)**:
    *   为每个屏幕创建一个全屏无边框窗口。
    *   负责窗口级别的配置（Level, Background Color, Behavior）。
*   **Selection Logic (`SelectionView`)**:
    *   核心视图，处理所有鼠标交互（点击、拖拽、悬停）。
    *   维护交互状态机 (`InteractionState`: idle, creating, selected, moving, resizing)。
    *   负责绘制选区、手柄、十字光标和高亮框。
    *   **Toolbar Integration**: 协调主工具栏 (`AnnotationToolbar`) 和属性面板 (`AnnotationPropertiesView`) 的显示与布局。
*   **Annotation Layer (`AnnotationOverlayView`)**:
    *   **职责**: 专门负责标注内容的绘制与交互，作为 `SelectionView` 的子视图（覆盖在选区之上）。
    *   **Data Models**: 
        *   `AnnotationModels.swift`: 定义 `Annotation` 协议及具体形状 (`Rectangle`, `Ellipse`, `Arrow`, `Line`, `Pen`, `Text`)。
        *   **Hit Testing**: 每个图形实现 `contains(point)` 用于点击检测。
    *   **Interaction**: 
        *   独立处理标注的绘制 (`creating`)、选择 (`moving`)、变形 (`resizing`)。
        *   支持 `Shift` 键约束（正方形/圆/45度角）。
    *   **Text Editing**: 管理 `NSTextView` 的动态创建与销毁，处理文本输入。
*   **Data Provider (`WindowInfoProvider`)**:
    *   **职责**: 封装 `ScreenCaptureKit`，提供当前屏幕的窗口信息。
    *   **核心能力**: 
        *   获取并过滤窗口列表（排除系统窗口如 Dock/Wallpaper）。
        *   **Z-Order 排序**: 严格按 Layer 降序 + Index 升序排列，确保命中测试符合视觉直觉。
        *   **智能容器识别**: 将子窗口（如内容区）映射回应用的主容器窗口。
        *   **坐标转换**: 处理 Quartz (左上原点) 到 Cocoa (左下原点) 的坐标系转换。

### 2.2 应用生命周期
*   **Entry Point**: `@main` (SwiftUI App) 或 `NSApplicationDelegate`。
*   **无停靠栏模式**: `LSUIElement = YES` (Info.plist)，应用启动后不显示在 Dock 上。
*   **菜单栏常驻 (Status Bar)**:
    *   由于隐藏了 Dock 图标，必须在 macOS 菜单栏（右上角）提供一个常驻图标 (`NSStatusItem`)。
    *   **职责**: 提供应用状态指示、快速设置入口以及 **退出应用 (Quit)** 的显式途径。
    *   **实现**: 使用 `NSStatusBar.system.statusItem`，并配置下拉菜单 (`NSMenu`)。
*   **焦点抢占 (Activation)**:
    *   **问题**: `LSUIElement` 应用在后台启动后，难以通过 `NSApp.activate` 抢占系统焦点，导致无法响应全局快捷键（如 ESC）。
    *   **解决方案**: 在进入截图模式前，临时将 `ActivationPolicy` 切换为 `.regular`，调用 `activate(ignoringOtherApps: true)`，然后再切回（或在截图结束后切回）。

#### 启动流程调整（初始化 gating）
*   **顺序**: 进入截图模式时，先创建并显示各屏幕的遮罩窗口 (`OverlayWindow`)，按鼠标所在屏幕设置为 Key 并激活应用；随后异步采集窗口信息。
*   **初始化 gating**: 在 `SelectionView` 中引入 `isInitialized` 标志，采集成功后才开启十字辅助线与窗口高亮；初始化阶段不改变光标，不显示坐标线，高亮为空，避免用户误判状态。
*   **失败回退**: 采集失败（或权限不足）时，关闭遮罩并恢复 `.accessory`，弹出权限提示引导用户处理。
*   **目的**: 保证第一次点击由遮罩接收、不穿透到底层窗口，同时提供明确的初始化完成信号。

### 2.3 安全网 (Safety Net)
*   **退出机制**:
    *   **CMD+Q 支持**: 必须通过 `SelectionView.keyDown` 显式监听 `Cmd+Q`，调用 `NSApp.terminate`。
    *   **菜单项**: 状态栏菜单必须包含 "Quit TZClip" 选项。
*   **全局 ESC 监听**:
    *   **两级退出**: 
        1. 有选区时 -> 清除选区。
        2. 无选区时 -> 退出截图模式。
    *   **实现**: 在 `SelectionView` 和 `AppDelegate` 双重监听，确保无论焦点在哪里都能响应。

### 2.4 交互细节 (Interaction)
*   **混合模式 (Hybrid Mode)**:
    *   **Idle 状态**: 
        *   同时支持 **窗口识别** (Hover) 和 **自由选区** (Drag)。
        *   鼠标移动时，通过 `WindowInfoProvider` 实时检测下方窗口并高亮（仅边框）。
        *   **点击**: 立即吸附选中高亮窗口，状态流转至 `selected`。
        *   **拖拽**: 忽略窗口高亮，开始绘制橡胶圈，状态流转至 `creating`。
*   **工具栏事件分发**:
    *   由于 `SelectionView` 覆盖全屏，工具栏作为子视图容易被遮挡或事件被父视图拦截。
    *   **HitTest**: 必须重写 `SelectionView.hitTest`，优先检测并返回工具栏视图，确保按钮可点击。
*   **防误触**:
    *   点击选区外部不应立即重置选区，必须配合拖拽检测（阈值 > 3px）才开始新选区，防止用户误点导致选区丢失。

### 2.5 模块化 (Modularity)
*   **Core**: 包含截图引擎 (`SCShareableContent` 封装)、窗口管理、权限管理等底层逻辑。
*   **UI**: 包含 `SelectionView`、工具栏 (`NSStackView` 实现)、标注画板。
*   **Features**: 独立的业务模块（如 PinWindow, OCRService - 待开发）。

## 3. 关键技术决策
*   **最低版本**: macOS 13.0 (Ventura)。
*   **语言版本**: Swift 5.9。
