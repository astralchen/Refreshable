import UIKit

/// 刷新视图的展示方式。
public enum RefreshablePresentation: Sendable, Equatable {
    /// 将刷新视图放在滚动内容边缘，并在 action 执行期间通过 `contentInset` 保持可见。
    case contentInset

    /// 将刷新视图浮在滚动视图当前可见区域的对应边缘内侧。
    ///
    /// 浮层模式不会修改 `contentInset`，适合全屏视频流等不希望内容被顶开或挤开的场景。
    ///
    /// - Parameter spacing: 刷新视图与安全区域边缘之间的距离。
    /// - Parameter locksContentOffset: 是否在边界拖动时将内容固定在当前边界。
    case overlay(spacing: CGFloat = 12, locksContentOffset: Bool = false)
}

/// 浮层刷新视图的锚定方式。
public enum RefreshableOverlayAnchor: Sendable, Equatable {
    /// 固定在滚动视图当前可见区域的边缘内侧。
    case viewport

    /// 跟随滚动内容边界，显示在内容起始或结束边缘外侧。
    case contentBoundary
}

extension RefreshablePresentation {
    var usesContentInset: Bool {
        switch self {
        case .contentInset:
            true
        case .overlay:
            false
        }
    }

    var locksContentOffset: Bool {
        switch self {
        case .contentInset:
            false
        case .overlay(_, let locksContentOffset):
            locksContentOffset
        }
    }
}

/// 控制刷新样式视觉视图在组件布局区域内的位置。
public struct RefreshablePlacement: Equatable {
    /// 刷新轴方向上，视觉控件与内容边缘之间的间距。
    public var contentSpacing: CGFloat

    /// 刷新轴方向上，视觉控件与可见外侧边缘之间的间距。
    public var outerSpacing: CGFloat

    /// 垂直于刷新方向的对称边距。
    public var crossAxisInset: CGFloat

    /// 创建刷新样式视觉视图的位置配置。
    ///
    /// - Parameters:
    ///   - contentSpacing: 刷新轴方向上，视觉控件与内容边缘之间的间距。
    ///   - outerSpacing: 刷新轴方向上，视觉控件与可见外侧边缘之间的间距。
    ///   - crossAxisInset: 垂直于刷新方向的对称边距。
    public init(contentSpacing: CGFloat = 0, outerSpacing: CGFloat = 0, crossAxisInset: CGFloat = 0) {
        self.contentSpacing = contentSpacing
        self.outerSpacing = outerSpacing
        self.crossAxisInset = crossAxisInset
    }
}

/// 一组用于配置刷新和加载更多行为的选项。
public struct RefreshableOptions {
    /// 触发刷新动作所需的拖动距离。
    ///
    /// 当此值为 `nil` 时，组件使用当前 `RefreshableStyle.extent` 作为触发距离。
    /// 进入刷新中后，`contentInset` 保持的可见范围由样式的 `extent`、
    /// `placement.outerSpacing` 和 `placement.contentSpacing` 决定。
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

    /// 组件宿主布局应用到样式视觉视图周围的位置配置。
    public var placement: RefreshablePlacement

    /// 刷新视图的展示方式。
    ///
    /// 默认值为 `.contentInset`，保持传统列表刷新体验。设置为 `.overlay` 时，刷新视图
    /// 不会修改 `contentInset`。浮层默认固定在滚动视图可见区域边缘，也可以配置为跟随内容
    /// 边界显示在最后一屏之后。浮层模式可选择在边界拖动时锁定内容偏移，适合下拉时不希望
    /// 视频画面移动的全屏视频流。
    public var presentation: RefreshablePresentation

    /// 浮层刷新视图的锚定方式。
    ///
    /// 仅在 `presentation` 为 `.overlay` 时生效。默认值为 `.viewport`，保持浮在当前可见区域
    /// 边缘的行为；设置为 `.contentBoundary` 时，刷新视图跟随内容边界，适合只在上拉越界拖拽
    /// 时显示在最后一屏之后。
    public var overlayAnchor: RefreshableOverlayAnchor

    /// 状态变化时在主线程调用的闭包。
    ///
    /// 安装组件时对样式执行的初始 `idle` 更新不会触发此闭包。
    public var onStateChange: (@MainActor (RefreshState) -> Void)?

    /// 创建一组刷新行为配置。
    ///
    /// - Parameters:
    ///   - triggerOffset: 触发刷新动作所需的拖动距离。传入 `nil` 时使用样式高度；刷新中的停留范围由样式高度、
    ///     `placement.outerSpacing` 和 `placement.contentSpacing` 决定。
    ///   - animationDuration: 展开和恢复 `contentInset` 时使用的动画时长。
    ///   - automaticallyEndRefreshing: 刷新动作结束后是否自动收起刷新组件。
    ///   - allowsLoadMoreWhenContentFits: 内容未填满当前滚动轴时是否仍允许触发加载更多。
    ///   - placement: 样式视觉视图在组件宿主区域内的位置配置。
    ///   - presentation: 刷新视图的展示方式。
    ///   - overlayAnchor: 浮层刷新视图的锚定方式。
    ///   - onStateChange: 状态变化时在主线程调用的闭包。
    public init(
        triggerOffset: CGFloat? = nil,
        animationDuration: TimeInterval = 0.25,
        automaticallyEndRefreshing: Bool = true,
        allowsLoadMoreWhenContentFits: Bool = false,
        placement: RefreshablePlacement = RefreshablePlacement(),
        presentation: RefreshablePresentation = .contentInset,
        overlayAnchor: RefreshableOverlayAnchor = .viewport,
        onStateChange: (@MainActor (RefreshState) -> Void)? = nil
    ) {
        self.triggerOffset = triggerOffset
        self.animationDuration = animationDuration
        self.automaticallyEndRefreshing = automaticallyEndRefreshing
        self.allowsLoadMoreWhenContentFits = allowsLoadMoreWhenContentFits
        self.placement = placement
        self.presentation = presentation
        self.overlayAnchor = overlayAnchor
        self.onStateChange = onStateChange
    }
}
