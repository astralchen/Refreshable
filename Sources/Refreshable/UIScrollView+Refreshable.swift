import UIKit
import ObjectiveC

// MARK: - Associated Object Keys

private enum AssociatedKeys {
    nonisolated(unsafe) static let header = malloc(1)!
    nonisolated(unsafe) static let footer = malloc(1)!
}

// MARK: - Public API

extension UIScrollView {

    // MARK: - 下拉刷新

    /// 使用默认样式添加下拉刷新
    @MainActor
    public func refreshable(action: @MainActor @escaping () async -> Void) {
        refreshable(style: DefaultHeaderStyle(), action: action)
    }

    /// 使用自定义样式添加下拉刷新
    @MainActor
    public func refreshable(style: some RefreshableStyle, action: @MainActor @escaping () async -> Void) {
        let component = HeaderRefreshComponent(style: style, action: action)
        self.headerComponent = component
        component.scrollView = self
    }

    /// 手动触发下拉刷新
    @MainActor
    public func beginRefreshing() {
        headerComponent?.beginRefreshing()
    }

    /// 手动结束下拉刷新
    @MainActor
    public func endRefreshing() {
        headerComponent?.endRefreshing()
    }

    // MARK: - 上拉加载

    /// 使用默认样式添加上拉加载
    @MainActor
    public func loadMoreable(action: @MainActor @escaping () async -> Void) {
        loadMoreable(style: DefaultFooterStyle(), action: action)
    }

    /// 使用自定义样式添加上拉加载
    @MainActor
    public func loadMoreable(style: some RefreshableStyle, action: @MainActor @escaping () async -> Void) {
        let component = FooterRefreshComponent(style: style, action: action)
        self.footerComponent = component
        component.scrollView = self
    }

    /// 手动触发上拉加载
    @MainActor
    public func beginLoadingMore() {
        footerComponent?.beginLoadingMore()
    }

    /// 手动结束上拉加载
    @MainActor
    public func endLoadingMore() {
        footerComponent?.endRefreshing()
    }

    /// 标记没有更多数据
    @MainActor
    public func noMoreData() {
        footerComponent?.setNoMoreData()
    }

    /// 重置没有更多数据状态，允许继续上拉加载
    @MainActor
    public func resetNoMoreData() {
        footerComponent?.resetNoMoreData()
    }

    // MARK: - Internal Accessors

    @MainActor
    var headerComponent: HeaderRefreshComponent? {
        get {
            objc_getAssociatedObject(self, AssociatedKeys.header) as? HeaderRefreshComponent
        }
        set {
            // 移除旧组件的视图
            headerComponent?.style.view.removeFromSuperview()
            objc_setAssociatedObject(self, AssociatedKeys.header, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    @MainActor
    var footerComponent: FooterRefreshComponent? {
        get {
            objc_getAssociatedObject(self, AssociatedKeys.footer) as? FooterRefreshComponent
        }
        set {
            footerComponent?.style.view.removeFromSuperview()
            objc_setAssociatedObject(self, AssociatedKeys.footer, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
