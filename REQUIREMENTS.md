# Refreshable — 需求文档

## 1. 项目概述

基于 UIScrollView 的通用边缘刷新 / 加载更多控件，以 Swift Package 形式提供。
API 风格对标 SwiftUI `.refreshable {}`，一行代码即可接入。

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
- 支持 `beginRefreshing()` 手动触发（代码驱动，如首次进入页面）
- 支持 `beginRefreshing(edge:)` 手动触发指定边缘
- 支持 `endRefreshing()` 手动结束（兜底）
- 支持通过 `RefreshableOptions` 调整触发距离、动画时长、自动结束和状态回调
- 支持运行时启用、禁用和移除指定边缘刷新组件

### 3.2 加载更多

- 用户沿指定 edge 拖动到内容末端超过阈值松手后，触发加载
- 默认 edge 为 `.bottom`，也支持 `.top`、`.leading`、`.trailing`
- 加载期间显示 loading indicator，对应方向的 `contentInset` 自动增加
- async 闭包返回后自动结束加载
- 支持 `beginLoadingMore()` 手动触发
- 支持 `beginLoadingMore(edge:)` 手动触发指定边缘
- 支持 `endLoadingMore()` 手动结束
- 支持 `noMoreData()` 标记无更多数据（显示终态文案，停止触发）
- 支持 `noMoreData(edge:)` 标记指定边缘
- 支持 `resetNoMoreData()` 重置状态（如下拉刷新后重新允许上拉）
- 内容不足当前 edge 所在轴的视口时默认不触发加载，可通过 `allowsLoadMoreWhenContentFits` 开启
- 支持运行时启用、禁用和移除指定边缘加载组件

### 3.3 防重入

刷新/加载进行中，再次下拉或上拉不会重复触发。
同一 scroll view 的同一 edge 同时只允许一个组件；重复安装会替换旧组件并恢复旧 inset。

### 3.4 自定义 UI

- 提供 `RefreshableStyle` 协议，实现即可替换默认视图
- 协议要求：`view`（UIView）、`extent`（CGFloat）、`update(state:progress:)`
- 通过 `scrollView.refreshable(style:action:)` 传入自定义样式

### 3.5 默认 UI

- **下拉**：箭头图标（跟随拖拽旋转）+ 文案 + 菊花
- **上拉**：菊花 + 文案，noMoreData 时显示 "没有更多数据"
- **横向边缘**：使用适配 `.leading` / `.trailing` 的默认样式，并使用动态系统颜色适配深色模式

### 3.6 通用性

通过 `extension UIScrollView` 提供，无需子类化。
UITableView、UICollectionView 及任何 UIScrollView 子类均可使用。
`leading` / `trailing` 为语义方向，按 `effectiveUserInterfaceLayoutDirection` 自动适配 RTL。

## 4. 公开 API

```swift
// 下拉刷新
scrollView.refreshable { await vm.fetch() }
scrollView.refreshable(edge: .leading) { await vm.fetch() }
scrollView.refreshable(options: RefreshableOptions()) { await vm.fetch() }
scrollView.refreshable(style: CustomHeader()) { await vm.fetch() }
scrollView.refreshable(style: CustomHeader(), options: RefreshableOptions()) { await vm.fetch() }
scrollView.beginRefreshing()
scrollView.beginRefreshing(edge: .leading)
scrollView.endRefreshing()
scrollView.setRefreshEnabled(false)
scrollView.removeRefreshable()

// 上拉加载
scrollView.loadMoreable { await vm.loadNext() }
scrollView.loadMoreable(edge: .trailing) { await vm.loadNext() }
scrollView.loadMoreable(options: RefreshableOptions()) { await vm.loadNext() }
scrollView.loadMoreable(style: CustomFooter()) { await vm.loadNext() }
scrollView.loadMoreable(style: CustomFooter(), options: RefreshableOptions()) { await vm.loadNext() }
scrollView.beginLoadingMore()
scrollView.beginLoadingMore(edge: .trailing)
scrollView.endLoadingMore()
scrollView.noMoreData()
scrollView.noMoreData(edge: .trailing)
scrollView.resetNoMoreData()
scrollView.setLoadMoreEnabled(false)
scrollView.removeLoadMoreable()

// 状态查询
scrollView.refreshState
scrollView.refreshState(edge: .leading)
scrollView.loadMoreState
scrollView.loadMoreState(edge: .trailing)
scrollView.isRefreshActive
scrollView.isLoadMoreActive
```

`RefreshableOptions`：

```swift
RefreshableOptions(
    triggerOffset: nil,
    animationDuration: 0.25,
    automaticallyEndRefreshing: true,
    allowsLoadMoreWhenContentFits: false,
    onStateChange: nil
)
```

## 5. 状态机

```
Refresh:  idle → pulling(progress) → triggered → refreshing → ending → idle
LoadMore: idle → pulling(progress) → triggered → refreshing → ending → idle
                                                                 ↘ noMoreData
```

| 状态 | 含义 |
|------|------|
| `idle` | 空闲 |
| `pulling(CGFloat)` | 正在拖拽，progress 0...1 |
| `triggered` | 已达阈值，松手即触发 |
| `refreshing` | 刷新/加载中 |
| `ending` | 收起动画中 |
| `noMoreData` | 无更多数据（仅 `loadMoreable`） |

## 6. 自定义样式协议

```swift
@MainActor
public protocol RefreshableStyle: AnyObject {
    var view: UIView { get }
    var extent: CGFloat { get }
    func update(state: RefreshState, progress: CGFloat)
}
```

## 7. 视图可见性（借鉴 UIRefreshControl）

style.view 的 alpha 由组件自动管理，idle 时完全不可见，拖拽时渐显：

