# Refreshable — 需求文档

## 1. 项目概述

基于 UIScrollView 的通用边缘刷新 / 加载更多控件，以 Swift Package 形式提供。
每个滚动视图内部通过唯一 coordinator 统一管理所有边缘 session，对外只暴露 `UIScrollView` 方法。

## 2. 技术约束

| 项目 | 要求 |
|------|------|
| 语言 | Swift 6.0+（strict concurrency） |
| 最低系统 | iOS 13 |
| 并发模型 | async/await；UIKit 安装和状态 API 保持 `@MainActor`，action 为 `@Sendable () async -> Void` |
| 分发方式 | Swift Package Manager |
| 依赖 | 无第三方依赖，仅 UIKit |

## 3. 功能需求

### 3.1 刷新

- 用户沿指定 edge 拖动 UIScrollView 超过阈值松手后，触发刷新
- 默认 edge 为 `.top`，也支持 `.bottom`、`.leading`、`.trailing`
- 刷新期间显示 loading indicator，对应方向的 `contentInset` 自动增加露出视图
- async 闭包返回后自动结束刷新，动画收回
- 支持 `beginRefreshableOperation(for:)` 手动触发
- 支持 `endRefreshableOperation(for:)` 手动结束（兜底）
- 支持通过 `RefreshableOptions` 调整触发距离、动画时长、自动结束、短内容加载、展示方式和状态回调
- 支持运行时启用、禁用和移除指定边缘刷新组件

### 3.2 加载更多

- 用户沿指定 edge 拖动到内容末端超过阈值松手后，触发加载
- 默认 edge 为 `.bottom`，也支持 `.top`、`.leading`、`.trailing`
- 加载期间显示 loading indicator，对应方向的 `contentInset` 自动增加
- async 闭包返回后自动结束加载
- 支持 `beginRefreshableOperation(for:)` 与 `endRefreshableOperation(for:)` 手动启停
- 支持 `markNoMoreData(for:)` 标记无更多数据（显示终态文案，停止触发）
- 支持 `resetNoMoreData(for:)` 重置状态（如下拉刷新后重新允许加载）
- 内容不足当前 edge 所在轴的视口时默认不触发加载，可通过 `allowsLoadMoreWhenContentFits` 开启
- 支持运行时启用、禁用和移除指定边缘加载组件

### 3.3 防重入

刷新/加载进行中，再次下拉或上拉不会重复触发。
同一 scroll view 的同一 edge 同时只允许一个组件；重复安装会替换旧组件并恢复旧 inset。

### 3.4 自定义 UI

- 提供 `RefreshableStyle` 配置/工厂协议和 `RefreshableStyleRenderer` 渲染协议
- 同一 style 每次安装必须创建独立 renderer 和 UIView，避免多 scroll view 共享渲染状态
- `RefreshableStyleContext` 由组件创建并提供状态与归一化拖动进度
- 通过 `setRefreshableOperation(_:for:style:options:action:)` 传入自定义样式
- 核心产品 `Refreshable` 保留默认 spinner、DefaultTop、DefaultBottom 和 SystemNative
- Kinetic、Video 展示型样式由独立产品 `RefreshableStyles` 提供，并依赖核心产品

### 3.5 默认 UI

- 省略 `style:` 时，刷新和加载更多在 `.top`、`.bottom`、`.leading`、`.trailing` 都使用同一套分段式 spinner
- 默认指示器没有箭头，不显示可见状态文案，并使用动态系统颜色适配深色模式
- `RefreshableOptions.textConfiguration == nil` 时保持所有可见文案隐藏
- `RefreshableTextConfiguration()` 启用按 edge、刷新/加载角色和状态区分的内置中文文案
- 非 nil 配置中的状态字段只覆盖对应状态；nil 字段继续使用内置文案
- 状态字段为空字符串 `""` 时，仅隐藏对应状态的可见文案
- `textConfiguration` 只在省略 `style:` 时应用；显式传入的样式不读取该配置

### 3.6 通用性

