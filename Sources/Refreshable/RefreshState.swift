import UIKit

/// 刷新组件的状态
public enum RefreshState: Sendable, Equatable {
    /// 空闲
    case idle
    /// 正在拖拽，progress 为 0...1 表示拖拽进度
    case pulling(CGFloat)
    /// 已达到触发阈值，松手即触发
    case triggered
    /// 正在刷新/加载中
    case refreshing
    /// 刷新结束，正在收起动画
    case ending
    /// 没有更多数据（仅 footer 使用）
    case noMoreData

    public var isRefreshing: Bool {
        self == .refreshing
    }
}
