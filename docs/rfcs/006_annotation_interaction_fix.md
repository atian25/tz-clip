# RFC 006: 标注交互规范（形状命中、文本编辑、序号行为、层级与工具切换）

Status: Implemented

## 范围
矩形、椭圆、直线/箭头、自由笔、文字标注与序号标注在查看态与编辑态下的命中、拖拽、光标与层级规则；工具切换与首次点击的创建优先级；编辑反馈与尺寸一致性。

## 交互规则
- 工具切换与创建优先级
  - 切换到非 `select` 工具后，首次点击优先进入“新增标注”流程（超过拖动阈值开始创建），不命中已有标注；随后恢复正常命中。
  - 拖动阈值默认 `3px`，用于区分点击与创建拖动。

- 形状命中与拖拽
  - 填充矩形/椭圆：点击内部区域命中，优先拖拽已存在形状。
  - 非填充矩形/椭圆：使用加粗描边路径进行命中，提升容错，命中后拖拽移动。

- 文字标注（查看态与编辑态）
  - 查看态由 `TextAnnotation` 绘制；编辑态使用 `NSTextView` 单一组件承载文本编辑。
  - 编辑态显示实线边框；文本区域为 I 光标；编辑态不显示手型光标。
  - 事件路由优先给 `NSTextView`，支持鼠标选择与拖拽选区；结束编辑后合并为 `TextAnnotation`。

- 序号标注（圆点与文字）
  - 尺寸解耦：圆点尺寸与文字大小独立；拖动“文字大小”只影响文字，拖拽圆点缩放只影响圆点与内部数字。
  - 编辑态保留从圆点到文字的连线；连线绘制在徽章下方，避免遮挡。
  - 首次拖拽按命中部件移动：点击文字只移动文字，点击圆点只移动圆点；不发生整体同时移动。

- 层级与绘制顺序
  - 编辑态下先绘制指向连线，再绘制徽章与其他标注，确保徽章在连线上方。
  - 选择高亮与编辑边框在标注之后绘制。

- 编辑态反馈与尺寸一致性
  - 字号、粗细、字体变化实时重测文本、更新编辑框尺寸；触发重绘与光标区域刷新，保持边框与几何同步。

## 技术要点（代码位置）
- 填充命中：`Sources/TZClip/Annotations/RectangleAnnotation.swift:32-36`，`Sources/TZClip/Annotations/EllipseAnnotation.swift:24-28`
- 事件路由：`Sources/TZClip/Views/SelectionView.swift:52`（子视图优先命中）
- 编辑态管理：`Sources/TZClip/AnnotationOverlayView.swift:986-1161`（`startTextEditing`/`endTextEditing`）
- 光标与边框：`Sources/TZClip/AnnotationOverlayView.swift:532-544, 350-367`
- 工具切换创建优先：`Sources/TZClip/AnnotationOverlayView.swift:45-58, 644-679, 706-729`
- 序号行为与层级：`Sources/TZClip/Annotations/CounterAnnotation.swift:24-43, 64-105`；`Sources/TZClip/AnnotationOverlayView.swift:350-367`

## 兼容性与一致性
- 保持非填充形状的容错命中，不影响现有工作流。
- 编辑态仅显示一个文本组件，避免查看态文本与编辑组件重叠。
- 序号标注在编辑与查看态下几何规则一致，避免尺寸联动造成的挤压与遮挡。

## 验证
- 单元测试：`Tests/TZClipTests/ShapeHitTestTests.swift` 验证填充形状中心命中与非填充描边命中。
- 交互回归：本地运行完整验证形状、文字与序号的命中、拖拽、编辑与层级。

## 结论
交互模型统一、规则明确，确保查看与编辑态的一致性、工具切换的可预期性以及标注的层级正确性，为后续能力扩展提供稳定基础。
