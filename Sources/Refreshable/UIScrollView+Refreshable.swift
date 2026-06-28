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

    /// 使用默认样式为滚动视图添加下拉刷新。
    ///
    /// 再次调用此方法会替换已经安装的 header 组件。
    ///
    /// - Parameter action: 触发刷新时在主线程执行的异步操作。
    @MainActor
    public func refreshable(action: @MainActor @escaping () async -> Void) {
        refreshable(style: DefaultHeaderStyle(), options: RefreshableOptions(), action: action)
    }

    /// 使用默认样式和指定配置为滚动视图添加下拉刷新。
    ///
    /// - Parameters:
    ///   - options: 控制触发距离、动画和状态回调的配置。
    ///   - action: 触发刷新时在主线程执行的异步操作。
    @MainActor
    public func refreshable(options: RefreshableOptions, action: @MainActor @escaping () async -> Void) {
        refreshable(style: DefaultHeaderStyle(), options: options, action: action)
    }

    /// 使用自定义样式为滚动视图添加下拉刷新。
    ///
    /// - Parameters:
    ///   - style: 显示刷新状态的 header 样式对象。
    ///   - action: 触发刷新时在主线程执行的异步操作。
    @MainActor
    public func refreshable(style: some RefreshableStyle, action: @MainActor @escaping () async -> Void) {
        refreshable(style: style, options: RefreshableOptions(), action: action)
    }

    /// 使用自定义样式和指定配置为滚动视图添加下拉刷新。
    ///
    /// 再次调用此方法会替换已经安装的 header 组件，并取消其正在执行的刷新任务。
    ///
    /// - Parameters:
    ///   - style: 显示刷新状态的 header 样式对象。
    ///   - options: 控制触发距离、动画和状态回调的配置。
    ///   - action: 触发刷新时在主线程执行的异步操作。
    @MainActor
    public func refreshable(
        style: some RefreshableStyle,
        options: RefreshableOptions,
        action: @MainActor @escaping () async -> Void
    ) {
        let component = HeaderRefreshComponent(style: style, options: options, action: action)
        self.headerComponent = component
        component.scrollView = self
    }

    /// 以编程方式开始下拉刷新。
    ///
    /// 如果未安装 header、组件被禁用，或者当前已经在刷新中，此方法不会产生效果。
    @MainActor
    public func beginRefreshing() {
        headerComponent?.beginRefreshing()
    }

    /// 结束当前下拉刷新并恢复滚动视图的顶部 inset。
    ///
    /// 如果未安装 header 或当前没有刷新任务，此方法不会产生效果。
    @MainActor
    public func endRefreshing() {
        headerComponent?.endRefreshing()
    }

    // MARK: - 上拉加载

    /// 使用默认样式为滚动视图添加上拉加载。
    ///
    /// 再次调用此方法会替换已经安装的 footer 组件。
    ///
    /// - Parameter action: 触发加载更多时在主线程执行的异步操作。
    @MainActor
    public func loadMoreable(action: @MainActor @escaping () async -> Void) {
        loadMoreable(style: DefaultFooterStyle(), options: RefreshableOptions(), action: action)
    }

    /// 使用默认样式和指定配置为滚动视图添加上拉加载。
    ///
    /// - Parameters:
    ///   - options: 控制触发距离、动画和状态回调的配置。
    ///   - action: 触发加载更多时在主线程执行的异步操作。
    @MainActor
    public func loadMoreable(options: RefreshableOptions, action: @MainActor @escaping () async -> Void) {
        loadMoreable(style: DefaultFooterStyle(), options: options, action: action)
    }

    /// 使用自定义样式为滚动视图添加上拉加载。
    ///
    /// - Parameters:
    ///   - style: 显示加载更多状态的 footer 样式对象。
    ///   - action: 触发加载更多时在主线程执行的异步操作。
    @MainActor
    public func loadMoreable(style: some RefreshableStyle, action: @MainActor @escaping () async -> Void) {
        loadMoreable(style: style, options: RefreshableOptions(), action: action)
    }

    /// 使用自定义样式和指定配置为滚动视图添加上拉加载。
    ///
    /// 再次调用此方法会替换已经安装的 footer 组件，并取消其正在执行的加载任务。
    ///
    /// - Parameters:
    ///   - style: 显示加载更多状态的 footer 样式对象。
    ///   - options: 控制触发距离、动画和状态回调的配置。
    ///   - action: 触发加载更多时在主线程执行的异步操作。
    @MainActor
    public func loadMoreable(
        style: some RefreshableStyle,
        options: RefreshableOptions,
        action: @MainActor @escaping () async -> Void
    ) {
        let component = FooterRefreshComponent(style: style, options: options, action: action)
        self.footerComponent = component
        component.scrollView = self
    }

    /// 以编程方式开始上拉加载。
    ///
    /// 如果未安装 footer、组件被禁用、已经在加载中，或者已处于 `noMoreData` 状态，
    /// 此方法不会产生效果。
    @MainActor
    public func beginLoadingMore() {
        footerComponent?.beginLoadingMore()
    }

    /// 结束当前上拉加载并恢复滚动视图的底部 inset。
    ///
    /// 如果未安装 footer 或当前没有加载任务，此方法不会产生效果。
    @MainActor
    public func endLoadingMore() {
        footerComponent?.endRefreshing()
    }

    /// 将上拉加载组件标记为没有更多数据。
    ///
    /// 处于此状态时，拖动和 `beginLoadingMore()` 都不会再次触发加载。
    @MainActor
    public func noMoreData() {
        footerComponent?.setNoMoreData()
    }

    /// 重置没有更多数据状态，允许 footer 再次触发加载。
    @MainActor
    public func resetNoMoreData() {
        footerComponent?.resetNoMoreData()
    }

    // MARK: - 状态查询

    /// 当前下拉刷新状态。
    ///
    /// 如果未安装 header，此属性返回 `RefreshState.idle`。
    @MainActor
    public var refreshState: RefreshState {
        headerComponent?.state ?? .idle
    }

    /// 当前上拉加载状态。
    ///
    /// 如果未安装 footer，此属性返回 `RefreshState.idle`。
    @MainActor
    public var loadMoreState: RefreshState {
        footerComponent?.state ?? .idle
    }

    /// 一个布尔值，指示 header 当前是否正在刷新。
    @MainActor
    public var isRefreshActive: Bool {
        refreshState.isRefreshing
    }

    /// 一个布尔值，指示 footer 当前是否正在加载。
    @MainActor
    public var isLoadMoreActive: Bool {
        loadMoreState.isRefreshing
    }

    // MARK: - 运行时控制

    /// 启用或禁用下拉刷新。
    ///
    /// 禁用 header 会取消正在执行的刷新任务；如果组件正在显示刷新状态，会开始收起。
    ///
    /// - Parameter enabled: 传入 `true` 以启用下拉刷新；传入 `false` 以禁用。
    @MainActor
    public func setRefreshEnabled(_ enabled: Bool) {
        headerComponent?.setEnabled(enabled)
    }

    /// 启用或禁用上拉加载。
    ///
    /// 禁用 footer 会取消正在执行的加载任务；如果组件正在显示加载状态，会开始收起。
    ///
    /// - Parameter enabled: 传入 `true` 以启用上拉加载；传入 `false` 以禁用。
    @MainActor
    public func setLoadMoreEnabled(_ enabled: Bool) {
        footerComponent?.setEnabled(enabled)
    }

    /// 移除当前安装的下拉刷新组件。
    ///
    /// 移除时会取消正在执行的刷新任务，恢复顶部 inset，并从滚动视图中移除 header 视图。
    @MainActor
    public func removeRefreshable() {
        headerComponent = nil
    }

    /// 移除当前安装的上拉加载组件。
    ///
    /// 移除时会取消正在执行的加载任务，恢复底部 inset，并从滚动视图中移除 footer 视图。
    @MainActor
    public func removeLoadMoreable() {
        footerComponent = nil
    }

    // MARK: - Internal Accessors

    @MainActor
    var headerComponent: HeaderRefreshComponent? {
        get {
            objc_getAssociatedObject(self, AssociatedKeys.header) as? HeaderRefreshComponent
        }
        set {
            if let old = headerComponent, old !== newValue {
                old.prepareForRemoval()
            }
            objc_setAssociatedObject(self, AssociatedKeys.header, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    @MainActor
    var footerComponent: FooterRefreshComponent? {
        get {
            objc_getAssociatedObject(self, AssociatedKeys.footer) as? FooterRefreshComponent
        }
        set {
            if let old = footerComponent, old !== newValue {
                old.prepareForRemoval()
            }
            objc_setAssociatedObject(self, AssociatedKeys.footer, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
