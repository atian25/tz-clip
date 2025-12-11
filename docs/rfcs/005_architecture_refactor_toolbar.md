# RFC 005: 工具栏分层重构方案（Architecture Refactor for Toolbar & Annotation）

Status: Draft

## 1. 背景与目标
在现有实现中，`SelectionView` 集中了选区交互（状态机、吸附、手柄）、工具栏与属性面板的摆放与联动、输出动作（保存/复制/关闭）、以及与标注画布的配置同步。这使得控制逻辑与渲染耦合较重，扩展新工具/动作、统一撤销/埋点、以及编写单元测试变得困难。

本 RFC 旨在对标注工具栏相关的架构进行分层重构：
- 明确 UI 层、应用层（用例/命令）、领域层（模型与算法）、状态层（Store/ViewModel）与服务组件的职责边界。
- 将散落在视图类中的业务逻辑抽取到可测试、可复用的服务与命令中。
- 为后续功能（Pin/OCR/滚动截屏/马赛克等）提供一致的扩展点与撤销/日志/错误处理通道。

## 2. 分层架构

### 2.1 视图层（UI Views）
- 组件：
  - `SelectionView`：负责选区的绘制（边框、十字准星、尺寸指示）与基本交互（鼠标/键盘识别、状态机推进），仅暴露选区几何与屏幕空间信息；不再直接执行业务动作。
  - `AnnotationOverlayView`：负责按状态层提供的数据进行渲染与命中测试；输入事件转为命令，不直接修改模型。
  - `AnnotationToolbar` / `AnnotationPropertiesView`：纯 UI 呈现与事件抛出；不持久化业务状态。
- 交互准则：视图只发出用户意图（点击工具、属性改变、选择/拖拽等）；实际业务变更由应用层处理并回写到状态层，视图订阅状态变化进行刷新。

### 2.2 应用层（UseCase / Command）
- 引入命令与用例统一处理副作用：
  - Tool Commands：`SelectTool`、`ApplyProperties`、`CreateAnnotation`、`SelectAnnotation`、`Move`、`Resize`、`Delete`、`Undo/Redo`。
  - Session Commands：`Save`、`Copy`、`Close`、`Pin`、`OCR`、`ScrollShot`。
- `CommandBus`/`SelectionController`：中心调度器，负责：
  - 从视图接收事件，转换为命令；
  - 执行命令，更新状态层；
  - 管理撤销栈与错误处理、埋点；
  - 统一发送跨组件通知（如退出）。

### 2.3 领域层（Domain Models & Algorithms）
- 模型：`Annotation` 协议及具体实现（矩形/椭圆/直线/箭头/画笔/文本/序号）。
- 算法：
  - `HitTest`/`Move`/`Resize` 等操作方法保持纯净且可测试（倾向不可变返回或最小变更）。
  - 将与选区相关的几何与对齐算法从视图中抽取为服务：
    - `SnapService`：边缘吸附与辅助线计算（替代 `SelectionView.applySnapping`）。
    - `HandleGeometry`：八向手柄几何与命中（替代 `rectForHandle/handle(at:)`）。

### 2.4 状态层（Store / ViewModel）
- `ToolState`：当前工具与各工具最近一次配置（颜色、粗细、粗体、字体、底色、透明度、圆角/填充等）。
- `SelectionState`：选区矩形与交互状态机（`idle/creating/selected/moving/resizing(handle)`）。
- `OverlayState`：标注列表、当前选中项、编辑态快照（文本编辑隔离）。
- 状态层作为单一事实来源，视图订阅渲染；命令只改变状态。

### 2.5 服务组件（Services）
- `ToolbarLayoutService`：根据 `SelectionRect` 与屏幕空间，计算工具栏与属性面板的最佳摆放位置，统一布局策略；消除视图内散落的坐标计算。
- `CaptureService`：封装屏幕图像捕获（Quartz/Cocoa 坐标转换、分辨率策略），提供给 `Save/Copy/Pin` 用例使用。
- `PermissionService` / `WindowInfoProvider`：保留现有权限与窗口识别实现，但通过接口注入到控制器。

