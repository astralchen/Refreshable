import UIKit

/// 上拉加载组件。
@MainActor
final class FooterRefreshComponent: EdgeRefreshComponent {

    init(
        style: any RefreshableStyle,
        options: RefreshableOptions = RefreshableOptions(),
        action: @escaping @Sendable () async -> Void
    ) {
        super.init(edge: .bottom, role: .loadMore, style: style, options: options, action: action)
    }
}
