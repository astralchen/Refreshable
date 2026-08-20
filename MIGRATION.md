# Refreshable Coordinator Migration

RefreshableCoordinator replaces the separate refresh/load-more method families with one
edge-oriented runtime. Existing convenience APIs remain forwarding adapters during the
migration window.

## Install

    // Before
    scrollView.refreshable(edge: .top, style: style, options: options, action: action)
    scrollView.onLoadMore(edge: .bottom, style: style, options: options, action: action)

    // After
    let coordinator = scrollView.refreshableCoordinator
    coordinator.install(
        edge: .top,
        operation: .refresh,
        style: style,
        options: options,
        action: action
    )
    coordinator.install(
        edge: .bottom,
        operation: .loadMore,
        style: style,
        options: options,
        action: action
    )

Passing nil for style selects the existing default control and continues to apply
RefreshableOptions.textConfiguration.

## Control and state

| Before | After |
|---|---|
| beginRefreshing / beginLoadingMore | coordinator.begin |
| endRefreshing / endLoadingMore | coordinator.end |
| refreshState / loadMoreState | coordinator.state |
| setRefreshEnabled / setLoadMoreEnabled | coordinator.setEnabled |
| markNoMoreData | coordinator.markNoMoreData |
| resetNoMoreData | coordinator.resetNoMoreData |
| removeRefreshable / removeLoadMore | coordinator.remove |

The coordinator keeps one operation per semantic edge. Installing another operation at the
same edge replaces the old session and restores its inset before the replacement is attached.