## 3. 事件与数据流

1. 用户在工具栏点击“文字”→ `AnnotationToolbar` 触发 `didSelectTool(.text)`。
2. `SelectionController` 将其转换为 `SelectTool(.text)` 命令，更新 `ToolState.currentTool` 与预置配置。
3. `AnnotationPropertiesView` 订阅 `ToolState`，显示对应控件（字号、底色、粗体、字体）。
4. 用户拖拽或点击画布→ `AnnotationOverlayView` 发出“创建/选择/移动/缩放”意图→ 控制器转为命令→ 更新 `OverlayState` 与/或 `SelectionState`。
5. 用户点击“复制”→ 控制器执行 `Copy` 用例→ 调用 `CaptureService` 生成最终图像→ 写入剪贴板→ 通过控制器发出退出通知。

## 4. 迁移计划（最小改造）

### Step A：抽取控制器与服务
- 新增 `SelectionController.swift`：
  - 接管 `AnnotationToolbarDelegate` 与 `AnnotationPropertiesDelegate`；
  - 暴露方法用于 `SelectionView` 分发输入事件（选择/移动/缩放/删除/撤销）。
- 新增 `SnapService.swift` 与 `HandleGeometry.swift`：迁移吸附与手柄几何/命中逻辑。
- 新增 `ToolbarLayoutService.swift`：封装工具栏与属性面板位置计算。

### Step B：状态层落地
- 新增 `ToolState.swift`、`SelectionState.swift`、`OverlayState.swift`：
  - 将 `AnnotationOverlayView` 的 `currentTool` 与 `currentColor/currentLineWidth/...` 迁出到 `ToolState`；
  - `SelectionView` 的 `state/selectionRect` 保持，但以 `SelectionState` 形式暴露给控制器与服务；
  - `OverlayState` 管理标注集合与选中项、编辑快照。

### Step C：命令化动作
- 新增 `CommandBus.swift` 与 `Commands.swift`：实现 `Undo/Redo/Delete/Save/Copy/Close/Pin/OCR/ScrollShot`；（Pin/OCR/ScrollShot 现为占位，接口已打通）
- 将 `SelectionView.didSelectAction(_:)` 中的逻辑迁移到命令执行，视图只触发命令，不直接操作 `OverlayView`。

### Step D：视图减负与订阅
- `SelectionView`：保留状态机驱动与基本绘制；业务动作通过控制器；布局通过 `ToolbarLayoutService`。
- `AnnotationOverlayView`：读取 `OverlayState/ToolState` 进行渲染；输入事件转命令。
- `AnnotationToolbar/PropertiesView`：只读/写 UI，与状态层双向绑定（通过控制器）。

## 5. 兼容性与回滚
- 渐进式迁移：每个 Step 都保持对外行为一致（MVP 功能不变）。
- 回滚策略：控制器与服务采用接口注入，出现异常时可短路回到旧视图内部实现；撤销栈保存在 `CommandBus`，不影响旧逻辑。

## 6. 测试与验证
- 单元测试：
  - `SnapService`：边缘吸附阈值与辅助线集合；
  - `HandleGeometry`：八向手柄几何与命中测试；
  - `CommandBus`：Undo/Redo、Delete、Save/Copy 的状态与副作用。
- 集成测试：在覆盖窗口环境下的坐标转换与图像生成；工具栏/属性面板布局在多屏与边界场景。
- 手动验证：对照 `docs/rfcs/003_toolbar_and_annotation.md` 的交互规范逐条验证。

## 7. 开放问题
- 文本工具与序号工具的属性“独立记忆”与“全局默认”的切换策略（是否引入 Profile/Preset）。
- `ScrollShot` 与 `OCR` 的用例触发与长流程状态管理（可能需要独立模块）。
- 撤销栈的容量与性能影响，是否需要持久化或压缩策略。

## 8. 里程碑
- M1：控制器/服务骨架与状态层落地（不改变现有 UI 行为）。
- M2：命令化输出动作与统一撤销；完成服务抽取的单元测试。
- M3：引入马赛克工具与高级动作（Pin/OCR/滚动截屏）基于命令与状态层扩展。

