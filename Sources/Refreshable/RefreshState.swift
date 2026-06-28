import UIKit

/// 刷新组件在交互和执行过程中的状态。
public enum RefreshState: Sendable, Equatable {
    /// 组件处于空闲状态，未显示任何刷新进度。
    case idle

    /// 用户正在拖动滚动视图，但尚未达到触发距离。
    ///
    /// 关联值表示归一化后的拖动进度，通常位于 `0...1` 范围内。
    case pulling(CGFloat)

    /// 用户已经达到触发距离，松手后会开始刷新或加载更多。
    case triggered

    /// 组件正在执行刷新或加载更多动作。
    case refreshing

    /// 刷新动作已经结束，组件正在执行收起动画。
    case ending

    /// footer 已经进入没有更多数据的状态。
    case noMoreData

    /// 一个布尔值，指示状态是否为 `refreshing`。
    public var isRefreshing: Bool {
        self == .refreshing
    }
}
