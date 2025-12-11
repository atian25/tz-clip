# RFC 003: 标注工具栏与绘制 (Toolbar & Annotation)

Status: Implemented

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
    8.  **序号 (Counter)**: 组合标注工具，包含一个自动递增的圆形数字标记 (Badge) 和一个可选的文本说明 (Label)，两者之间通过连线连接。

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
*   **触发**: 当选择了某个绘图工具，或选中了某个已存在的标注时显示。
*   **位置**: 紧贴主工具栏下方（或上方，视屏幕空间而定），左对齐。
*   **布局设计 (Layout)**:
    *   面板采用圆角矩形设计，背景为白色，带有轻微阴影。
    *   **左侧区 (Left Section) - 属性控制**:
        *   **行 1 (Size)**: [图标] + [滑块 (Slider)] + [数值显示 (Value)]。
            *   针对形状: 控制线宽 (1-20px)。
            *   针对文字: 控制字号 (10-100pt)。
        *   **行 2 (Opacity)**: [图标] + [滑块 (Slider)] + [数值显示 (Value)]。
            *   控制不透明度 (0-100%)。
    *   **中间区 (Middle Section) - 颜色选择**:
        *   **3x2 矩阵排列**的圆形色块。
        *   提供 5 种常用颜色（红、品红、蓝、黄、绿） + **自定义颜色按钮**（调用系统色板）。
    *   **右侧区 (Right Section) - 样式/字体**:
        *   **样式分组**：
            *   **描边样式**: 下拉（无/细/中/粗）。
            *   **描边颜色**: 颜色选择。
            *   **填充 (Fill)**: 形状适用；文本隐藏；序号由容器控制。
        *   **字体分组**：
            *   **字体族 (Font)**: 下拉选择（系统与常用字体），固定列宽，超长省略号。
            *   **粗细 (Weight)**: 分段或步进（300/400/500/600/700）。若字体不支持权重，显示 **B** 作为 `bold` 开关，二者不同时出现。

#### 2.2.1 详细属性定义
*   **粗细/字号 (Size)**:
    *   **交互**: 拖拽滑块实时预览。
    *   **数值**: 右侧显示具体数值 (如 "4px" 或 "18pt")。
*   **透明度 (Opacity)**:
    *   **交互**: 拖拽滑块实时调整 alpha 通道。
    *   **数值**: 右侧显示百分比 (如 "80%")。
*   **颜色 (Color)**:
    *   **交互**: 点击色块切换颜色，支持自定义颜色。
    *   **状态**: 选中色块有外圈高亮。

### 2.3 交互逻辑 (Interaction)
*   **绘制 (Creating)**:
    *   按下鼠标 -> 拖动 -> 释放。
    *   `Shift` 键约束：正方形、正圆、水平/垂直/45度直线。
    *   **文字工具**:
        *   **点击**: 在点击处创建文本框，立即开始输入。
        *   **输入**: 支持实时预览（所见即所得），自动横向扩展宽度。
        *   **结束**: 点击画布空白处或按下 `Cmd+Enter` 完成输入。
        *   **独立性**: 连续输入多段文字时，每段文字属性独立，互不干扰。
    *   **序号工具 (Counter)**:
        *   **点击**: 在点击位置生成一个新的序号标记 (Badge)，序号自动递增 (1, 2, 3...)。
        *   **默认状态**: 仅显示序号 Badge，不自动进入文本编辑模式。
        *   **添加说明**: 用户可以通过双击序号 Badge 或相关联的操作来激活文本输入，生成与 Badge 连接的 Label。
*   **选择与编辑 (Selecting & Editing)**:
    *   点击已有图形自动进入选择模式。
    *   **文字编辑**:
        *   **双击**: 进入文字编辑模式。
        *   **状态隔离**: 编辑时创建独立的状态快照，确保全局工具配置不影响当前正在编辑的文字。
        *   **所见即所得**: 编辑框样式（字体、大小、颜色、描边）与原文字完全一致。
    *   **序号编辑**:
        *   **拖拽移动**:
            *   **整体移动**: 拖拽 Badge 或 Label 的非连接点区域，两者保持相对位置一起移动。
            *   **独立移动**: 选中后，可以分别拖拽 Badge 或 Label，两者之间会自动绘制一条连接线 (Connector Line)。
        *   **文本编辑**: 双击 Label 部分（如果存在）或双击 Badge 触发添加/编辑 Label，交互与普通文字工具一致。
        *   **递增逻辑**: 删除中间某个序号后，后续序号自动重新排序 (Reflow) 或保持不变 (取决于实现复杂度，建议 MVP 保持不变，手动调整)。
    *   **移动**: 拖动图形主体。
    *   **缩放**: 拖动图形周围的 8 个控制点 (Handles)。`Shift` 键保持比例。
    *   **删除**: 选中后按 `Delete` / `Backspace`。
    *   **属性修改**: 选中图形后，改变属性面板设置，实时应用到图形。

