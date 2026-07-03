import UIKit

/// 一个用于提供刷新组件外观和状态更新逻辑的协议。
///
/// 实现此协议可以替换默认的边缘刷新视图。刷新组件会自动安装 `view`，
/// 并在状态变化时调用 `update(state:progress:)`。
///
/// 下面的示例展示了如何提供自定义刷新样式：
///
/// ```swift
/// final class MyRefreshStyle: RefreshableStyle {
///     let view: UIView = MyCustomView()
///     let extent: CGFloat = 56
///
///     func update(state: RefreshState, progress: CGFloat) {
///         // 根据状态更新 UI
///     }
/// }
///
/// scrollView.refreshable(style: MyRefreshStyle()) { await vm.fetch() }
/// ```
@MainActor
public protocol RefreshableStyle: AnyObject {
    /// 渲染刷新控件视觉内容的视图。
    ///
    /// 组件可能会将此视图安装在内部宿主视图中。样式应基于此视图自身的
    /// `bounds` 布局，不应依赖 `superview` 或 `layoutMargins` 获取组件几何信息。
    var view: UIView { get }

    /// 刷新视图沿滚动轴占用的尺寸。
    ///
    /// 对 `.top` 和 `.bottom` 边缘，此值表示高度；对 `.leading` 和 `.trailing`
    /// 边缘，此值表示宽度。当 `RefreshableOptions.triggerOffset` 为 `nil` 时，
    /// 此值也会作为触发距离。
    var extent: CGFloat { get }

    /// 通知样式对象根据最新状态更新界面。
    ///
    /// - Parameters:
    ///   - state: 当前刷新状态。
    ///   - progress: `pulling` 阶段的归一化拖动进度。其他状态通常可以忽略此值。
    func update(state: RefreshState, progress: CGFloat)
}
