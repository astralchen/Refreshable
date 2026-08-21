import ObjectiveC
import UIKit

private enum AssociatedKeys {
    nonisolated(unsafe) static let coordinator = malloc(1)!
}

extension UIScrollView {
    // coordinator 通过关联对象保持稳定身份，但其类型和生命周期管理仍属于内部实现。
    @MainActor
    var refreshableCoordinator: RefreshableCoordinator {
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

    /// 设置或替换指定语义边缘上的刷新操作。
    ///
    /// - Parameters:
    ///   - operation: 刷新或加载更多操作。
    ///   - edge: 操作所在的语义边缘。
    ///   - style: 可选的自定义样式；省略时使用默认样式。
    ///   - options: 触发距离、展示方式和生命周期配置。
    ///   - action: 操作触发后执行的异步闭包。
    @MainActor
    public func setRefreshableOperation(
        _ operation: RefreshableOperation,
        for edge: RefreshableEdge,
        style: (any RefreshableStyle)? = nil,
        options: RefreshableOptions = .init(),
        action: @escaping @Sendable () async -> Void
    ) {
        refreshableCoordinator.setOperation(
            operation,
            for: edge,
            style: style,
            options: options,
            action: action
        )
    }

    /// 返回指定边缘的操作状态；未设置操作时返回 `.idle`。
    @MainActor
    public func refreshableState(for edge: RefreshableEdge) -> RefreshState {
        refreshableCoordinator.state(for: edge)
    }

    /// 尝试开始指定边缘的操作。
    @MainActor
    public func beginRefreshableOperation(for edge: RefreshableEdge) {
        refreshableCoordinator.beginOperation(for: edge)
    }

    /// 结束指定边缘的操作。
    @MainActor
    public func endRefreshableOperation(for edge: RefreshableEdge) {
        refreshableCoordinator.endOperation(for: edge)
    }

    /// 启用或禁用指定边缘的操作。
    @MainActor
    public func setRefreshableOperationEnabled(_ enabled: Bool, for edge: RefreshableEdge) {
        refreshableCoordinator.setEnabled(enabled, for: edge)
    }

    /// 将指定边缘的加载更多操作标记为没有更多数据；刷新操作忽略此调用。
    @MainActor
    public func markNoMoreData(for edge: RefreshableEdge) {
        refreshableCoordinator.markNoMoreData(for: edge)
    }

    /// 重置指定边缘的没有更多数据状态。
    @MainActor
    public func resetNoMoreData(for edge: RefreshableEdge) {
        refreshableCoordinator.resetNoMoreData(for: edge)
    }

    /// 移除指定边缘的操作，并恢复它产生的布局贡献。
    @MainActor
    public func removeRefreshableOperation(for edge: RefreshableEdge) {
        refreshableCoordinator.removeOperation(for: edge)
    }
}