## 11. 代码目录结构（分层）

```
Sources/TZClip/
├── Views/
│   ├── SelectionView.swift
│   ├── AnnotationOverlayView.swift
│   ├── AnnotationToolbar.swift
│   └── AnnotationPropertiesView.swift
├── Controllers/
│   └── SelectionController.swift
│   └── OverlayWindowController.swift
├── Services/
│   ├── CommandBus.swift
│   ├── SnapService.swift
│   └── ToolbarLayoutService.swift
│   └── HandleGeometryService.swift
│   └── WindowInfoProvider.swift
├── State/
│   ├── ToolState.swift
│   ├── SelectionState.swift
│   └── OverlayState.swift
├── AnnotationToolbar.swift
├── AnnotationPropertiesView.swift
├── AnnotationOverlayView.swift
├── AnnotationModels.swift
├── SelectionView.swift
├── OverlayWindowController.swift
├── WindowInfoProvider.swift
├── AppDelegate.swift
└── main.swift

Tests/TZClipTests/
├── CommandBusTests.swift
├── SnapServiceTests.swift
└── ToolbarLayoutServiceTests.swift

## 12. 下一步（M2 TODO）

- [ ] `AnnotationOverlayView` 配置读取迁移到 `ToolState`（去除内部 `toolConfigs` 映射）。
- [ ] 将选区创建/移动/缩放接口收敛到 `SelectionController`，`SelectionView` 仅推进状态机并调用接口。
- [ ] 扩展命令：`Pin/OCR/ScrollShot` 的占位与参数定义（`Commands.swift`）。
- [ ] 增加单测：控制器驱动的选区移动/缩放、Overlay 读取状态的正确性。
```

说明：视图文件已迁移至 Views 目录；控制器与服务已归位；模型已拆分到 Annotations 目录；后续迭代将逐步收敛选区交互到控制器与状态层。

## 10. M1 控制器说明与 TODO

### 10.1 名称与职责
- 名称：`SelectionController`
- 职责：
  - 作为工具/属性/标注交互的中枢，承接 UI 事件并转换为命令；
  - 维护并更新 `ToolState/SelectionState/OverlayState`；
  - 调用 `CommandBus` 执行输出动作与撤销；
  - 注入与使用 `SnapService/ToolbarLayoutService/CaptureService/WindowInfoProvider` 等服务。

### 10.2 对外接口（初版草案）
- `init(toolState: ToolState, selectionState: SelectionState, overlayState: OverlayState, commandBus: CommandBus, services: Services)`
- `handleToolSelected(_ tool: AnnotationType)`：工具切换，更新 `ToolState` 并驱动属性面板显示。
- `applyProperties(_ p: Properties)`：属性变更（颜色、粗细、粗体、字体、底色、透明度等），更新 `ToolState` 与选中项。
- `beginSelection(at p: NSPoint)` / `updateSelection(to p: NSPoint)` / `endSelection()`：创建选区流程与状态机推进。
- `moveSelection(dx: CGFloat, dy: CGFloat)` / `resizeSelection(handle: Handle, dx: CGFloat, dy: CGFloat)`：对选区执行移动/缩放（内部调用 `SnapService`）。
- `selectAnnotation(id: UUID?)` / `deleteSelection()` / `undo()`：标注选择/删除/撤销。
- `perform(_ action: ToolbarAction)`：转发到 `CommandBus`（保存/复制/关闭等）。

### 10.3 依赖与绑定
- 依赖：`ToolState/SelectionState/OverlayState`、`CommandBus`、`SnapService`、`ToolbarLayoutService`、`CaptureService`、`WindowInfoProvider`。
- 绑定：
  - 由 `OverlayWindowController` 创建并注入到 `SelectionView/AnnotationOverlayView/AnnotationToolbar/AnnotationPropertiesView`；
  - `SelectionView` 将鼠标/键盘产生的“选区相关”事件转交 `SelectionController`；
  - `AnnotationToolbar/PropertiesView` 的委托由 `SelectionController` 实现；
  - 视图订阅状态层变化并刷新（大小/位置/属性），避免直接改模型。

