# Refreshable

UIScrollView 刷新/加载更多控件。async/await 驱动，一行接入，支持 `.top`、`.bottom`、`.leading`、`.trailing` 四个语义边缘和自定义 UI。Swift 6.0，iOS 13+。

## 安装

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/astralchen/Refreshable.git", from: "1.0.0")
]
```

app target 至少依赖核心产品 `Refreshable`；需要动感或视频样式时，再加入
`RefreshableStyles` 产品。

## 快速上手

```swift
import Refreshable

// 下拉刷新。组件会存储 action，实例成员请使用弱捕获。
tableView.refreshable { [weak self] in
    guard let self else { return }
    let items = await service.fetchLatest()
    await MainActor.run {
        viewModel.items = items
        tableView.reloadData()
    }
}

// 上拉加载
tableView.onLoadMore { [weak self] in
    guard let self else { return }
    let nextPage = await service.fetchNextPage()
    await MainActor.run {
        viewModel.append(nextPage)
        tableView.reloadData()
    }
}
```

## API

```swift
// 下拉刷新
scrollView.refreshable { /* async */ }
scrollView.refreshable(edge: .leading) { /* async */ }
scrollView.refreshable(options: options) { /* async */ }
scrollView.refreshable(style: MyStyle()) { /* async */ }
scrollView.refreshable(style: MyStyle(), options: options) { /* async */ }
scrollView.beginRefreshing()
scrollView.beginRefreshing(edge: .leading)
scrollView.endRefreshing()

// 上拉加载
scrollView.onLoadMore { /* async */ }
scrollView.onLoadMore(edge: .trailing) { /* async */ }
scrollView.onLoadMore(options: options) { /* async */ }
scrollView.onLoadMore(style: MyStyle()) { /* async */ }
scrollView.onLoadMore(style: MyStyle(), options: options) { /* async */ }
scrollView.beginLoadingMore()
scrollView.beginLoadingMore(edge: .trailing)
scrollView.endLoadingMore()

// 没有更多数据
scrollView.markNoMoreData()
scrollView.resetNoMoreData()

// 状态查询
scrollView.refreshState
scrollView.refreshState(edge: .leading)
scrollView.loadMoreState
scrollView.loadMoreState(edge: .trailing)
scrollView.isRefreshActive
scrollView.isLoadMoreActive

// 运行时控制
scrollView.setRefreshEnabled(false)
scrollView.setLoadMoreEnabled(false)
scrollView.removeRefreshable()
scrollView.removeLoadMore()
```

`leading` 和 `trailing` 是语义方向，会根据 `UIScrollView.effectiveUserInterfaceLayoutDirection` 在 LTR/RTL 下自动映射到物理 left/right。

## 行为配置

用 `RefreshableOptions` 调整触发距离、动画时长、自动结束、短内容加载、展示方式和状态回调：

```swift
let options = RefreshableOptions(
    triggerDistance: 80,
    animationDuration: 0.35,
    automaticallyEnds: false,
    allowsLoadMoreWhenContentFits: true,
    automaticTriggerDistance: 120,
    placement: RefreshablePlacement(contentSpacing: 12, outerSpacing: 8, crossAxisInset: 20),
    presentation: .contentInset,
    onStateChange: { [weak self] state in
        self?.record(state)
    }
)

tableView.refreshable(options: options) { [weak self, weak tableView] in
    await self?.viewModel.fetchLatest()
    await MainActor.run {
        tableView?.endRefreshing()
    }
}

tableView.onLoadMore(options: options) { [weak self, weak tableView] in
    await self?.viewModel.fetchNextPage()
    await MainActor.run {
        tableView?.endLoadingMore()
    }
}
```

选项默认值保持一行接入行为：

- `triggerDistance: nil` 使用 `style.extent` 作为触发距离；自定义 `triggerDistance` 只改变触发阈值，不改变刷新中保留的视觉占位
- `animationDuration: 0.25`
- `automaticallyEnds: true`，action 完成后自动收起
- `allowsLoadMoreWhenContentFits: false`，内容未填满当前滚动轴时默认不触发加载更多
- `automaticTriggerDistance: .default`，使用内置策略：底部 `onLoadMore` 默认滚到底部自动触发，其他方向默认不自动触发；设置为 `0` 或正值时，`refreshable` / `onLoadMore` 可在任意方向滚到对应边缘或提前距离内自动开始；设置为 `nil` 时关闭自动触发
- `placement: nil`，使用 style 的 `defaultPlacement`；显式传入 `RefreshablePlacement()` 才表示真正的全零布局。`outerSpacing` 沿刷新方向增加视觉控件与可见外侧边缘之间的距离，`contentSpacing` 增加视觉控件与内容之间的距离，`crossAxisInset` 在垂直于刷新方向的轴上收缩视觉控件
- `presentation: .contentInset`，默认通过 inset 保持刷新视图；全屏视频流可使用 `.overlay(spacing:locksContentOffset:)` 浮在可见区域边缘，并可在边界拖动时保持视频画面不移动

默认横向边缘样式会保留 8pt 外侧留白，让左右刷新控件不会贴住屏幕边缘；传入自定义 `placement` 时以调用方配置为准。

## 默认刷新控件与文案

省略 `style:` 时，`refreshable` 和 `onLoadMore` 在 `.top`、`.bottom`、`.leading`、`.trailing` 四个方向都使用同一套分段式 spinner。默认指示器没有箭头，也不显示可见状态文案。

`RefreshableOptions.textConfiguration` 控制这套默认指示器的可见文案：

- `nil`（默认值）保持所有可见文案隐藏
- `RefreshableTextConfiguration()` 启用按 edge、刷新/加载角色和状态区分的内置中文文案
- 非 nil 配置中的某个状态字段只覆盖该状态；其余 nil 字段继续使用对应的内置文案
- 状态字段传入空字符串 `""` 时，仅隐藏该状态的可见文案

以下示例可直接编译：

```swift
import UIKit
import Refreshable

