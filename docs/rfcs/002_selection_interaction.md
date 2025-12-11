# RFC 002: 选区交互优化 (Selection Interaction)

Status: Implemented

## 1. 背景与目标
为了提供专业级的截图体验，除了支持自由选区的**移动 (Move)** 和 **调整大小 (Resize)** 外，还应支持**智能窗口识别 (Smart Window Detection)**，使用户能一键选中当前悬停的窗口，提升截图效率。

## 2. 核心功能设计 (Core Features)

### 2.1 交互状态机 (Interaction State Machine)
引入明确的状态管理，替代当前简单的 `isDraggingSelection` 布尔值。

```swift
enum InteractionState {
    case idle               // 空闲（无选区）
    case creating           // 正在创建新选区（拖拽中）
    case selected           // 选区已创建（静态展示）
    case moving             // 正在移动整个选区
    case resizing(Handle)   // 正在调整大小（Handle 指示方向）
}

enum Handle {
    case topLeft, top, topRight
    case left, right
    case bottomLeft, bottom, bottomRight
}
```

### 2.2 鼠标交互逻辑
*   **Hover (鼠标悬停)**:
    *   在选区内部 -> 显示移动光标 (`openHand` 或 `crosshair`)。
    *   在选区边缘/手柄 -> 显示调整光标 (`resizeUpDown`, `resizeLeftRight`, 等)。
    *   在选区外部 -> 显示默认光标（准备创建新选区）。
*   **Drag (鼠标拖拽)**:
    *   根据 `mouseDown` 时的位置决定进入 `creating`, `moving` 还是 `resizing` 状态。
    *   **Moving**: 更新 `selectionRect.origin`。
    *   **Resizing**: 根据手柄方向更新 `selectionRect` 的 `origin` 或 `size`。
    *   **Creating**: 清除旧选区，重新绘制。

### 2.3 键盘微调
*   **方向键**: 移动选区 1px。
*   **Shift + 方向键**: 移动选区 10px。
*   **Option + 方向键**: 调整选区大小（增加/减少 1px，默认调整右下角）。

### 2.4 视觉辅助设计 (Visual Aids)

#### 实时尺寸显示 (Size Indicator)
*   **内容**: 显示当前选区的宽度和高度，格式为 `W x H` (例如 `400 x 300`)。
*   **位置**: 
    *   默认显示在选区左上角的上方。
    *   如果上方空间不足，自动移动到选区内部或下方。
*   **样式**: 黑色半透明背景，白色文字，圆角矩形，清晰易读。
*   **时机**: 仅在 `creating`, `moving`, `resizing`, `selected` 状态下显示。

#### 屏幕边缘吸附 (Screen Edge Snapping)
*   **触发条件**: 当选区的任意边缘距离屏幕边缘（Top, Bottom, Left, Right）小于阈值（例如 10px）时。
*   **行为**: 
    *   **吸附**: 自动将选区边缘对齐到屏幕边缘。
    *   **反馈**: 显示一条贯穿屏幕的辅助线（Snap Guide），提示用户已吸附。
*   **覆盖**: 按住 `Cmd` 键可以临时禁用吸附功能（可选）。

#### 十字辅助线 (Crosshair Guides)
*   **内容**: 显示跟随鼠标的水平和垂直贯穿线（全屏长度）。
*   **时机**: 仅在 `idle` 状态（准备创建选区）时显示，且需在初始化完成后（`SelectionView.isInitialized == true`）才启用。开始创建或选区已存在时，十字线隐藏。
*   **样式**: 细实线或虚线，半透明白色/灰色，不干扰视线。
*   **坐标**: 可选在中心显示当前 (x, y) 坐标（本次暂不实现坐标数值显示，仅显示线条）。

### 2.5 智能窗口识别 (Smart Window Detection)
*   **前提**: 仅在 `InteractionState.idle`（无选区）状态下生效。
*   **Hover (悬停)**:
    *   系统实时检测鼠标下方的窗口。
    *   **视觉反馈**: 在识别到的窗口区域显示**高亮遮罩**（例如：淡蓝色半透明填充 + 蓝色边框）。此高亮层应独立于 `SelectionView` 的橡胶圈。
*   **Click (点击)**:
    *   如果当前有高亮窗口，点击立即将该窗口的 Frame 设置为 `selectionRect`。
    *   状态流转: `idle` -> `selected`。
*   **Drag (拖拽)**:
    *   监测到拖拽位移（> 3px）时，**忽略**当前高亮窗口，进入 `creating` 状态绘制自由选区。
*   **辅助控制**:
    *   **Cmd 键**: 按住时临时禁用窗口识别（避免误选）。

## 3. 技术架构 (Technical Architecture)

### 3.1 绘制与交互
*   **手柄绘制**: 在 `draw(_:)` 方法中，当状态为 `selected` 时，在选区的 8 个关键点绘制白色圆点。
*   **命中检测**: 定义 `func handle(at point: NSPoint) -> Handle?`，优先检测手柄。
*   **尺寸绘制**: 在 `draw(_:)` 中绘制 `NSAttributedString`。
*   **十字线绘制**: 在 `draw(_:)` 中根据 `cursorLocation` 绘制路径。

### 3.2 吸附算法
在 `mouseDragged` 更新位置时介入：
1.  **计算目标位置**: 根据鼠标位移计算出的原始 `newRect`。
2.  **检测吸附**: 计算边缘距离，若小于阈值则强制修正。
3.  **绘制辅助线**: 根据吸附状态绘制线条。

### 3.3 窗口识别技术
*   **数据源**: 使用 `ScreenCaptureKit` (`SCShareableContent`) 获取窗口信息。
*   **预加载 (Pre-fetching)**: 在截图开始时一次性获取所有窗口信息，避免实时获取的延迟。
*   **初始化 gating**: 在窗口信息采集完成之前，`SelectionView` 不显示窗口高亮（`highlightWindowRect == nil`），避免用户误以为已完成初始化；采集成功后再启用高亮与点击吸附。
*   **坐标转换**: 需将 SCK 的 `CGRect` (左上角原点) 转换为 Cocoa 的 `CGRect` (左下角原点)，并处理多屏幕坐标偏移。
*   **智能过滤**:
    *   排除桌面背景、Dock、自身窗口。
    *   实现 **智能容器** 逻辑：当命中某应用时，优先选择包含鼠标且面积最大的主容器窗口，而非局部子视图。

## 4. 实施计划 (Implementation Plan)

- [x] **Core Interaction (已完成)**:
    - 重构状态管理。
    - 实现手柄绘制。
    - 实现光标更新。
    - 实现拖拽逻辑 (Move/Resize)。
    - 实现键盘微调。
- [x] **Visual Aids (已完成)**:
    - 实现尺寸显示。
    - 实现吸附逻辑与辅助线。
    - 实现十字辅助线 (Crosshair Guides)。
- [x] **Window Detection (Phase 3)**:
    - [x] 实现 `WindowInfoProvider`。
    - [x] 实现窗口高亮绘制。
    - [x] 集成点击选中逻辑。
