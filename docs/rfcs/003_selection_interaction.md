# RFC 003: 选区交互优化 (Selection Interaction)

Status: Implemented

## 1. 背景与目标
当前的选区功能仅支持“一次性拖拽创建”，一旦创建完成无法修改，只能重新绘制。为了提供专业级的截图体验，必须支持对已有选区的**移动 (Move)** 和 **调整大小 (Resize)**。

## 2. 核心交互设计

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

## 3. 技术实现细节

### 3.1 控制手柄 (Handles)
*   **绘制**: 在 `draw(_:)` 方法中，当状态为 `selected` 时，在选区的 8 个关键点绘制白色圆点（直径 6-8px，带阴影）。
*   **命中检测 (Hit Testing)**:
    *   定义一个 `func handle(at point: NSPoint) -> Handle?`。
    *   优先检测手柄，其次检测选区内部。

### 3.2 光标管理
*   使用 `addTrackingArea` 监控鼠标移动。
*   在 `mouseMoved` 中根据位置设置 `NSCursor`。

### 3.3 边界限制
*   无论是移动还是调整大小，都必须确保 `selectionRect` 不会超出 `SelectionView` (屏幕) 的边界。

## 4. 任务分解
1.  **重构状态管理**: 引入 `InteractionState` 枚举，改造 `SelectionView`。
2.  **实现手柄绘制**: 绘制 8 个控制点。
3.  **实现光标更新**: 添加 TrackingArea，根据 Hover 位置切换光标。
4.  **实现拖拽逻辑**:
    *   支持 Move。
    *   支持 Resize (8个方向)。
5.  **实现键盘微调**: 响应方向键事件。
