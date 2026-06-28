import UIKit

/// 一组用于配置刷新和加载更多行为的选项。
public struct RefreshableOptions {
    /// 触发刷新动作所需的拖动距离。
    ///
    /// 当此值为 `nil` 时，组件使用当前 `RefreshableStyle.extent` 作为触发距离。
    public var triggerOffset: CGFloat?

    /// 展开和恢复 `contentInset` 时使用的动画时长。
    public var animationDuration: TimeInterval

    /// 一个布尔值，指示刷新动作结束后是否自动收起刷新组件。
    ///
    /// 默认值为 `true`。如果设置为 `false`，需要在 `action` 完成后手动调用
    /// `endRefreshing()` 或 `endLoadingMore()`。
    public var automaticallyEndRefreshing: Bool

    /// 一个布尔值，指示内容未填满当前滚动轴时是否仍允许触发加载更多。
    ///
    /// 此选项仅影响通过 `loadMoreable` 安装的组件。
    public var allowsLoadMoreWhenContentFits: Bool

    /// 状态变化时在主线程调用的闭包。
    ///
    /// 安装组件时对样式执行的初始 `idle` 更新不会触发此闭包。
    public var onStateChange: (@MainActor (RefreshState) -> Void)?

    /// 创建一组刷新行为配置。
    ///
    /// - Parameters:
    ///   - triggerOffset: 触发刷新动作所需的拖动距离。传入 `nil` 时使用样式高度。
    ///   - animationDuration: 展开和恢复 `contentInset` 时使用的动画时长。
    ///   - automaticallyEndRefreshing: 刷新动作结束后是否自动收起刷新组件。
    ///   - allowsLoadMoreWhenContentFits: 内容未填满当前滚动轴时是否仍允许触发加载更多。
    ///   - onStateChange: 状态变化时在主线程调用的闭包。
    public init(
        triggerOffset: CGFloat? = nil,
        animationDuration: TimeInterval = 0.25,
        automaticallyEndRefreshing: Bool = true,
        allowsLoadMoreWhenContentFits: Bool = false,
        onStateChange: (@MainActor (RefreshState) -> Void)? = nil
    ) {
        self.triggerOffset = triggerOffset
        self.animationDuration = animationDuration
        self.automaticallyEndRefreshing = automaticallyEndRefreshing
        self.allowsLoadMoreWhenContentFits = allowsLoadMoreWhenContentFits
        self.onStateChange = onStateChange
    }
}
