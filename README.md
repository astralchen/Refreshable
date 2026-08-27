# Refreshable

基于 `UIScrollView` 的刷新与加载更多控件。使用 async/await 驱动，支持 `.top`、`.bottom`、`.leading`、`.trailing` 四个语义边缘、自定义 UI、RTL、content inset 和 overlay 展示。Swift 6.0，iOS 13+。

## 安装

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/astralchen/Refreshable.git", from: "2.0.0")
]
```

App target 至少依赖 `Refreshable`；需要 Kinetic 或 Video 样式时，再加入 `RefreshableStyles`。

## 快速上手

每个滚动视图内部只有一个统一 coordinator，对外通过 UIKit 风格的 `UIScrollView` 方法管理所有 edge：

```swift
import Refreshable

tableView.refreshable(.refresh, for: .top) { [weak self] in
    guard let self else { return }
    let items = await service.fetchLatest()
    await MainActor.run {
        viewModel.items = items
        tableView.reloadData()
    }
}

tableView.refreshable(.loadMore, for: .bottom) { [weak self] in
    guard let self else { return }
    let page = await service.fetchNextPage()
    await MainActor.run {
        viewModel.append(page)
        tableView.reloadData()
    }
}
```

同一个 edge 再次 `refreshable` 会取消旧任务、恢复旧 inset、移除旧 host，再设置新 session。省略 `style` 时，内部 coordinator 会根据 `operation + edge` 选择默认样式。

## 控制与状态

```swift
scrollView.refreshState(for: .top)
scrollView.beginRefreshing(for: .top)
scrollView.endRefreshing(for: .top)
scrollView.setRefreshableEnabled(false, for: .bottom)
scrollView.markNoMoreData(for: .bottom)
scrollView.resetNoMoreData(for: .bottom)
scrollView.removeRefreshable(for: .top)
```

`markNoMoreData` 只对 `.loadMore` session 生效；刷新 session 会忽略它。`leading` 和 `trailing` 会根据 `effectiveUserInterfaceLayoutDirection` 自动映射到物理 left/right。

## 行为配置

```swift
let options = RefreshableOptions(
    triggerDistance: 80,
    animationDuration: 0.35,
    automaticallyEnds: false,
    allowsLoadMoreWhenContentFits: true,
    automaticTriggerDistance: 120,
    placement: RefreshablePlacement(
        contentSpacing: 12,
        outerSpacing: 8,
        crossAxisInset: 20
    ),
    presentation: .contentInset,
    onStateChange: { [weak self] state in
        self?.record(state)
    }
)

tableView.refreshable(
    .refresh,
    for: .top,
    options: options
) { [weak self, weak tableView] in
    await self?.viewModel.fetchLatest()
    await MainActor.run {
        tableView?.endRefreshing(for: .top)
    }
}
```

主要默认值：

- `triggerDistance: nil`：使用 `style.extent`
- `animationDuration: 0.25`
- `automaticallyEnds: true`：action 返回后自动结束
- `allowsLoadMoreWhenContentFits: false`
- `automaticTriggerDistance: .default`：底部加载更多默认在边界自动触发，其他情况默认关闭
- `placement: nil`：使用 style 的 `defaultPlacement`
- `presentation: .contentInset`；全屏内容可改用 `.overlay(spacing:locksContentOffset:)`

## 默认控件与文案

不传 `style` 时，四个方向都使用分段式 spinner。默认不显示状态文案。

```swift
let options = RefreshableOptions(
    textConfiguration: RefreshableTextConfiguration(active: "正在同步…")
)

scrollView.refreshable(
    .refresh,
    for: .top,
    options: options
) {}
```

- `textConfiguration == nil`：隐藏所有可见文案
- `RefreshableTextConfiguration()`：启用内置中文文案
- 非 nil 字段覆盖对应状态，nil 字段继续使用内置值
- 空字符串只隐藏对应状态
- 显式传入 style 时不读取 `textConfiguration`

内置显式样式仍可直接安装：

```swift
scrollView.refreshable(.refresh, for: .top, style: SystemNativeRefreshStyle()) {}
scrollView.refreshable(.loadMore, for: .bottom, style: ClassicBottomLoadMoreStyle()) {}
```

## 自定义样式

`RefreshableStyle` 是可复用配置与 renderer 工厂。每次安装都会创建独立 renderer 和 view：

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
        case .idle: break
        case .pulling: updateProgress(context.pullProgress)
        case .triggered: showReady()
        case .active: startAnimating()
        case .ending: stopAnimating()
        case .noMoreData: showNoMoreData()
        }
    }
}

scrollView.refreshable(
    .refresh,
    for: .top,
    style: MyHeaderStyle()
) { [weak self] in
    await self?.viewModel.fetch()
}
```

组件自动管理 renderer view 的 alpha。自定义样式应按 `view.bounds` 布局；host 几何、安全区、RTL 和间距由组件层处理。

`RefreshableStyles` 提供展示型样式：

```swift
import Refreshable
import RefreshableStyles

scrollView.refreshable(
    .refresh,
    for: .top,
    style: KineticRefreshStyle()
) {}
```

## 并发与生命周期

安装与控制 API 是 `@MainActor`；action 是 `@Sendable () async -> Void`，不会默认隔离到主 actor。更新 UIKit 时请显式使用 `MainActor.run`。

Coordinator 持有 session，session 存储 action、`onStateChange` 和 renderer。闭包引用 controller、view model 或 scroll view 时应弱捕获。替换、禁用和移除会取消任务并使旧 generation 的 completion 失效。

## 从 v1 迁移

v2 只提供按 edge 和 operation 统一命名的 `UIScrollView` API，不公开内部 coordinator，也不包含 v1 convenience API。迁移说明见 [MIGRATION.md](MIGRATION.md)。

## 系统要求

- iOS 13+
- Swift 6.0+
- `UIScrollView` / `UITableView` / `UICollectionView`

## License

MIT
