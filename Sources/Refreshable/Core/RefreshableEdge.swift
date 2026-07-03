import UIKit

/// 刷新组件可以安装到的滚动视图边缘。
///
/// `leading` 和 `trailing` 是语义方向，会根据滚动视图的有效界面布局方向
/// 映射到物理的左侧或右侧。
public enum RefreshableEdge: Sendable, CaseIterable, Hashable {
    /// 滚动内容顶部边缘。
    case top

    /// 滚动内容底部边缘。
    case bottom

    /// 当前界面布局方向的起始边缘。
    case leading

    /// 当前界面布局方向的结束边缘。
    case trailing
}

enum RefreshableRole: Sendable, Equatable {
    case refresh
    case loadMore
}

enum RefreshableAxis {
    case vertical
    case horizontal
}

enum RefreshablePhysicalEdge {
    case top
    case bottom
    case left
    case right

    var axis: RefreshableAxis {
        switch self {
        case .top, .bottom:
            .vertical
        case .left, .right:
            .horizontal
        }
    }

    var isStartEdge: Bool {
        switch self {
        case .top, .left:
            true
        case .bottom, .right:
            false
        }
    }
}

extension RefreshableEdge {
    var axis: RefreshableAxis {
        switch self {
        case .top, .bottom:
            .vertical
        case .leading, .trailing:
            .horizontal
        }
    }

    @MainActor
    func physicalEdge(in view: UIView) -> RefreshablePhysicalEdge {
        switch self {
        case .top:
            .top
        case .bottom:
            .bottom
        case .leading:
            view.effectiveUserInterfaceLayoutDirection == .rightToLeft ? .right : .left
        case .trailing:
            view.effectiveUserInterfaceLayoutDirection == .rightToLeft ? .left : .right
        }
    }
}

extension UIEdgeInsets {
    func value(for edge: RefreshablePhysicalEdge) -> CGFloat {
        switch edge {
        case .top:
            top
        case .bottom:
            bottom
        case .left:
            left
        case .right:
            right
        }
    }

    mutating func setValue(_ value: CGFloat, for edge: RefreshablePhysicalEdge) {
        switch edge {
        case .top:
            top = value
        case .bottom:
            bottom = value
        case .left:
            left = value
        case .right:
            right = value
        }
    }
}
