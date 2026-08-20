import UIKit

/// Owns the mutable UIKit presentation state for one edge session.
@MainActor
final class EdgePresentationDriver {
    let hostView = RefreshHostView()
    var insetCoordinator: RefreshableInsetCoordinator?
    var isLockingOverlayContentOffset = false
    var isApplyingInsetEffect = false
    var maintainsLockedOverlayBoundary = false
    var maintainsContentInsetRefreshBoundary = false
    var preservesContentOffsetAcrossInsetChanges = false

    init(insetCoordinator: RefreshableInsetCoordinator?) {
        self.insetCoordinator = insetCoordinator
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