| 状态 | alpha | 说明 |
|------|-------|------|
| idle | 0 | 完全透明，bounce 时不会露出 |
| pulling(p) | p (0→1) | 跟随拖拽进度渐显 |
| triggered | 1 | 完全可见 |
| refreshing | 1 | 完全可见 |
| ending | 保持 | 收起动画期间保持可见，回到 idle 后隐藏 |
| noMoreData | 1 | 显示终态文案 |

> 自定义 `RefreshableStyle` 无需手动管理 alpha，组件层自动处理。

## 8. 默认样式行为

### DefaultHeaderStyle（extent 54pt）

| 状态 | 箭头 | 菊花 | 文案 |
|------|------|------|------|
| idle | ↓ 显示 | 停止 | 下拉刷新 |
| pulling(p) | 旋转 p×180° | 停止 | 下拉刷新 |
| triggered | ↑ 翻转 | 停止 | 释放刷新 |
| refreshing | 隐藏 | 旋转 | 正在刷新... |
| ending | 隐藏 | 停止 | 刷新完成 |

### DefaultFooterStyle（extent 54pt）

| 状态 | 菊花 | 文案 |
|------|------|------|
| idle | 停止 | 上拉加载更多 |
| pulling | 停止 | 上拉加载更多 |
| triggered | 停止 | 释放加载 |
| refreshing | 旋转 | 正在加载... |
| ending | 停止 | 加载完成 |
| noMoreData | 停止 | 没有更多数据 |

## 9. 实现架构

```
UIScrollView+Refreshable.swift    公开 API（associated object 持有 edge store）
        │
        ├── EdgeRefreshComponent      edge/role 几何、inset 和触发逻辑
        │         │
        ├── HeaderRefreshComponent    top refresh 兼容包装
        └── FooterRefreshComponent    bottom loadMore 兼容包装
                  │
            RefreshComponent          基类（状态机 + KVO + task 管理）
                  │
            RefreshableStyle          样式协议（默认 / 自定义）
```

**关键实现细节：**

- **关联存储**：`objc_setAssociatedObject` 存放 edge store，scrollView 强引用 component，component weak 引用 scrollView
- **KVO 监听**：`contentOffset`（滚动）、`contentSize`（bottom/trailing 位置跟随）、`panGestureRecognizer.state`（松手检测）
- **inset 管理**：记录原始 `contentInset`，只修改和恢复当前 edge 对应的方向
- **线程安全**：所有组件安装、状态控制和样式更新标记 `@MainActor`；action 闭包为 SwiftUI 风格的 `@Sendable () async -> Void`，需要更新 UI 时由调用方显式回到主 actor

## 10. 文件结构

```
Refreshable/
├── Package.swift
├── Sources/Refreshable/
│   ├── RefreshState.swift
│   ├── RefreshableEdge.swift
│   ├── RefreshableStyle.swift
│   ├── RefreshableOptions.swift
│   ├── DefaultHeaderStyle.swift
│   ├── DefaultFooterStyle.swift
│   ├── DefaultEdgeStyle.swift
│   ├── RefreshComponent.swift
│   ├── EdgeRefreshComponent.swift
│   ├── HeaderRefreshComponent.swift
│   ├── FooterRefreshComponent.swift
│   └── UIScrollView+Refreshable.swift
├── Tests/RefreshableTests/
│   ├── MockStyle.swift
│   ├── RefreshStateTests.swift
│   ├── RefreshableOptionsTests.swift
│   ├── DefaultStyleTests.swift
│   ├── RefreshComponentTests.swift
│   ├── EdgeRefreshComponentTests.swift
│   ├── HeaderRefreshComponentTests.swift
│   ├── FooterRefreshComponentTests.swift
│   └── UIScrollViewExtensionTests.swift
└── Demo/
    └── Demo/
        ├── TableViewDemoController.swift
        └── CollectionViewDemoController.swift
```

## 11. 测试覆盖

110 个测试用例，9 个 Suite：

| Suite | 数量 | 覆盖点 |
|-------|------|--------|
| RefreshState | 2 | isRefreshing、Equatable |
| RefreshableOptions | 2 | 默认配置、自定义配置 |
| DefaultHeaderStyle | 3 | extent、子视图、全状态 update |
| DefaultFooterStyle | 2 | extent、全状态 update |
| RefreshComponent 基类 | 9 | originalInset、setState 去重、scrollView 替换、完整流转、状态回调、`@Sendable` action 存储、自动结束 |
| EdgeRefreshComponent | 7 | leading/trailing 安装、RTL、水平 inset、noMoreData 语义、多 edge 隔离、水平短内容判断 |
| HeaderRefreshComponent | 25 | 安装、状态机、endDragging、防重入、手动触发/结束、inset、action 执行、取消任务 |
| FooterRefreshComponent | 30 | 安装、状态机、防重入、noMoreData/reset、contentSize 变化、内容不足一屏、短内容加载选项 |
| UIScrollView+Refreshable | 30 | 设置/替换/移除组件、`@Sendable` action 语义、显式 MainActor 回跳、手动控制、状态查询、启停控制、Header+Footer 共存、UITableView/UICollectionView 兼容 |

## 12. Demo 示例

| 页面 | 视图类型 | 演示内容 |
|------|---------|---------|
| TableView Demo | UITableView | 下拉刷新 20 条文本 + 上拉分页加载 15 条/页，3 页后 noMoreData |
| CollectionView Demo | UICollectionView | 3 列彩色方块网格，下拉刷新 18 个 + 上拉加载 12 个/页，3 页后 noMoreData |

## 13. 非需求（明确不做）

- Combine / RxSwift 绑定
- SwiftUI 原生支持（SwiftUI 已有内置 `.refreshable`）
- 自动分页（由调用方控制页码逻辑）