### 2.4 工具细分与文字属性统一
1. **共用控件组件**：文字工具与序号工具共用 `TextStyleControls` UI 组件；配置存储独立（`TextToolConfig` 与 `CounterToolConfig`）。
2. **Text 工具属性**：
   - 字体族、字号、字重/粗细、颜色、透明度、描边样式与颜色、背景填充
   - 初始化完成后（窗口信息采集就绪）才显示十字线与窗口高亮（参见 Architecture 的初始化 gating）
3. **Counter 工具属性**：
   - 继承文字属性；新增容器形状（圆/圆角矩形/无）、容器颜色与内边距、自动递增与起始值
   - 隐藏“背景填充”，由容器形状与颜色决定外观
4. **右侧布局规范**：
   - 三行分组：颜色矩阵与预览；样式（描边样式/颜色/填充）；字体（字体族/粗细或 B）
   - `Weight` 与 **B** 互斥显示，统一高度与基线，消除错位

### 2.5 默认值与策略
1. 文本工具：`font=System`、`size=18pt`、`weight=400`、`outline=none`
2. 序号工具：`shape=circle`、`padding=6`、`size=16pt`、`weight=600`、`autoIncrement=true`、`startIndex=1`

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
    *   `currentEditingState`: 用于保存文字编辑时的临时状态快照。
    *   `nextCounterValue: Int`: 记录下一个序号的值，每次使用 Counter 工具重置或递增。
*   **方法**:
    *   `draw(_:)`: 遍历 `annotations` 调用其 `draw(in:)` 方法。
    *   `mouseDown/dragged/Up`: 处理绘制和编辑手势。
    *   `startTextEditing`/`endTextEditing`: 管理 NSTextView 的生命周期。

#### `Annotation` (Protocol)
*   **属性**: `id`, `type`, `color`, `lineWidth`, `opacity`, `bounds`。
*   **方法**:
    *   `draw(in context: CGContext)`
    *   `contains(point: CGPoint) -> Bool`
    *   `move(by translation: CGPoint) -> Annotation`
*   **实现**: `RectangleAnnotation`, `EllipseAnnotation`, `LineAnnotation`, `TextAnnotation` (增强: `outlineStyle`, `outlineColor`, `fontName`), `CounterAnnotation` 等。

#### `CounterAnnotation` (New)
*   **属性**:
    *   `number: Int`: 序号值。
    *   `badgeCenter: CGPoint`: 序号圆圈中心点。
    *   `labelOrigin: CGPoint?`: 文本说明的位置 (可选)。
    *   `text: String?`: 文本内容。
    *   `attributes`: 颜色、字体等通用属性。
*   **绘制逻辑**:
    *   绘制圆形 Badge 背景和数字。
    *   如果有 `labelOrigin` 和 `text`，绘制连接线 (Badge Center -> Label Center) 和文本 Label。
*   **交互逻辑**:
    *   `hitTest` 需要分别判断命中 Badge 还是 Label。
    *   `move` 根据命中部分决定是整体移动还是独立移动。

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
- [x] **Step 5: 属性面板升级 (Done)**
    - [x] 重构 `AnnotationPropertiesView` UI。
    - [x] 增加**透明度**支持。
    - [x] 增加**粗细滑块**支持。
    - [x] 增加**高级样式**支持（实心填充、圆角、自定义颜色）。
- [x] **Step 6: 高级标注工具 (Phase 2)**
    - [x] **序号 (Counter) 工具实现**:
        - [x] 数据模型 `CounterAnnotation` (Badge + Label + Link)。
        - [x] 交互逻辑：点击生成、拖拽分离、双击编辑文本。
        - [x] 自动递增逻辑管理。
        - [x] **优化**: 动态缩放比例、智能防重叠、最大尺寸限制。
    - [ ] 实现**马赛克 (Mosaic)** 工具。
- [x] **Step 7: 文字工具完善 (Enhanced)**
    - [x] 集成 `NSTextView` 进行文本输入。
    - [x] 渲染文本标注。
    - [x] **高级文本属性**: 描边、字体选择。
    - [x] **交互优化**: 自动扩容、双击编辑、属性隔离。
- [x] **Step 8: 操作落地**
    - [x] 实现复制 (Copy) 和保存 (Save) 功能。
    - [ ] 实现贴图 (Pin) 功能 (Phase 2)。
    - [ ] 实现 OCR (Phase 3)。
    - [ ] 实现长截图 (Phase 3)。
