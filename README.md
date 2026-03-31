# Refreshable

UIScrollView 下拉刷新/上拉加载控件。async/await 驱动，一行接入，支持自定义 UI。Swift 6.0，iOS 13+。

## 安装

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/your-repo/Refreshable.git", from: "1.0.0")
]
```

## 快速上手

```swift
import Refreshable

// 下拉刷新
tableView.refreshable {
    await viewModel.fetchLatest()
}

// 上拉加载
tableView.loadMoreable {
    await viewModel.fetchNextPage()
}
```

## API

```swift
// 下拉刷新
scrollView.refreshable { /* async */ }
scrollView.refreshable(style: MyStyle()) { /* async */ }
scrollView.beginRefreshing()
scrollView.endRefreshing()

// 上拉加载
scrollView.loadMoreable { /* async */ }
scrollView.loadMoreable(style: MyStyle()) { /* async */ }
scrollView.beginLoadingMore()
scrollView.endLoadingMore()

// 没有更多数据
scrollView.noMoreData()
scrollView.resetNoMoreData()
```

## 自定义样式

实现 `RefreshableStyle` 协议即可替换默认 UI：

```swift
class MyHeaderStyle: RefreshableStyle {
    let view: UIView = MyCustomView()
    let height: CGFloat = 60

    func update(state: RefreshState, progress: CGFloat) {
        switch state {
        case .idle:           // 空闲
        case .pulling(let p): // 拖拽中，p 为 0...1 进度
        case .triggered:      // 达到阈值，松手即触发
        case .refreshing:     // 刷新中
        case .ending:         // 收起动画中
        case .noMoreData:     // 没有更多数据（仅 footer）
        }
    }
}

tableView.refreshable(style: MyHeaderStyle()) {
    await viewModel.fetch()
}
```

> 无需管理 `view.alpha`，组件会自动处理（idle 透明，拖拽渐显，刷新时完全显示）。

## 兼容性

- iOS 13+
- Swift 6.0+（strict concurrency）
- UIScrollView / UITableView / UICollectionView

## License

MIT
