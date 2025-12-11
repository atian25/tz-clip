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
    - [x] **交互升级 (Interaction State Machine)**:
        - [x] 引入 `InteractionState` (idle, creating, selected, moving, resizing)。
        - [x] 实现选区移动 (Move)。
        - [x] 实现选区调整大小 (Resize) - 8个方向手柄。
        - [x] 光标自适应 (Cursor Management)。
    - [x] **工具栏**:
        - [x] 显示 Cancel / Confirm 按钮。
        - [x] 自动吸附选区右下角（或上方），确保可见性。
        - [x] 交互时自动隐藏工具栏。
        - [x] Cancel 直接退出截图模式。
    - [x] **防误触优化**:
        - [x] 重写 `hitTest` 确保工具栏点击有效。
        - [x] 点击选区外部不重置选区，只有拖拽 (>3px) 才重置。
- [x] **混合模式 (Smart Window Detection)**:
    - [x] 引入 `ScreenCaptureKit` 获取窗口信息。
    - [x] 实现 `WindowInfoProvider` 与 Z-Order 排序。
    - [x] **智能容器识别**: 自动合并应用的子窗口，选中主容器。
    - [x] **视觉反馈**: 悬停高亮（仅边框，无填充），点击吸附。
    - [x] **权限处理**: 自动检测并提示屏幕录制权限，支持 TCC 状态检查。

## 3. 标注与工具栏 (Phase 3: Toolbar & Annotation)

### 3.1 标注工具栏
- [x] **AnnotationToolbar**:
    - [x] 悬浮工具栏设计。
    - [x] 工具按钮: 选择, 矩形, 椭圆, 直线, 箭头, 画笔, 文字。
    - [x] 操作按钮: 撤销, 关闭, 保存, 复制。
- [x] **属性面板 (Secondary Toolbar)**:
    - [x] 动态显示: 根据当前工具或选中图形类型显示。
    - [x] **布局优化**: 3 栏紧凑布局（大小/透明度、颜色矩阵、样式开关）。
    - [x] **颜色选择**: 6 色矩阵（含自定义颜色支持）。
    - [x] **样式支持**:
        - [x] 粗细选择 (Slider 1px-20px)。
        - [x] 不透明度 (Slider 0-100%)。
        - [x] 文字属性: 加粗 (Bold)。
        - [x] 形状属性: 实心填充 (Fill)，圆角矩形 (Rounded)。
    - [x] **交互**: 选中已有标注时自动回显属性，取消选择时自动隐藏。

### 3.2 标注交互核心
- [x] **AnnotationOverlayView**:
    - [x] 绘制层与交互层分离。
    - [x] **图形绘制**: 支持 Rectangle, Ellipse, Line, Arrow, Pen, Text。
    - [x] **选择与编辑**:
        - [x] 点击选中图形。
        - [x] 拖动图形移动。
        - [x] 拖动 Handle 调整大小。
    - [x] **快捷键支持**:
        - [x] `Shift`: 锁定宽高比 (矩形/椭圆) 或 45度角 (直线/箭头)。
        - [x] `Delete/Backspace`: 删除选中标注。
        - [x] `Cmd+Z`: 撤销。
    - [x] **高级渲染**:
        - [x] 支持实心填充（带透明度）。
        - [x] 支持圆角矩形绘制。

## 4. 后续规划 (Next Steps)

### 4.1 操作落地 (Actions)
- [x] **复制 (Copy)**: 将截图选区内容（包含标注）写入剪贴板。
- [x] **保存 (Save)**: 将截图选区内容保存为文件。

### 4.2 高级标注
- [x] **序号工具 (Counter)**: 自动递增、独立交互、智能连线。
- [ ] **马赛克/模糊 (Mosaic/Blur)**: 支持区域模糊处理。
- [x] **文字工具增强**:
    - [x] 支持描边、字体选择、所见即所得编辑。
    - [x] 优化编辑状态隔离与连续输入体验。
    - [ ] 优化序号标注与文字缩放效果（边界清晰度、描边一致性、比例联动）

### 4.3 贴图 (Phase 4: Pin)
- [ ] 将截图固定在屏幕顶层。