通过 `extension UIScrollView` 提供，无需子类化。
UITableView、UICollectionView 及任何 UIScrollView 子类均可使用。
`leading` / `trailing` 为语义方向，按 `effectiveUserInterfaceLayoutDirection` 自动适配 RTL。

## 4. 公开 API

```swift
scrollView.setRefreshableOperation(.refresh, for: .top, style: style, options: options) { await vm.fetch() }
scrollView.setRefreshableOperation(.loadMore, for: .bottom, style: style, options: options) { await vm.loadNext() }
scrollView.refreshableState(for: .top)
scrollView.beginRefreshableOperation(for: .top)
scrollView.endRefreshableOperation(for: .top)
scrollView.setRefreshableOperationEnabled(false, for: .bottom)
scrollView.markNoMoreData(for: .bottom)
scrollView.resetNoMoreData(for: .bottom)
scrollView.removeRefreshableOperation(for: .top)
```

v2 不提供 v1 convenience API、deprecated 标记或 forwarding 适配层。

`RefreshableOptions`：

```swift
RefreshableOptions(
    triggerDistance: nil,
    animationDuration: 0.25,
    automaticallyEnds: true,
    allowsLoadMoreWhenContentFits: false,
    automaticTriggerDistance: .default,
    placement: nil,
    presentation: .contentInset, // 或 .overlay(spacing: 12, locksContentOffset: true)
    textConfiguration: nil,
    onStateChange: nil
)
```

默认控件的文案配置示例：

```swift
import UIKit
import Refreshable

// 启用所有内置中文文案
@MainActor
func enableBuiltInRefreshText(on scrollView: UIScrollView) {
    let options = RefreshableOptions(
        textConfiguration: RefreshableTextConfiguration()
    )
    scrollView.setRefreshableOperation(
        .refresh,
        for: .top,
        options: options
    ) {}
}

// 只覆盖 active；其他状态继续使用内置中文文案
@MainActor
func overrideActiveText(on scrollView: UIScrollView) {
    let options = RefreshableOptions(
        textConfiguration: RefreshableTextConfiguration(active: "正在同步...")
    )
    scrollView.setRefreshableOperation(
        .refresh,
        for: .top,
        options: options
    ) {}
}

// 只隐藏 ending；其他状态继续使用内置中文文案
@MainActor
func hideEndingText(on scrollView: UIScrollView) {
    let options = RefreshableOptions(
        textConfiguration: RefreshableTextConfiguration(ending: "")
    )
    scrollView.setRefreshableOperation(
        .loadMore,
        for: .bottom,
        options: options
    ) {}
}
```

## 5. 状态机

```
Refresh:  idle → pulling(progress) → triggered → active → ending → idle
LoadMore: idle → pulling(progress) → triggered → active → ending → idle
                                                                 ↘ noMoreData
```

| 状态 | 含义 |
|------|------|
| `idle` | 空闲 |
| `pulling(CGFloat)` | 正在拖拽，progress 0...1 |
| `triggered` | 已达阈值，松手即触发 |
| `active` | 刷新/加载中 |
| `ending` | 收起动画中 |
| `noMoreData` | 无更多数据（仅 `.loadMore` session） |

## 6. 自定义样式协议

```swift
@MainActor
public protocol RefreshableStyle {
    var extent: CGFloat { get }
    var defaultTriggerDistance: CGFloat { get }
    var defaultPlacement: RefreshablePlacement { get }
    func makeRenderer() -> any RefreshableStyleRenderer
}

@MainActor
public protocol RefreshableStyleRenderer: AnyObject {
    var view: UIView { get }
    func render(_ context: RefreshableStyleContext)
}

public struct RefreshableStyleContext: Sendable, Equatable {
    public let state: RefreshState
    public let pullProgress: CGFloat
}
```

`defaultTriggerDistance` 默认等于 `extent`，`defaultPlacement` 默认是 `.init()`。
`RefreshableOptions.placement` 默认 `nil`，表示采用 style 默认 placement；显式 `.init()` 表示真正全零布局。

## 7. 视图可见性（借鉴 UIRefreshControl）

style.view 的 alpha 由组件自动管理，idle 时完全不可见，拖拽时渐显：