### 10.4 TODO 列表（M1 范围）
- [x] 新增 `SelectionController.swift` 文件与构造函数，接管工具/属性委托。
- [x] 定义 `ToolState/SelectionState/OverlayState` 最小数据结构并实现读写接口。
- [x] 在 `SelectionView` 中注入 `SelectionController`，将 `didSelectTool(_:)`、属性变更与动作分发改走控制器。
- [ ] 将选区的创建/移动/缩放事件封装为控制器调用，`SelectionView` 只负责状态机推进与调用控制器接口。
- [x] 将保存/复制/关闭通过 `CommandBus.perform` 统一执行并反馈退出。
- [x] 迁移布局计算到 `ToolbarLayoutService`（已完成集成，校验边界场景）。
- [x] 迁移吸附计算到 `SnapService`（已完成集成，补充阈值与多屏测试用例）。
- [x] 验证现有交互不变：工具栏跟随、属性面板展示逻辑、撤销/删除、尺寸指示与手柄命中。
- [x] 为服务与控制器添加基础单元测试（吸附、布局、命令分发、控制器属性同步）。

## 9. 与现有代码的映射
- 参考文件：
  - 选区交互与状态机：`Sources/TZClip/SelectionView.swift`（如 `mouseDown/mouseDragged/mouseUp`）。
  - 工具栏与动作分发：`Sources/TZClip/AnnotationToolbar.swift`（`didSelectTool/Action`）。
  - 属性面板：`Sources/TZClip/AnnotationPropertiesView.swift`（`configure` 与各属性变更）。
- 迁移要点：
  - 将 `SelectionView.didSelectAction(_:)` 的保存/复制/关闭迁移至 `CommandBus`；
  - 将 `applySnapping/handle(at:)/rectForHandle` 迁移至服务；
  - 将 `AnnotationOverlayView` 的当前工具与样式配置迁移至 `ToolState`，其渲染读取状态层。

---
本 RFC 为重构架构的指导文档。待确认后，将在 `M1` 阶段提供骨架代码与接口定义，并按上述迁移计划实施。

## 附录 A：交互与属性规则更新
- 形状类（矩形/椭圆/线/箭头/画笔）创建：按下后拖拽距离超过 3px 方进入创建，单击空白不创建，减少误触
- 文本/序号创建：单击空白创建；新建完成后下一次空白点击被抑制（不创建），随后恢复正常；双击已有文本进入编辑
- 属性面板宽度自适应：线条类不显示右侧第三块（无留白）；文本/序号显示第三块（底色/粗体/字体）
- 字体下拉：文本与序号工具始终显示字体选择下拉，随工具切换与选中项同步

## 附录 B：序号标注尺寸联动规范
- 第一块“大小”控制文本字号 `lineWidth`（单位 pt，范围 12–100），序号文字与连线使用同一颜色
- 序号徽章内数字字号：`numberFontSize = min(lineWidth × 0.6, 20.0)`；初始更易读，且在达到阈值后仅放大其文字不再放大数字
- 徽章半径：在数字达到上限时同步冻结（`freezeAtLineWidth = 20 / 0.6 ≈ 33.33`），`badgeRadius` 不再随 `lineWidth` 增长，保持与达到阈值时一致的视觉大小
- 徽章半径：随 `lineWidth` 低比例增长并限制最大半径（当前实现见 `CounterAnnotation.badgeRadius`）
- 文字位置：字号变化时保持文字与徽章相对关系，必要时沿连线方向做轻微位移以避免重叠

## 附录 C：测试用例（新增）
- `CounterAnnotationTests.testNumberFontSizeScalingAndCap`：验证数字字号随 `lineWidth` 按 0.6 比例变化，并在 20 上限封顶
- `CounterAnnotationTests.testEffectiveFontUsesLineWidth`：验证文本字号采用 `lineWidth` 并进行 12–100 的边界夹取

## 附录 D：目录更新
Tests/TZClipTests/
├── CommandBusTests.swift
├── SnapServiceTests.swift
├── ToolbarLayoutServiceTests.swift
└── CounterAnnotationTests.swift
