import UIKit

/// 持有单个 edge session 的 UIKit 展示状态。
@MainActor
final class EdgePresentationDriver {
    let hostView = RefreshHostView()
    var insetCoordinator: RefreshableInsetCoordinator?
    private(set) var contentOffsetMutationDepth = 0
    var isApplyingContentOffset: Bool { contentOffsetMutationDepth > 0 }
    var isApplyingInsetEffect = false
    var maintainsLockedOverlayBoundary = false
    var maintainsContentInsetRefreshBoundary = false
    var preservesContentOffsetAcrossInsetChanges = false

    init(insetCoordinator: RefreshableInsetCoordinator?) {
        self.insetCoordinator = insetCoordinator
    }

    /// UIScrollView 的 offset KVO 会同步重入；使用嵌套深度保证内部写入作用域不会被提前解除。
    func withContentOffsetMutation(_ mutation: () -> Void) {
        contentOffsetMutationDepth += 1
        defer { contentOffsetMutationDepth -= 1 }
        mutation()
    }

    func reset(owner: AnyObject) {
        maintainsLockedOverlayBoundary = false
        maintainsContentInsetRefreshBoundary = false
        preservesContentOffsetAcrossInsetChanges = false
        insetCoordinator?.removeContribution(owner: owner)
        insetCoordinator = nil
        hostView.onEnvironmentChange = nil
        hostView.removeFromSuperview()
    }
}
