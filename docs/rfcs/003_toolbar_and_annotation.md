# RFC 003: 标注工具栏与绘制 (Toolbar & Annotation)

Status: Partially Implemented (MVP Tools & Properties Done)

## 1. 背景与目标 (Background & Goals)
在用户确定截图选区后，需要提供一组工具以便用户对截图内容进行标记、修饰或执行后续操作（如复制、保存）。
本 RFC 定义了标注工具栏的 UI 结构、交互逻辑以及底层的绘制实现方案。

**目标**:
*   提供直观、悬浮的工具栏，跟随选区位置。
*   支持基础图形绘制（矩形、椭圆、直线、箭头）。
*   支持自由绘制（画笔）和文本输入。
*   支持对已绘制内容的二次编辑（移动、缩放、属性修改）。
*   提供次级属性面板，用于调整颜色、粗细、字体样式。

## 2. 核心功能设计 (Core Features)

### 2.1 主工具栏 (Main Toolbar)
*   **位置**: 默认显示在选区右下角外部。如果底部空间不足，自动调整至选区内部底部或上方。
*   **工具列表**:
    1.  **选择 (Select)**: 用于选中、移动、调整已绘制的图形。
    2.  **矩形 (Rectangle)**: 绘制矩形框。
    3.  **椭圆 (Ellipse)**: 绘制椭圆/圆。
    4.  **直线 (Line)**: 绘制直线。
    5.  **箭头 (Arrow)**: 绘制带箭头的直线。
    6.  **画笔 (Pen)**: 自由手绘路径。
    7.  **文字 (Text)**: 插入文本标签。
    8.  **马赛克 (Mosaic)**: (Phase 2) 区域模糊。
*   **操作列表**:
    1.  **撤销 (Undo)**: 撤销上一步绘制。
    2.  **复制 (Copy)**: 复制选区内容（含标注）到剪贴板。
    3.  **保存 (Save)**: 保存选区内容为文件。
    4.  **贴图 (Pin)**: (Phase 4) 将截图固定在屏幕上。
    5.  **关闭 (Close)**: 退出截图。

### 2.2 属性面板 (Properties Panel)
*   **触发**: 当选择了某个绘图工具，或选中了某个已存在的标注时显示。
*   **内容**:
    *   **颜色**: 预设一组常用颜色（红、黄、绿、蓝、白、黑等）。
    *   **粗细 (Size)**: S (2px), M (4px), L (8px)。
    *   **文字样式**: 仅在文字工具下显示，如 **加粗 (Bold)**、字号。

### 2.3 交互逻辑 (Interaction)
*   **绘制 (Creating)**:
    *   按下鼠标 -> 拖动 -> 释放。
    *   `Shift` 键约束：正方形、正圆、水平/垂直/45度直线。
*   **选择与编辑 (Selecting & Editing)**:
    *   点击已有图形自动进入选择模式。
    *   **移动**: 拖动图形主体。
    *   **缩放**: 拖动图形周围的 8 个控制点 (Handles)。`Shift` 键保持比例。
    *   **删除**: 选中后按 `Delete` / `Backspace`。
    *   **属性修改**: 选中图形后，改变属性面板设置，实时应用到图形。

## 3. 技术架构 (Technical Architecture)

### 3.1 视图层级
```
SelectionView (NSView)
├── SelectionOverlay (选区遮罩与边框)
├── AnnotationOverlayView (NSView)
│   └── (Custom Draw Loop via draw(_:))
├── AnnotationToolbar (NSView - Subview or Sibling)
└── AnnotationPropertiesView (NSView)
```

### 3.2 核心类设计

#### `AnnotationOverlayView`
*   **职责**: 负责管理所有标注数据并执行绘制。
*   **状态**:
    *   `annotations: [Annotation]`
    *   `currentTool: AnnotationType`
    *   `selectedAnnotationID: UUID?`
    *   `dragAction: DragAction` (creating, moving, resizing)
*   **方法**:
    *   `draw(_:)`: 遍历 `annotations` 调用其 `draw(in:)` 方法。
    *   `mouseDown/dragged/Up`: 处理绘制和编辑手势。

#### `Annotation` (Protocol)
*   **属性**: `id`, `type`, `color`, `lineWidth`, `bounds`。
*   **方法**:
    *   `draw(in context: CGContext)`
    *   `contains(point: CGPoint) -> Bool`
    *   `move(by translation: CGPoint) -> Annotation`
*   **实现**: `RectangleAnnotation`, `EllipseAnnotation`, `LineAnnotation`, `TextAnnotation`, etc.

#### `AnnotationToolbar` & `PropertiesView`
*   纯 UI 组件，通过 `Delegate` 或 `Closure` 与 `SelectionView` 通信。
*   `SelectionView` 作为控制器协调 Toolbar 和 OverlayView 的状态。

## 4. 实施计划 (Implementation Plan)

- [x] **Step 1: 基础架构**
    - 定义 `Annotation` 数据模型。
    - 创建 `AnnotationOverlayView` 并集成到 `SelectionView`。
- [x] **Step 2: 工具栏 UI**
    - 实现 `AnnotationToolbar` 按钮布局。
    - 实现工具切换逻辑。
- [x] **Step 3: 基础图形绘制**
    - 实现矩形、椭圆、直线、箭头的拖拽绘制。
    - 实现 `draw(_:)` 渲染循环。
- [x] **Step 4: 选择与编辑**
    - 实现点击命中测试 (`Hit Test`)。
    - 实现拖拽移动。
    - 实现 Resize Handles 和变形逻辑。
- [x] **Step 5: 属性面板**
    - 实现 `AnnotationPropertiesView`。
    - 联动颜色和粗细调整。
- [x] **Step 6: 文字工具**
    - 集成 `NSTextView` 进行文本输入。
    - 渲染文本标注。
- [ ] **Step 7: 操作落地**
    - 实现复制 (Copy) 和保存 (Save) 功能 (Phase 2)。

## 6. 实施状态 (Implementation Status)

### 6.1 已完成 (Completed)
- **AnnotationToolbar**: 
  - 实现了所有 MVP 工具按钮（选择、矩形、椭圆、直线、箭头、画笔、文字）。
  - 实现了 HoverButton 效果。
- **AnnotationPropertiesView**:
  - 实现了动态属性面板（颜色、粗细、加粗）。
  - 支持与选中工具或图形的双向同步。
- **AnnotationOverlayView**:
  - 实现了所有 MVP 图形的绘制与交互。
  - 实现了 `Select` 模式，支持点击选中、拖拽移动、拖拽把手变形。
  - 实现了 `Shift` 键约束（正方形/正圆/45度角）。
  - 实现了 `Delete` 键删除。
  - 实现了文本输入的创建与完成。
- **SelectionView Integration**:
  - 实现了工具栏与属性面板的自动定位与显示。
  - 实现了交互状态机管理。

### 6.2 待实现 (Pending)
- **Actions**:
  - 复制 (Copy) 到剪贴板。
  - 保存 (Save) 到文件。
- **Future Tools**:
  - 马赛克 (Mosaic)。
  - 贴图 (Pin)。
