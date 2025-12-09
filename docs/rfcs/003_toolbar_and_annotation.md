# RFC 003: 标注工具栏与绘制 (Toolbar & Annotation)

Status: Partially Implemented (MVP Tools & Properties Done)

## 1. 背景与目标 (Background & Goals)
在用户确定截图选区后，需要提供一组工具以便用户对截图内容进行标记、修饰或执行后续操作（如复制、保存）。
本 RFC 定义了标注工具栏的 UI 结构、交互逻辑以及底层的绘制实现方案。

**目标**:
*   提供直观、悬浮的工具栏，跟随选区位置。
*   支持基础图形绘制（矩形、椭圆、直线、箭头）。
*   支持自由绘制（画笔）和文本输入。
*   支持高级标注（序号、马赛克）。
*   支持对已绘制内容的二次编辑（移动、缩放、属性修改）。
*   提供**次级属性面板**，用于精细调整颜色、粗细、透明度等属性。

## 2. 核心功能设计 (Core Features)

### 2.1 主工具栏 (Main Toolbar)
*   **位置**: 默认显示在选区右下角外部。如果底部空间不足，自动调整至选区内部底部或上方。
*   **样式**: 圆角矩形背景，图标排列，支持 Hover 效果。
*   **工具列表 (Tools)** (从左至右):
    1.  **矩形 (Rectangle)**: 绘制矩形框。
    2.  **椭圆 (Ellipse)**: 绘制椭圆/圆。
    3.  **直线 (Line)**: 绘制直线。
    4.  **箭头 (Arrow)**: 绘制带箭头的直线。
    5.  **画笔 (Pen)**: 自由手绘路径。
    6.  **文字 (Text)**: 插入文本标签。
    7.  **马赛克 (Mosaic)**: 区域模糊/像素化 (TODO)。
    8.  **序号 (Counter)**: 自动递增的圆形数字标记 (①, ②, ③...) (TODO)。

*   **交互优化**:
    *   移除独立的“选择”工具按钮。
    *   **Toggle 模式**: 点击当前已激活的工具按钮，即可取消激活，回到默认的“选择/移动”模式。
*   **操作列表 (Actions)** (分隔符后):
    1.  **贴图 (Pin)**: 将截图选区作为悬浮窗固定在屏幕顶层。
    2.  **撤销 (Undo)**: 撤销上一步绘制。
    3.  **OCR**: 识别并提取文字。
    4.  **关闭 (Close)**: 取消截图 (`Esc`)。
    5.  **长截图 (Scroll)**: 滚动截屏。
    6.  **保存 (Save)**: 保存选区内容为文件。
    7.  **确认 (Confirm)**: 复制选区内容到剪贴板并退出 (`Enter`)。

### 2.2 次级属性面板 (Secondary Properties Bar)
*   **触发**: 当选择了某个绘图工具（不含 Text/Mosaic/Eraser），或选中了某个已存在的标注时显示。
*   **位置**: 紧贴主工具栏下方，与主工具栏左对齐或居中对齐。
*   **布局**: 分为两行或紧凑排列。
*   **内容**:
    *   **尺寸与样式**:
        *   **粗细 (Stroke Width)**: 提供滑块 (Slider) 或分档按钮 (S/M/L)，并显示具体数值 (px)。
        *   **透明度 (Opacity)**: 提供滑块 (0-100%)，用于调整描边或填充的不透明度。
    *   **颜色选择 (Color Picker)**:
        *   **预设色块**: 提供一组高频使用的颜色（红、橙、黄、绿、蓝、紫、黑、白）。
        *   **当前颜色**: 显示当前选中颜色的预览。
        *   **调色盘**: 点击可打开系统调色盘进行自定义。

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
└── AnnotationPropertiesView (NSView - Secondary Toolbar)
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
*   **属性**: `id`, `type`, `color`, `lineWidth`, `opacity`, `bounds`。
*   **方法**:
    *   `draw(in context: CGContext)`
    *   `contains(point: CGPoint) -> Bool`
    *   `move(by translation: CGPoint) -> Annotation`
*   **实现**: `RectangleAnnotation`, `EllipseAnnotation`, `LineAnnotation`, `TextAnnotation`, `CounterAnnotation` 等。

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
- [ ] **Step 5: 属性面板升级 (Current Task)**
    - [ ] 重构 `AnnotationPropertiesView` UI。
    - [ ] 增加**透明度**支持。
    - [ ] 增加**粗细滑块**支持。
- [ ] **Step 6: 高级标注工具 (Phase 2)**
    - [ ] 实现**序号 (Counter)** 工具。
    - [ ] 实现**马赛克 (Mosaic)** 工具。
- [ ] **Step 7: 文字工具完善**
    - 集成 `NSTextView` 进行文本输入。
    - 渲染文本标注。
- [x] **Step 8: 操作落地**
    - [x] 实现复制 (Copy) 和保存 (Save) 功能。
    - 实现贴图 (Pin) 功能 (Phase 2)。
    - 实现 OCR (Phase 3)。
    - 实现长截图 (Phase 3)。