// 启用所有内置中文文案
@MainActor
func enableBuiltInRefreshText(on scrollView: UIScrollView) {
    let options = RefreshableOptions(
        textConfiguration: RefreshableTextConfiguration()
    )
    scrollView.refreshable(options: options) {}
}

// 只覆盖 active；其他状态继续使用内置中文文案
@MainActor
func overrideActiveText(on scrollView: UIScrollView) {
    let options = RefreshableOptions(
        textConfiguration: RefreshableTextConfiguration(active: "正在同步...")
    )
    scrollView.refreshable(options: options) {}
}

// 只隐藏 ending；其他状态继续使用内置中文文案
@MainActor
func hideEndingText(on scrollView: UIScrollView) {
    let options = RefreshableOptions(
        textConfiguration: RefreshableTextConfiguration(ending: "")
    )
    scrollView.onLoadMore(options: options) {}
}
```

显式传入 `ClassicTopRefreshStyle`、`ClassicBottomLoadMoreStyle` 或 `SystemNativeRefreshStyle` 仍然可用，并保留各自原有的箭头、指示器和文案行为：

```swift
scrollView.refreshable(style: ClassicTopRefreshStyle()) {}
scrollView.onLoadMore(style: ClassicBottomLoadMoreStyle()) {}
scrollView.refreshable(style: SystemNativeRefreshStyle()) {}
```

`textConfiguration` 只在省略 `style:` 时应用；显式样式（包括上述样式和自定义 `RefreshableStyle`）不会读取它。

## 并发语义

`refreshable` 和 `onLoadMore` 的 action 是 SwiftUI 风格的 `@Sendable () async -> Void`，不会默认隔离到 `@MainActor`。组件安装、状态查询、手动启停和移除 API 仍是 `@MainActor`，因为它们会同步读写 UIKit 状态。

如果 action 内需要更新 UI 或主 actor 状态，请显式切回主 actor：

```swift
tableView.refreshable { [weak self] in
    guard let self else { return }
    let items = await service.fetchLatest()
    await MainActor.run {
        viewModel.items = items
        tableView.reloadData()
    }
}
```

## 自定义样式

`RefreshableStyle` 是可复用配置和 renderer 工厂。每次安装都会调用
`makeRenderer()`，因此同一个 style 可以安全地安装到多个 scroll view，视图和渲染状态互不共享：

```swift
@MainActor
final class MyHeaderStyle: RefreshableStyle {
    let extent: CGFloat = 60

    func makeRenderer() -> any RefreshableStyleRenderer {
        MyHeaderRenderer()
    }
}

@MainActor
final class MyHeaderRenderer: RefreshableStyleRenderer {
    let view: UIView = MyCustomView()

    func render(_ context: RefreshableStyleContext) {
        switch context.state {
        case .idle:           // 空闲
        case .pulling:        // context.pullProgress 为 0...1
        case .triggered:      // 达到阈值，松手即触发
        case .active:         // 刷新或加载动作执行中
        case .ending:         // 收起动画中
        case .noMoreData:     // 没有更多数据（仅 onLoadMore）
        }
    }
}

tableView.refreshable(style: MyHeaderStyle()) { [weak self] in
    await self?.viewModel.fetch()
}
```

> 无需管理 `view.alpha`，组件会自动处理（idle 透明，拖拽渐显，刷新时完全显示）。
> 自定义样式应按 `view.bounds` 布局。组件内部会处理滚动视图 host 几何、安全区和横向/纵向间距，不会改写样式视图的 `layoutMargins`。

`defaultTriggerDistance` 默认等于 `extent`，`defaultPlacement` 默认是全零配置；只有样式确实需要不同默认值时才需要覆盖。非正的 extent/trigger 会安全回退到 1pt，负数或非有限的间距和动画时长会归零。

### 内置自定义样式

核心产品保留系统感样式：

```swift
import Refreshable

// 原生系统感：箭头 + 进度环 + 菊花 + 文案
tableView.refreshable(style: SystemNativeRefreshStyle()) { [weak self] in
    await self?.viewModel.fetchLatest()
}
```

展示型样式迁移到独立的 `RefreshableStyles` 产品。将该产品加入 app target，并显式导入：

```swift
import Refreshable
import RefreshableStyles

// 动感彩带：弹性路径 + 彩色 tick + 状态胶囊
tableView.refreshable(style: KineticRefreshStyle()) { [weak self] in
    await self?.viewModel.fetchLatest()
}
```

Demo App 的“样式”页可以在真实 `UITableView` 中切换和试用系统感与动感两套刷新控件。要查看统一默认控件，请进入“样式”页并点击右上角“默认预览”；该预览可切换上、下、左、右四个方向以及刷新/加载更多角色，并可开关内置文案。

## 生命周期

scroll view 会存储 component，component 会存储 action、`onStateChange` 和 style。闭包引用 controller、view model 或 scroll view 时应使用 `[weak self]` / `[weak scrollView]`，避免形成
`scrollView → component → closure → owner → scrollView` 的存储环。移除或替换组件会取消任务、失效旧 generation，只移除自身 renderer view 和 inset 贡献。

## 兼容性

- iOS 13+
- Swift 6.0+（strict concurrency）
- UIScrollView / UITableView / UICollectionView

## License

MIT
