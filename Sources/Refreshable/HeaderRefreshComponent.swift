import UIKit

/// 下拉刷新组件。
@MainActor
final class HeaderRefreshComponent: EdgeRefreshComponent {

    init(
        style: any RefreshableStyle,
        options: RefreshableOptions = RefreshableOptions(),
        action: @escaping @Sendable () async -> Void
    ) {
        super.init(edge: .top, role: .refresh, style: style, options: options, action: action)
    }
}