| 状态 | alpha | 说明 |
|------|-------|------|
| idle | 0 | 完全透明，bounce 时不会露出 |
| pulling(p) | p (0→1) | 跟随拖拽进度渐显 |
| triggered | 1 | 完全可见 |
| active | 1 | 完全可见 |
| ending | 保持 | 收起动画期间保持可见，回到 idle 后隐藏 |
| noMoreData | 1 | 显示终态文案 |

> 自定义 `RefreshableStyle` 无需手动管理 alpha，组件层自动处理。

## 8. 默认样式行为

### 省略 style 的统一默认控件

| 状态 | 分段式 spinner | 默认可见文案 | 启用 `RefreshableTextConfiguration()` 后 |
|------|----------------|--------------|------------------------------------------|
| idle | 空进度，停止 | 隐藏 | 显示对应 edge / 角色的内置中文文案 |
| pulling(p) | 跟随 p 填充，停止 | 隐藏 | 显示对应 edge / 角色的内置中文文案 |
| triggered | 满进度，停止 | 隐藏 | 显示“释放刷新”或“释放加载” |
| active | 满进度，旋转 | 隐藏 | 显示“正在刷新...”或“正在加载...” |
| ending | 满进度，停止 | 隐藏 | 显示“刷新完成”或“加载完成” |
| noMoreData | 空进度，停止 | 隐藏 | 加载更多显示“没有更多数据” |

统一默认控件没有箭头。其文案解析规则为：非 nil 状态字段覆盖该状态，nil 字段保留内置中文文案，空字符串仅隐藏该状态。

### 显式样式

`ClassicTopRefreshStyle`、`ClassicBottomLoadMoreStyle` 和 `SystemNativeRefreshStyle` 仍可显式传入，并保留原有行为：

```swift
scrollView.setRefreshableOperation(.refresh, for: .top, style: ClassicTopRefreshStyle()) {}
scrollView.setRefreshableOperation(.loadMore, for: .bottom, style: ClassicBottomLoadMoreStyle()) {}
scrollView.setRefreshableOperation(.refresh, for: .top, style: SystemNativeRefreshStyle()) {}
```

`RefreshableOptions.textConfiguration` 只供省略 `style:` 的统一默认控件使用。显式传入上述样式或任意自定义 `RefreshableStyle` 时，该字段不会改变样式行为。

## 9. 实现架构

```
UIScrollView public methods
        │
        └── RefreshableCoordinator       internal scroll-view 级观察、生命周期和 inset 编排
              ├── RefreshableScrollObservationSet  单组 KVO / pan target
              ├── [RefreshableEdge: EdgeRefreshComponent]
              │      ├── RefreshComponent       effect 顺序与 renderer 编排
              │      ├── RefreshMachineDriver   reducer、generation、异步 action
              │      └── EdgePresentationDriver host、inset/offset 展示状态
              ├── RefreshableInsetCoordinator   scroll-view 级增量 inset
              └── EdgeRefreshGeometry           四方向纯几何
```

**关键实现细节：**

- **关联存储**：`objc_setAssociatedObject` 存放唯一 coordinator；coordinator 持有 edge session，session weak 引用 scrollView
- **统一观察**：同一 scroll view 只建立一组 contentOffset/contentSize/bounds/contentInset/semantic KVO 和一个 pan target，再向所有 edge session 分发快照
- **组合式组件**：`EdgeRefreshComponent` 是 final facade，不继承运行时基类；machine、observation 和 presentation 分别持有各自状态
- **事件 Reducer**：拖动、手势结束/取消、自动/手动触发、action/animation completion、noMoreData、启停和挂载都经 reducer；旧 generation completion 不得修改新状态
- **固定执行顺序**：提交状态 → inset/布局副作用 → renderer/可见性 → `onStateChange` → generation 校验后启动 action
- **KVO 监听**：`contentOffset`、`contentSize`、`bounds`、`contentInset` 和 `panGestureRecognizer.state`；host 在 layout、安全区、trait、RTL 和几何变化时失效
- **inset 管理**：coordinator 维护 baseline 和逐 owner/物理边贡献；外部 inset 修改更新 baseline，组件移除只减去自身贡献
- **生命周期**：替换、移除、禁用会取消任务并使旧命令失效；renderer 和 host 闭包可释放。Demo 与 README 的存储闭包统一弱捕获
- **线程安全**：options、placement 和自动触发配置为 `Sendable`；安装、状态控制、renderer 和 `onStateChange` 为 `@MainActor`，action 为 `@Sendable () async -> Void`

