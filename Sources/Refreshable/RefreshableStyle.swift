import UIKit

/// 一个用于提供刷新组件外观和状态更新逻辑的协议。
///
/// 实现此协议可以替换默认的 header 或 footer 视图。刷新组件会自动将 `view`
/// 添加到滚动视图中，并在状态变化时调用 `update(state:progress:)`。
///
/// 下面的示例展示了如何提供自定义下拉刷新样式：
///
/// ```swift
/// class MyHeaderStyle: RefreshableStyle {
///     let view: UIView = MyCustomView()
///     let height: CGFloat = 56
///
///     func update(state: RefreshState, progress: CGFloat) {
///         // 根据状态更新 UI
///     }
/// }
///
/// scrollView.refreshable(style: MyHeaderStyle()) { await vm.fetch() }
/// ```
@MainActor
public protocol RefreshableStyle: AnyObject {
    /// 刷新组件显示的视图。
    ///
    /// 组件会自动将此视图添加到对应的 `UIScrollView` 中。
    var view: UIView { get }

    /// 刷新视图的高度。
    ///
    /// 当 `RefreshableOptions.triggerOffset` 为 `nil` 时，此值也会作为触发距离。
    var height: CGFloat { get }

    /// 通知样式对象根据最新状态更新界面。
    ///
    /// - Parameters:
    ///   - state: 当前刷新状态。
    ///   - progress: `pulling` 阶段的归一化拖动进度。其他状态通常可以忽略此值。
    func update(state: RefreshState, progress: CGFloat)
}
