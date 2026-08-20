import UIKit
import ObjectiveC

// MARK: - 关联对象键

private enum AssociatedKeys {
    nonisolated(unsafe) static let coordinator = malloc(1)!
}

// MARK: - 公开 API

extension UIScrollView {

    /// The unified coordinator for all refresh and load-more sessions on this scroll view.
    @MainActor
    public var refreshableCoordinator: RefreshableCoordinator {
        if let coordinator = objc_getAssociatedObject(self, AssociatedKeys.coordinator)
            as? RefreshableCoordinator {
            return coordinator
        }
        let coordinator = RefreshableCoordinator(scrollView: self)
        objc_setAssociatedObject(
            self,
            AssociatedKeys.coordinator,
            coordinator,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        return coordinator
    }

    // MARK: - 刷新

    /// 为滚动视图添加刷新组件。
    ///
    /// 再次在同一边缘调用此方法会替换已经安装的组件，并取消其正在执行的任务。
    ///
    /// - Parameters:
    ///   - edge: 安装刷新组件的语义边缘。默认值为 `.top`。
    ///   - action: 触发刷新时执行的可发送异步操作；更新 UI 时需显式回到主 actor。
    @MainActor
    public func refreshable(
        edge: RefreshableEdge = .top,
        action: @escaping @Sendable () async -> Void
    ) {
        let resolvedOptions = RefreshableOptions()
        installRefreshable(
            edge: edge,
            style: DefaultRefreshControlStyle(
                edge: edge,
                role: .refresh,
                textConfiguration: resolvedOptions.textConfiguration
            ),
            options: resolvedOptions,
            action: action
        )
    }

    /// 使用指定配置为滚动视图添加刷新组件。
    ///
    /// - Parameters:
    ///   - edge: 安装刷新组件的语义边缘。默认值为 `.top`。
    ///   - options: 控制触发距离、动画和状态回调的配置。
    ///   - action: 触发刷新时执行的可发送异步操作；更新 UI 时需显式回到主 actor。
    @MainActor
    public func refreshable(
        edge: RefreshableEdge = .top,
        options: RefreshableOptions,
        action: @escaping @Sendable () async -> Void
    ) {
        let resolvedOptions = options
        installRefreshable(
            edge: edge,
            style: DefaultRefreshControlStyle(
                edge: edge,
                role: .refresh,
                textConfiguration: resolvedOptions.textConfiguration
            ),
            options: resolvedOptions,
            action: action
        )
    }

    /// 使用自定义样式为滚动视图添加刷新组件。
    ///
    /// - Parameters:
    ///   - edge: 安装刷新组件的语义边缘。默认值为 `.top`。
    ///   - style: 显示刷新状态的样式对象。
    ///   - action: 触发刷新时执行的可发送异步操作；更新 UI 时需显式回到主 actor。
    @MainActor
    public func refreshable(
        edge: RefreshableEdge = .top,
        style: some RefreshableStyle,
        action: @escaping @Sendable () async -> Void
    ) {
        installRefreshable(edge: edge, style: style, options: RefreshableOptions(), action: action)
    }

    /// 使用自定义样式和指定配置为滚动视图添加刷新组件。
    ///
    /// 再次在同一边缘调用此方法会替换已经安装的组件，并取消其正在执行的刷新任务。
    ///
    /// - Parameters:
    ///   - edge: 安装刷新组件的语义边缘。默认值为 `.top`。
    ///   - style: 显示刷新状态的样式对象。
    ///   - options: 控制触发距离、动画和状态回调的配置。
    ///   - action: 触发刷新时执行的可发送异步操作；更新 UI 时需显式回到主 actor。
    @MainActor
    public func refreshable(
        edge: RefreshableEdge = .top,
        style: some RefreshableStyle,
        options: RefreshableOptions,
        action: @escaping @Sendable () async -> Void
    ) {
        installRefreshable(edge: edge, style: style, options: options, action: action)
    }

    /// 以编程方式开始指定边缘的刷新。
    ///
    /// 如果该边缘未安装刷新组件、组件被禁用，或者当前已经在刷新中，此方法不会产生效果。
    ///
    /// - Parameter edge: 要开始刷新的语义边缘。默认值为 `.top`。
    @MainActor
    public func beginRefreshing(edge: RefreshableEdge = .top) {
        refreshComponent(for: edge)?.beginRefreshing()
    }

    /// 结束指定边缘的刷新并恢复对应方向的 inset。
    ///
    /// 如果该边缘未安装刷新组件或当前没有刷新任务，此方法不会产生效果。
    ///
    /// - Parameter edge: 要结束刷新的语义边缘。默认值为 `.top`。
    @MainActor
    public func endRefreshing(edge: RefreshableEdge = .top) {
        refreshComponent(for: edge)?.endAction()
    }

    // MARK: - 加载更多

    /// 为滚动视图添加加载更多组件。
    ///
    /// 再次在同一边缘调用此方法会替换已经安装的组件，并取消其正在执行的任务。
    ///
    /// - Parameters:
    ///   - edge: 安装加载更多组件的语义边缘。默认值为 `.bottom`。
    ///   - action: 触发加载更多时执行的可发送异步操作；更新 UI 时需显式回到主 actor。
    @MainActor
    public func onLoadMore(
        edge: RefreshableEdge = .bottom,
        action: @escaping @Sendable () async -> Void
    ) {
        let resolvedOptions = RefreshableOptions()
        installLoadMore(
            edge: edge,
            style: DefaultRefreshControlStyle(
                edge: edge,
                role: .loadMore,
                textConfiguration: resolvedOptions.textConfiguration
            ),
            options: resolvedOptions,
            action: action
        )
    }

    /// 使用指定配置为滚动视图添加加载更多组件。
    ///
    /// - Parameters:
    ///   - edge: 安装加载更多组件的语义边缘。默认值为 `.bottom`。
    ///   - options: 控制触发距离、动画和状态回调的配置。
    ///   - action: 触发加载更多时执行的可发送异步操作；更新 UI 时需显式回到主 actor。
    @MainActor
    public func onLoadMore(
        edge: RefreshableEdge = .bottom,
        options: RefreshableOptions,
        action: @escaping @Sendable () async -> Void
    ) {
        let resolvedOptions = options
        installLoadMore(
            edge: edge,
            style: DefaultRefreshControlStyle(
                edge: edge,
                role: .loadMore,
                textConfiguration: resolvedOptions.textConfiguration
            ),
            options: resolvedOptions,
            action: action
        )
    }

    /// 使用自定义样式为滚动视图添加加载更多组件。
    ///
    /// - Parameters:
    ///   - edge: 安装加载更多组件的语义边缘。默认值为 `.bottom`。
    ///   - style: 显示加载更多状态的样式对象。
    ///   - action: 触发加载更多时执行的可发送异步操作；更新 UI 时需显式回到主 actor。
    @MainActor
    public func onLoadMore(
        edge: RefreshableEdge = .bottom,
        style: some RefreshableStyle,
        action: @escaping @Sendable () async -> Void
    ) {
        installLoadMore(edge: edge, style: style, options: RefreshableOptions(), action: action)
    }

    /// 使用自定义样式和指定配置为滚动视图添加加载更多组件。
    ///
    /// 再次在同一边缘调用此方法会替换已经安装的组件，并取消其正在执行的加载任务。
    ///
    /// - Parameters:
    ///   - edge: 安装加载更多组件的语义边缘。默认值为 `.bottom`。
    ///   - style: 显示加载更多状态的样式对象。
    ///   - options: 控制触发距离、动画和状态回调的配置。
    ///   - action: 触发加载更多时执行的可发送异步操作；更新 UI 时需显式回到主 actor。
    @MainActor
    public func onLoadMore(
        edge: RefreshableEdge = .bottom,
        style: some RefreshableStyle,
        options: RefreshableOptions,
        action: @escaping @Sendable () async -> Void
    ) {
        installLoadMore(edge: edge, style: style, options: options, action: action)
    }

    /// 以编程方式开始指定边缘的加载更多。
    ///
    /// 如果该边缘未安装加载更多组件、组件被禁用、已经在加载中，或者已处于
    /// `noMoreData` 状态，此方法不会产生效果。
    ///
    /// - Parameter edge: 要开始加载更多的语义边缘。默认值为 `.bottom`。
    @MainActor
    public func beginLoadingMore(edge: RefreshableEdge = .bottom) {
        loadMoreComponent(for: edge)?.beginLoadingMore()
    }

    /// 结束指定边缘的加载更多并恢复对应方向的 inset。
    ///
    /// 如果该边缘未安装加载更多组件或当前没有加载任务，此方法不会产生效果。
    ///
    /// - Parameter edge: 要结束加载更多的语义边缘。默认值为 `.bottom`。
    @MainActor
    public func endLoadingMore(edge: RefreshableEdge = .bottom) {
        loadMoreComponent(for: edge)?.endAction()
    }

    /// 将指定边缘的加载更多组件标记为没有更多数据。
    ///
    /// 只有通过 `onLoadMore` 安装的组件会响应此方法；刷新组件会忽略该调用。
    ///
    /// - Parameter edge: 要标记的语义边缘。默认值为 `.bottom`。
    @MainActor
    public func markNoMoreData(edge: RefreshableEdge = .bottom) {
        loadMoreComponent(for: edge)?.markNoMoreData()
    }

    /// 重置指定边缘的没有更多数据状态。
    ///
    /// - Parameter edge: 要重置的语义边缘。默认值为 `.bottom`。
    @MainActor
    public func resetNoMoreData(edge: RefreshableEdge = .bottom) {
        loadMoreComponent(for: edge)?.resetNoMoreData()
    }

    // MARK: - 状态

    /// 当前默认顶部刷新状态。
    ///
    /// 如果未安装顶部刷新组件，此属性返回 `RefreshState.idle`。
    @MainActor
    public var refreshState: RefreshState {
        refreshState(edge: .top)
    }

    /// 返回指定边缘的刷新状态。
    ///
    /// 如果该边缘未安装刷新组件，此方法返回 `RefreshState.idle`。
    ///
    /// - Parameter edge: 要查询的语义边缘。
    @MainActor
    public func refreshState(edge: RefreshableEdge) -> RefreshState {
        refreshComponent(for: edge)?.state ?? .idle
    }

    /// 当前默认底部加载更多状态。
    ///
    /// 如果未安装底部加载更多组件，此属性返回 `RefreshState.idle`。
    @MainActor
    public var loadMoreState: RefreshState {
        loadMoreState(edge: .bottom)
    }

    /// 返回指定边缘的加载更多状态。
    ///
    /// 如果该边缘未安装加载更多组件，此方法返回 `RefreshState.idle`。
    ///
    /// - Parameter edge: 要查询的语义边缘。
    @MainActor
    public func loadMoreState(edge: RefreshableEdge) -> RefreshState {
        loadMoreComponent(for: edge)?.state ?? .idle
    }

    /// 一个布尔值，指示默认顶部刷新组件当前是否正在刷新。
    @MainActor
    public var isRefreshActive: Bool {
        isRefreshActive(edge: .top)
    }

    /// 返回指定边缘的刷新组件当前是否正在刷新。
    ///
    /// - Parameter edge: 要查询的语义边缘。
    @MainActor
    public func isRefreshActive(edge: RefreshableEdge) -> Bool {
        refreshState(edge: edge).isActive
    }

    /// 一个布尔值，指示默认底部加载更多组件当前是否正在加载。
    @MainActor
    public var isLoadMoreActive: Bool {
        isLoadMoreActive(edge: .bottom)
    }

    /// 返回指定边缘的加载更多组件当前是否正在加载。
    ///
    /// - Parameter edge: 要查询的语义边缘。
    @MainActor
    public func isLoadMoreActive(edge: RefreshableEdge) -> Bool {
        loadMoreState(edge: edge).isActive
    }

    // MARK: - 运行时控制

    /// 启用或禁用指定边缘的刷新组件。
    ///
    /// 禁用组件会取消正在执行的刷新任务；如果组件正在显示刷新状态，会开始收起。
    ///
    /// - Parameters:
    ///   - enabled: 传入 `true` 以启用刷新；传入 `false` 以禁用。
    ///   - edge: 要控制的语义边缘。默认值为 `.top`。
    @MainActor
    public func setRefreshEnabled(_ enabled: Bool, edge: RefreshableEdge = .top) {
        refreshComponent(for: edge)?.setEnabled(enabled)
    }

    /// 启用或禁用指定边缘的加载更多组件。
    ///
    /// 禁用组件会取消正在执行的加载任务；如果组件正在显示加载状态，会开始收起。
    ///
    /// - Parameters:
    ///   - enabled: 传入 `true` 以启用加载更多；传入 `false` 以禁用。
    ///   - edge: 要控制的语义边缘。默认值为 `.bottom`。
    @MainActor
    public func setLoadMoreEnabled(_ enabled: Bool, edge: RefreshableEdge = .bottom) {
        loadMoreComponent(for: edge)?.setEnabled(enabled)
    }

    /// 移除指定边缘的刷新组件。
    ///
    /// 移除时会取消正在执行的刷新任务，恢复对应方向的 inset，并移除组件视图。
    ///
    /// - Parameter edge: 要移除的语义边缘。默认值为 `.top`。
    @MainActor
    public func removeRefreshable(edge: RefreshableEdge = .top) {
        guard component(for: edge)?.role == .refresh else { return }
        setComponent(nil, for: edge)
    }

    /// 移除指定边缘的加载更多组件。
    ///
    /// 移除时会取消正在执行的加载任务，恢复对应方向的 inset，并移除组件视图。
    ///
    /// - Parameter edge: 要移除的语义边缘。默认值为 `.bottom`。
    @MainActor
    public func removeLoadMore(edge: RefreshableEdge = .bottom) {
        guard component(for: edge)?.role == .loadMore else { return }
        setComponent(nil, for: edge)
    }

    // MARK: - 内部访问

    @MainActor
    func component(for edge: RefreshableEdge) -> EdgeRefreshComponent? {
        refreshableCoordinator.component(for: edge)
    }

    @MainActor
    var headerComponent: EdgeRefreshComponent? {
        get {
            component(for: .top)
        }
        set {
            setComponent(newValue, for: .top)
        }
    }

    @MainActor
    var footerComponent: EdgeRefreshComponent? {
        get {
            component(for: .bottom)
        }
        set {
            setComponent(newValue, for: .bottom)
        }
    }

    private func installRefreshable(
        edge: RefreshableEdge,
        style: any RefreshableStyle,
        options: RefreshableOptions,
        action: @escaping @Sendable () async -> Void
    ) {
        refreshableCoordinator.install(
            edge: edge,
            operation: .refresh,
            style: style,
            options: options,
            action: action
        )
    }

    private func installLoadMore(
        edge: RefreshableEdge,
        style: any RefreshableStyle,
        options: RefreshableOptions,
        action: @escaping @Sendable () async -> Void
    ) {
        refreshableCoordinator.install(
            edge: edge,
            operation: .loadMore,
            style: style,
            options: options,
            action: action
        )
    }

    private func setComponent(_ component: EdgeRefreshComponent?, for edge: RefreshableEdge) {
        refreshableCoordinator.setComponent(component, at: edge)
    }

    private func refreshComponent(for edge: RefreshableEdge) -> EdgeRefreshComponent? {
        let component = component(for: edge)
        return component?.role == .refresh ? component : nil
    }

    private func loadMoreComponent(for edge: RefreshableEdge) -> EdgeRefreshComponent? {
        let component = component(for: edge)
        return component?.role == .loadMore ? component : nil
    }

}
