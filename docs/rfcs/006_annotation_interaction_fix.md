# RFC 006: 标注交互缺陷修复（填充命中、双击编辑、编辑态尺寸）

Status: Implemented

## 背景
在使用矩形/椭圆、文字与序号标注的过程中，发现三处交互问题影响效率与体验：
1. 实心形状中心无法拖拽，误触发新标注创建。
2. 序号/文字双击进入编辑态时，容易误创建新标注。
3. 编辑态调整字号时，面板易被遮挡，边框与尺寸反馈不实时。

## 问题与原因
1) 填充形状命中不正确
- 现象：`isFilled=true` 时中心点击无法命中已有图形。
- 原因：命中逻辑仅使用描边路径，未考虑填充区域。
- 代码：`Sources/TZClip/Annotations/RectangleAnnotation.swift:32-41`、`Sources/TZClip/Annotations/EllipseAnnotation.swift:24-33`。

2) 双击编辑误创建
- 现象：双击进入编辑态后，后续 `mouseUp` 仍走到空白创建逻辑，导致新标注。
- 原因：进入编辑态未设置“创建保护”；且点击存在编辑框时统一结束编辑过于激进。
- 代码：`Sources/TZClip/AnnotationOverlayView.swift:519-527, 531-563, 818-858`。

3) 编辑态字号调整反馈不实时
- 现象：拖动字号滑块时编辑框尺寸与边框反馈延迟，属性面板遮挡感明显。
- 原因：仅更新 `NSTextView.font`，未同步重算尺寸；编辑态未绘制高亮框；属性面板层级虽在上，但缺少视觉边界对齐。
- 代码：`Sources/TZClip/AnnotationOverlayView.swift:286-323, 362-379, 1139-1155`。

## 方案与实现
A. 填充形状命中修正
- 规则：`isFilled=true` 使用填充区域命中；`isFilled=false` 保持描边容错命中。
- 改动：
  - `RectangleAnnotation.contains(point:)` 使用 `rect.contains(point)`。
  - `EllipseAnnotation.contains(point:)` 使用 `ellipsePath.contains(point)`。

B. 双击编辑创建保护与收束优化
- 规则：双击进入编辑后，抑制后续一次空白点击创建；点击编辑框内部不结束编辑。
- 改动：
  - 双击分支设置 `skipNextBlankClickCreation=true` 并进入 `startTextEditing(...)`。
  - `mouseDown` 顶部：若点中编辑框区域则不结束编辑；否则结束编辑。

C. 编辑态字号与边框反馈实时化
- 规则：字号滑动实时重算编辑框尺寸，并绘制轻量高亮边框以维持反馈。
- 改动：
  - `updateActiveTextView()` 在更新字体/颜色后，基于当前文本重新测量并更新 `frame.size`。
  - 在 `draw(_:)` 中对 `activeTextView.frame` 绘制高亮边框。

## 影响与兼容
- 选择命中更符合直觉，不破坏既有非填充形状的选择容错。
- 编辑流程稳定，避免误创建与误结束编辑。
- 编辑态与最终渲染的尺寸更一致，所见即所得。

## 验证
- 单测：新增 `Tests/TZClipTests/ShapeHitTestTests.swift`，验证填充形状中心命中与非填充中心不命中。
- 回归：全部测试通过；应用本地运行交互验证。

## 结论
该修复提高了标注编辑的可控性与一致性，符合 RFC003 的交互目标，并为后续 Mosaic/Pin/OCR 等功能提供更稳定的基础。
