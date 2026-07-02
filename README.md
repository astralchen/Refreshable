# Refreshable

UIScrollView 刷新/加载更多控件。async/await 驱动，一行接入，支持 `.top`、`.bottom`、`.leading`、`.trailing` 四个语义边缘和自定义 UI。Swift 6.0，iOS 13+。

## 安装

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/astralchen/Refreshable.git", from: "1.0.0")
]
```

## 快速上手

```swift
import Refreshable

// 下拉刷新
tableView.refreshable {
    let items = await service.fetchLatest()
    await MainActor.run {
        viewModel.items = items
        tableView.reloadData()
    }
}

// 上拉加载
tableView.loadMoreable {
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
scrollView.loadMoreable { /* async */ }
scrollView.loadMoreable(edge: .trailing) { /* async */ }
scrollView.loadMoreable(options: options) { /* async */ }
scrollView.loadMoreable(style: MyStyle()) { /* async */ }
scrollView.loadMoreable(style: MyStyle(), options: options) { /* async */ }
scrollView.beginLoadingMore()
scrollView.beginLoadingMore(edge: .trailing)
scrollView.endLoadingMore()

// 没有更多数据
scrollView.noMoreData()
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
scrollView.removeLoadMoreable()
```

`leading` 和 `trailing` 是语义方向，会根据 `UIScrollView.effectiveUserInterfaceLayoutDirection` 在 LTR/RTL 下自动映射到物理 left/right。

## 行为配置

用 `RefreshableOptions` 调整触发距离、动画时长、自动结束、短内容加载、展示方式和状态回调：

```swift
let options = RefreshableOptions(
    triggerOffset: 80,
    animationDuration: 0.35,
    automaticallyEndRefreshing: false,
    allowsLoadMoreWhenContentFits: true,
    placement: RefreshablePlacement(contentSpacing: 12, outerSpacing: 8, crossAxisInset: 20),
    presentation: .contentInset,
    onStateChange: { state in
        print(state)
    }
)

tableView.refreshable(options: options) {
    await viewModel.fetchLatest()
    await MainActor.run {
        tableView.endRefreshing()
    }
}

tableView.loadMoreable(options: options) {
    await viewModel.fetchNextPage()
    await MainActor.run {
        tableView.endLoadingMore()
    }
}
```

选项默认值保持一行接入行为：

- `triggerOffset: nil` 使用 `style.extent` 作为触发距离；自定义 `triggerOffset` 只改变触发阈值，不改变刷新中保留的视觉占位
- `animationDuration: 0.25`
- `automaticallyEndRefreshing: true`，action 完成后自动收起
- `allowsLoadMoreWhenContentFits: false`，内容未填满当前滚动轴时默认不触发加载更多
- `placement: RefreshablePlacement()`，默认不增加额外间距；`outerSpacing` 沿刷新方向增加视觉控件与可见外侧边缘之间的距离，`contentSpacing` 增加视觉控件与内容之间的距离，`crossAxisInset` 在垂直于刷新方向的轴上收缩视觉控件
- `presentation: .contentInset`，默认通过 inset 保持刷新视图；全屏视频流可使用 `.overlay(spacing:locksContentOffset:)` 浮在可见区域边缘，并可在边界拖动时保持视频画面不移动

默认横向边缘样式会保留 8pt 外侧留白，让左右刷新控件不会贴住屏幕边缘；传入自定义 `placement` 时以调用方配置为准。

## 并发语义

`refreshable` 和 `loadMoreable` 的 action 是 SwiftUI 风格的 `@Sendable () async -> Void`，不会默认隔离到 `@MainActor`。组件安装、状态查询、手动启停和移除 API 仍是 `@MainActor`，因为它们会同步读写 UIKit 状态。

如果 action 内需要更新 UI 或主 actor 状态，请显式切回主 actor：

```swift
tableView.refreshable {
    let items = await service.fetchLatest()
    await MainActor.run {
        viewModel.items = items
        tableView.reloadData()
    }
}
```

## 自定义样式

实现 `RefreshableStyle` 协议即可替换默认 UI：

```swift
class MyHeaderStyle: RefreshableStyle {
    let view: UIView = MyCustomView()
    let extent: CGFloat = 60

    func update(state: RefreshState, progress: CGFloat) {
        switch state {
        case .idle:           // 空闲
        case .pulling(let p): // 拖拽中，p 为 0...1 进度
        case .triggered:      // 达到阈值，松手即触发
        case .refreshing:     // 刷新中
        case .ending:         // 收起动画中
        case .noMoreData:     // 没有更多数据（仅 loadMoreable）
        }
    }
}

tableView.refreshable(style: MyHeaderStyle()) {
    await viewModel.fetch()
}
```

> 无需管理 `view.alpha`，组件会自动处理（idle 透明，拖拽渐显，刷新时完全显示）。
> 自定义样式应按 `view.bounds` 布局。组件内部会处理滚动视图 host 几何、安全区和横向/纵向间距，不会改写样式视图的 `layoutMargins`。

### 内置自定义样式

库内提供三套可直接使用的自定义刷新样式：

```swift
// 原生系统感：箭头 + 进度环 + 菊花 + 文案
tableView.refreshable(style: SystemNativeRefreshStyle()) {
    await viewModel.fetchLatest()
}

// 高级玻璃太极：无可见文案，用旋转、辉光和粒子表达状态
tableView.refreshable(style: TaijiRefreshStyle()) {
    await viewModel.fetchLatest()
}

// 动感彩带：弹性路径 + 彩色 tick + 状态胶囊
tableView.refreshable(style: KineticRefreshStyle()) {
    await viewModel.fetchLatest()
}
```

Demo App 的“样式”页可以在真实 `UITableView` 中切换和试用这三套刷新控件。

## 兼容性

- iOS 13+
- Swift 6.0+（strict concurrency）
- UIScrollView / UITableView / UICollectionView

## License

MIT
