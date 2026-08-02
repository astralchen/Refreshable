import UIKit

/// 传递给刷新样式 renderer 的不可变渲染上下文。
public struct RefreshableStyleContext: Sendable, Equatable {
    /// 当前公开刷新状态。
    public let state: RefreshState

    /// 当前拖动进度。pulling 为 `0...1`，triggered 可继续增长到 `2`。
    public let pullProgress: CGFloat

    /// 创建渲染上下文。组件运行时会自动创建它；自定义 renderer 的测试和预览也可直接构造。
    public init(state: RefreshState, pullProgress: CGFloat) {
        self.state = state
        self.pullProgress = pullProgress
    }
}

/// 单次刷新组件安装所独占的视图 renderer。
@MainActor
public protocol RefreshableStyleRenderer: AnyObject {
    /// 由当前 renderer 独占的根视图。
    var view: UIView { get }

    /// 使用最新状态更新视图。
    func render(_ context: RefreshableStyleContext)
}

/// 可重复用于多个刷新组件的样式工厂。
@MainActor
public protocol RefreshableStyle {
    /// 刷新视图沿滚动轴占用的尺寸。
    var extent: CGFloat { get }

    /// 未显式配置触发距离时使用的距离。
    var defaultTriggerDistance: CGFloat { get }

    /// 未显式配置 placement 时使用的位置。
    var defaultPlacement: RefreshablePlacement { get }

    /// 创建一次安装所独占的 renderer。
    func makeRenderer() -> any RefreshableStyleRenderer
}

public extension RefreshableStyle {
    var defaultTriggerDistance: CGFloat { extent }

    var defaultPlacement: RefreshablePlacement { RefreshablePlacement() }
}

/// 内部样式能力：声明无更多数据终态是否需要继续占用 content inset。
///
/// 未实现此能力的公开/自定义样式保持原有行为，默认继续展示终态区域。
@MainActor
protocol RefreshableNoMoreDataInsetProviding {
    var reservesInsetForNoMoreData: Bool { get }
}
