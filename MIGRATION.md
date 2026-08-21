# v1 → v2 迁移指南

v2 将刷新与加载更多统一成一组 UIKit 风格的 `UIScrollView` 方法。内部 coordinator 不作为公开 API 暴露；v1 convenience API 已直接移除，不提供 deprecated 或 forwarding 适配层。

## 安装 session

设置操作时明确指定语义 operation 与 edge：

```swift
scrollView.setRefreshableOperation(
    .refresh,
    for: .top,
    style: headerStyle,
    options: refreshOptions
) {
    await viewModel.fetchLatest()
}

scrollView.setRefreshableOperation(
    .loadMore,
    for: .bottom,
    style: footerStyle,
    options: loadMoreOptions
) {
    await viewModel.fetchNextPage()
}
```

`style` 可以省略。此时内部 coordinator 会根据 `operation + edge` 选择默认控件，并继续应用 `RefreshableOptions.textConfiguration`。

## API 映射

| v1 职责 | v2 写法 |
|---|---|
| 安装刷新 | `scrollView.setRefreshableOperation(.refresh, for: ...)` |
| 安装加载更多 | `scrollView.setRefreshableOperation(.loadMore, for: ...)` |
| 手动开始 | `scrollView.beginRefreshableOperation(for:)` |
| 手动结束 | `scrollView.endRefreshableOperation(for:)` |
| 查询状态 | `scrollView.refreshableState(for:)` |
| 启用或禁用 | `scrollView.setRefreshableOperationEnabled(_:for:)` |
| 标记无更多数据 | `scrollView.markNoMoreData(for:)` |
| 重置无更多数据 | `scrollView.resetNoMoreData(for:)` |
| 移除 session | `scrollView.removeRefreshableOperation(for:)` |

## 语义变化

- 每个语义 edge 同时只有一个 session。相同 edge 再次安装会取消旧任务、恢复旧 inset，再替换为新 session。
- 状态和控制都按 edge 寻址，不再按刷新/加载更多维护两套 API。
- `markNoMoreData(for:)` 只对 `.loadMore` session 生效；刷新 session 会忽略该操作。
- 每个 scroll view 只建立一套 KVO 与 pan gesture 观察，并把快照分发给全部 edge session。
