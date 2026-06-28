import UIKit

/// 刷新组件的行为配置。
public struct RefreshableOptions {
    /// 触发距离。nil 表示使用 style.height，保持现有行为。
    public var triggerOffset: CGFloat?

    /// inset 展开和收起动画时长。
    public var animationDuration: TimeInterval

    /// action 完成后是否自动调用 endRefreshing/endLoadingMore。
    public var automaticallyEndRefreshing: Bool

    /// 内容不足一屏时，是否仍允许上拉加载。
    public var allowsLoadMoreWhenContentFits: Bool

    /// 状态变化回调，不包含安装时对 style 的 idle 初始化调用。
    public var onStateChange: (@MainActor (RefreshState) -> Void)?

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
