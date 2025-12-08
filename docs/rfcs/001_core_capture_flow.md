# RFC 001: 核心截图与标注流程 (MVP)

## 1. 需求描述 (Requirements)

### 1.1 核心流程
1.  **触发**: 用户按下快捷键。
2.  **选择**: 进入全屏遮罩模式，用户进行区域选择（支持混合模式：拖拽坐标 / 窗口吸附）。
3.  **确认**: 鼠标松开后，选区固定，显示**悬浮工具栏**。
4.  **操作**:
    *   **标注**: 用户点击工具栏上的标注工具（画笔、箭头、矩形等），直接在选区上绘制。
    *   **输出**: 用户点击“复制”、“保存”或“取消”。
    *   **Pin/长截图/OCR**: (暂不包含在 MVP 核心流程，留作后续 RFC 扩展)。

### 1.2 关键交互细节
*   **混合选择**:
    *   默认状态下鼠标 hover 会高亮识别到的窗口。
    *   一旦鼠标按下并拖动，立即切换为自由矩形选择。
*   **工具栏**:
    *   紧贴选区下方或上方（自动避让屏幕边缘）。
    *   MVP 包含按钮：`矩形`、`箭头`、`画笔`、`马赛克`、`复制(默认)`、`保存`、`取消`。

## 2. 技术实现 (Technical Implementation)

### 2.1 窗口管理 (Window Management)
*   使用 `NSWindow` 创建一个全屏、无边框、透明背景的窗口 (`OverlayWindow`)。
*   `OverlayWindow` 级别设为 `.screenSaver` 或 `.status`，覆盖 Dock 和菜单栏。
*   支持多显示器：为每个显示器创建一个 `OverlayWindow`。

### 2.2 选区与绘制 (Selection & Drawing)
*   **视图层级**:
    *   `BackgroundLayer`: 黑色半透明遮罩 (0.3 alpha)。
    *   `SelectionLayer`: 透明，显示选中的清晰区域（通过 `CAShapeLayer` 挖空背景）。
    *   `AnnotationLayer`: 用于承载用户的标注绘制。
*   **混合选择逻辑**:
    *   利用 `ScreenCaptureKit` 或 `CGWindowList` 缓存所有窗口 Frame。
    *   `mouseMoved`: 碰撞检测 -> 更新高亮 Frame。
    *   `mouseDragged`: 禁用碰撞检测 -> 更新矩形 Frame。

### 2.3 图像捕获 (Capture)
*   使用 `ScreenCaptureKit` 的 `SCShareableContent` 获取屏幕快照。
*   最终输出 = 原始屏幕图像 (Crop 到选区) + AnnotationLayer 的内容合成。

## 3. 待办事项 (Todos)
- [ ] 原型验证：ScreenCaptureKit 获取窗口信息的延迟测试。
- [ ] 原型验证：多屏下的坐标系转换准确性。
