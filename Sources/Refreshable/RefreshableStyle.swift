import UIKit

/// 自定义刷新 UI 的协议
///
/// 实现此协议可替换默认的刷新视图。
/// ```swift
/// class MyHeaderStyle: RefreshableStyle {
///     let view: UIView = MyCustomView()
///     func update(state: RefreshState, progress: CGFloat) {
///         // 根据状态更新 UI
///     }
/// }
/// scrollView.refreshable(style: MyHeaderStyle()) { await vm.fetch() }
/// ```
@MainActor
public protocol RefreshableStyle: AnyObject {
    /// 刷新组件的视图，会被自动添加到 scrollView 中
    var view: UIView { get }

    /// 视图高度，用于计算触发阈值和 inset 偏移
    var height: CGFloat { get }

    /// 状态变化时调用，驱动自定义动画
    /// - Parameters:
    ///   - state: 当前刷新状态
    ///   - progress: pulling 阶段的拖拽进度 0...1，其他状态忽略
    func update(state: RefreshState, progress: CGFloat)
}
