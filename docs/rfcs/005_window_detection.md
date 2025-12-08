# RFC 005: 智能窗口识别与吸附 (Smart Window Detection)

Status: Draft

## 1. 背景与目标
为了提升截图效率，用户在截取特定应用窗口时，不应需要手动对齐边缘。系统应自动识别鼠标当前悬停的窗口，并提供一键选中的能力。同时，该功能不能干扰用户绘制自由选区的操作。

## 2. 交互设计

### 2.1 混合模式 (Hybrid Mode)
我们采用“混合模式”，即默认同时支持窗口识别和自由选区，通过用户操作意图（点击 vs 拖拽）来区分。

*   **前提**: 仅在 `InteractionState.idle`（无选区）状态下生效。
*   **Hover (悬停)**:
    *   系统实时检测鼠标下方的窗口。
    *   **视觉反馈**: 在识别到的窗口区域显示**高亮遮罩**（例如：淡蓝色半透明填充 + 蓝色边框）。
    *   注意：此高亮层应独立于 `SelectionView` 的橡胶圈，表明这是一个“建议”而非最终选区。
*   **Click (点击)**:
    *   如果当前有高亮窗口，点击立即将该窗口的 Frame 设置为 `selectionRect`。
    *   状态流转: `idle` -> `selected`。
*   **Drag (拖拽)**:
    *   只要监测到鼠标拖拽位移（> 3px），立即**忽略**当前的窗口高亮。
    *   按原逻辑开始绘制自由选区。
    *   状态流转: `idle` -> `creating`。

### 2.2 辅助控制
*   **Cmd 键**: 按住 `Cmd` 键时，**临时禁用**窗口识别功能（避免在窗口密集的区域误选）。
*   **Space 键 (可选)**: 许多截图软件（包括 macOS 原生）使用空格键在“自由模式”和“窗口模式”间切换。考虑到我们的“混合模式”已足够直观，暂不强制引入空格切换，除非混合模式误触率高。

## 3. 技术实现细节

### 3.1 数据源: ScreenCaptureKit
使用 macOS 12.3+ 引入的 `ScreenCaptureKit` (SCK) 获取窗口信息。

*   **API**: `SCShareableContent.current`
*   **过滤**: 
    *   排除 `excludeDesktopWindows: true` (桌面背景)。
    *   排除本应用自己的窗口 (Overlay Window, Status Bar Item)。
    *   排除透明度过低或 Frame 异常的窗口。

### 3.2 性能优化: 预加载 (Pre-fetching)
`SCShareableContent` 的获取是异步且相对耗时（可能需几十毫秒），不能在 `mouseMoved` 中实时调用。

*   **策略**: 在截图会话开始的瞬间（`OverlayWindowController` 初始化或 `viewWillAppear` 时），**一次性获取**当前所有屏幕的窗口列表并缓存。
*   **假设**: 在截图过程中，用户不太可能移动其他应用的窗口。

### 3.3 坐标系转换 (Coordinate Conversion)
这是一个关键痛点。
*   **SCK / Quartz**: 原点在屏幕**左上角**，Y 轴向下。
*   **Cocoa / NSView**: 原点在屏幕**左下角**，Y 轴向上。
*   **多屏处理**: `NSScreen.frame` 的原点可能为负值。需要将 SCK 的 `CGRect` 准确映射到 `OverlayWindow` 的坐标系中。

### 3.4 命中测试与智能容器识别 (Hit Testing & Smart Container)
*   **Z-Order 排序**: 窗口列表必须严格按照层级 (Layer) 降序和索引 (Index) 升序排列，以确保选中的是视觉上最顶层的窗口。
*   **智能容器 (Smart Container)**:
    *   现代 macOS 应用通常由多个窗口组成（如侧边栏、内容区、标题栏可能是分离的 `SCWindow`）。
    *   如果简单地返回命中的第一个窗口，往往只能选中某个局部区域（如仅仅是微信的内容区）。
    *   **策略**: 当命中某个应用的窗口时，查找该应用下**包含**鼠标位置且**面积最大**的窗口（通常是主窗口容器），将其作为最终结果。这能极大提升选中体验。
*   **系统窗口过滤**:
    *   排除 "Dock" (程序坞)、"Wallpaper" (壁纸) 等系统层级窗口，避免误选背景。
    *   支持本地化名称匹配（如中文环境下的 "程序坞"）。

## 4. 模块结构
新增 `WindowInfoProvider` 类负责数据获取与处理。

```swift
struct DetectedWindow {
    let id: UInt32
    let frame: CGRect // 已转换为 Cocoa 坐标系
    let title: String?
    let appName: String?
}

class WindowInfoProvider {
    func captureWindows() async throws -> [DetectedWindow]
    func window(at point: NSPoint) -> DetectedWindow?
}
```

## 5. 任务分解
1.  **Core Logic**: 实现 `WindowInfoProvider`，集成 `ScreenCaptureKit`，处理坐标转换。
2.  **Visuals**: 在 `SelectionView` 中添加 `highlightWindowRect` 属性和相应的绘制逻辑（高亮遮罩）。
3.  **Interaction**: 修改 `mouseMoved` 和 `mouseDown` 逻辑，接入窗口检测。