## 10. 文件结构

```
Refreshable/
├── Package.swift
├── Sources/Refreshable/
│   ├── Core/
│   │   ├── RefreshState.swift
│   │   ├── RefreshableEdge.swift
│   │   ├── RefreshableStyle.swift
│   │   ├── RefreshableOptions.swift
│   │   ├── ResolvedRefreshableOptions.swift
│   │   ├── RefreshEventReducer.swift
│   │   ├── RefreshMachineDriver.swift
│   │   ├── RefreshableCoordinator.swift
│   │   ├── RefreshableScrollObservation.swift
│   │   ├── RefreshableInsetCoordinator.swift
│   │   └── EdgeRefreshGeometry.swift
│   ├── Components/
│   │   ├── RefreshComponent.swift
│   │   ├── EdgeRefreshComponent.swift
│   │   ├── EdgePresentationDriver.swift
│   │   └── RefreshHostView.swift
│   ├── Extensions/
│   │   └── UIScrollView+Refreshable.swift
│   └── Styles/
│       ├── Classic/
│       │   ├── RefreshLabelStyleConfiguration.swift
│       │   ├── ClassicTopRefreshStyle.swift
│       │   └── ClassicBottomLoadMoreStyle.swift
│       ├── Default/
│       │   └── DefaultRefreshControlStyle.swift
│       ├── Shared/
│       │   └── SegmentedRefreshSpinnerView.swift
│       └── Custom/
│           └── SystemNativeRefreshStyle.swift
├── Sources/RefreshableStyles/
│   ├── KineticRefreshStyle.swift
│   └── VideoRefreshStyles.swift
├── Tests/RefreshableTests/
├── Tests/RefreshableStylesTests/
└── Demo/
    └── Demo/
        ├── TableViewDemoController.swift
        ├── CollectionViewDemoController.swift
        ├── CustomStylesDemoController.swift
        └── DefaultRefreshControlPreviewController.swift
```

## 11. 测试与发布门禁

- Reducer：完整状态流、progress 归零、ended/cancelled/failed、手动/自动触发、旧 generation、disable/detach/noMoreData
- Inset：外部修改、活跃增量、多 owner 同边叠加、物理边切换和逐 owner 移除
- Geometry：四个物理方向、reveal、host/renderer frame、安全区、bounds/contentSize/RTL 变化
- Renderer：独立 UIView/状态、Reduce Motion 和动态颜色
- 生命周期：controller、scroll view、component、renderer 可释放，存储闭包使用弱捕获
- UI：四方向真实拖拽、默认无文案、内置文案、noMoreData/reset 和两套自定义样式
- CI 使用官方 `macos-26`，执行核心/样式单测、iOS 13 generic Release 编译、Demo Swift 6 build-for-testing、UI smoke/full 测试和两产品 API baseline 检查

## 12. Demo 示例

| 页面 | 视图类型 | 演示内容 |
|------|---------|---------|
| TableView Demo | UITableView | 下拉刷新 20 条文本 + 上拉分页加载 15 条/页，3 页后 noMoreData |
| CollectionView Demo | UICollectionView | 3 列彩色方块网格，下拉刷新 18 个 + 上拉加载 12 个/页，3 页后 noMoreData |
| 默认刷新控件预览 | UIScrollView | 从“样式”页点击右上角“默认预览”进入；可切换上、下、左、右四个方向、刷新/加载更多角色，并开关内置文案 |

## 13. 非需求（明确不做）

- Combine / RxSwift 绑定
- SwiftUI 原生支持（SwiftUI 已有内置 `.refreshable`）
- 自动分页（由调用方控制页码逻辑）
