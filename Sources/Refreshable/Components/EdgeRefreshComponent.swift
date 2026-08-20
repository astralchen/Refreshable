import UIKit

/// 按边缘和语义角色驱动的刷新组件。
@MainActor
final class EdgeRefreshComponent: NSObject, RefreshComponentEffects {

    let edge: RefreshableEdge
    let role: RefreshableRole
    private var runtime: RefreshComponent!
    private let presentationDriver: EdgePresentationDriver
    private var insetCoordinator: RefreshableInsetCoordinator? {
        get { presentationDriver.insetCoordinator }
        set { presentationDriver.insetCoordinator = newValue }
    }
    private var isLockingOverlayContentOffset: Bool {
        get { presentationDriver.isLockingOverlayContentOffset }
        set { presentationDriver.isLockingOverlayContentOffset = newValue }
    }
    private var isApplyingInsetEffect: Bool {
        get { presentationDriver.isApplyingInsetEffect }
        set { presentationDriver.isApplyingInsetEffect = newValue }
    }
    private var maintainsLockedOverlayBoundary: Bool {
        get { presentationDriver.maintainsLockedOverlayBoundary }
        set { presentationDriver.maintainsLockedOverlayBoundary = newValue }
    }
    private var maintainsContentInsetRefreshBoundary: Bool {
        get { presentationDriver.maintainsContentInsetRefreshBoundary }
        set { presentationDriver.maintainsContentInsetRefreshBoundary = newValue }
    }
    private var preservesContentOffsetAcrossInsetChanges: Bool {
        get { presentationDriver.preservesContentOffsetAcrossInsetChanges }
        set { presentationDriver.preservesContentOffsetAcrossInsetChanges = newValue }
    }
    private var refreshHostView: RefreshHostView { presentationDriver.hostView }

    weak var scrollView: UIScrollView? {
        get { runtime.scrollView }
        set { runtime.scrollView = newValue }
    }
    var renderer: any RefreshableStyleRenderer { runtime.renderer }
    var style: any RefreshableStyle { runtime.style }
    var options: RefreshableOptions { runtime.options }
    var resolvedOptions: ResolvedRefreshableOptions { runtime.resolvedOptions }
    var action: (@Sendable () async -> Void)? {
        get { runtime.action }
        set { runtime.action = newValue }
    }
    var triggerThreshold: CGFloat { runtime.triggerThreshold }
    var styleExtent: CGFloat { runtime.styleExtent }
    var state: RefreshState { runtime.state }
    var isEnabled: Bool { runtime.isEnabled }

    func dispatch(_ event: RefreshEvent) { runtime.dispatch(event) }
    func receive(_ snapshot: RefreshableScrollSnapshot) { runtime.receive(snapshot) }
    func trigger() { runtime.trigger() }
    func endAction() { runtime.endAction() }
    func setEnabled(_ enabled: Bool) { runtime.setEnabled(enabled) }
    func prepareForRemoval() { runtime.prepareForRemoval() }
    func setState(_ state: RefreshState) { runtime.setState(state) }

    init(
        edge: RefreshableEdge,
        role: RefreshableRole,
        style: any RefreshableStyle,
        options: RefreshableOptions = RefreshableOptions(),
        usesExternalObservation: Bool = false,
        insetCoordinator: RefreshableInsetCoordinator? = nil,
        action: @escaping @Sendable () async -> Void
    ) {
        self.edge = edge
        self.role = role
        presentationDriver = EdgePresentationDriver(insetCoordinator: insetCoordinator)
        super.init()
        runtime = RefreshComponent(
            role: role,
            style: style,
            options: options,
            usesExternalObservation: usesExternalObservation,
            action: action
        )
        runtime.effects = self
    }

    var installedView: UIView {
        refreshHostView
    }

    var visibilityView: UIView { renderer.view }

    func removeInstalledView() {
        renderer.view.removeFromSuperview()
        presentationDriver.reset(owner: self)
    }

    func installView(in scrollView: UIScrollView) {
        if insetCoordinator == nil {
            insetCoordinator = RefreshableInsetCoordinator.coordinator(for: scrollView)
        }
        refreshHostView.onEnvironmentChange = { [weak self, weak scrollView] in
            guard let self, let scrollView else { return }
            self.updateForEnvironmentChange(in: scrollView)
        }
        refreshHostView.clipsToBounds = false
        refreshHostView.isUserInteractionEnabled = false

        let refreshView = renderer.view
        refreshView.isUserInteractionEnabled = false
        updateRefreshViewFrame(in: scrollView)
        refreshView.alpha = 0
        if refreshView.superview !== refreshHostView {
            refreshHostView.addSubview(refreshView)
        }
        if refreshHostView.superview !== scrollView {
            scrollView.addSubview(refreshHostView)
        }
    }

    func scrollViewContentSizeDidChange(contentSize: CGSize) {
        guard let scrollView else { return }
        updateRefreshViewFrame(in: scrollView, contentSize: contentSize)
        restoreMaintainedRefreshBoundaryIfNeeded(in: scrollView)
    }

    func scrollViewBoundsDidChange(bounds: CGRect) {
        guard let scrollView else { return }
        updateRefreshViewFrame(in: scrollView)
        restoreMaintainedRefreshBoundaryIfNeeded(in: scrollView)
    }

    func scrollViewContentInsetDidChange(contentInset: UIEdgeInsets) {
        guard let scrollView else { return }
        updateRefreshViewFrame(in: scrollView)
        restoreMaintainedRefreshBoundaryIfNeeded(in: scrollView)
    }

    func scrollViewEnvironmentDidChange() {
        guard let scrollView else { return }
        updateForEnvironmentChange(in: scrollView)
    }

    func scrollViewDidScroll(contentOffset: CGPoint) {
        guard isEnabled else { return }
        guard let scrollView else { return }

        if isApplyingInsetEffect {
            updatePresentationFrameForScrolling(in: scrollView)
            return
        }

        if isLockingOverlayContentOffset {
            updatePresentationFrameForScrolling(in: scrollView)
            return
        }

        if role == .loadMore && state == .noMoreData {
            let distance = pullDistance(in: scrollView, contentOffset: contentOffset)
            lockOverlayContentOffsetIfNeeded(in: scrollView, distance: distance)
            updatePresentationFrameForScrolling(in: scrollView)
            return
        }

        if role == .loadMore && !resolvedOptions.allowsLoadMoreWhenContentFits {
            guard contentLength(in: scrollView) > viewportLength(in: scrollView) else { return }
        }

        if triggerAutomaticallyIfNeeded(in: scrollView, contentOffset: contentOffset) {
            return
        }

        let distance = pullDistance(in: scrollView, contentOffset: contentOffset)
        lockOverlayContentOffsetIfNeeded(in: scrollView, distance: distance)
        updatePresentationFrameForScrolling(in: scrollView)

        let rawProgress = distance / triggerThreshold

        guard scrollView.isDragging else { return }
        switch state {
        case .idle, .pulling, .triggered:
            break
        case .active, .ending, .noMoreData:
            return
        }
        dispatch(.dragChanged(progress: rawProgress))
    }

    func scrollViewDidEndDragging() {
        dispatch(.panEnded)
    }

    func scrollViewDidCancelDragging() {
        dispatch(.panCancelled)
    }

    func setInsetVisible(reveal: Bool) {
        guard resolvedOptions.presentation.usesContentInset else {
            establishLockedOverlayBoundaryIfNeeded(reveal: reveal)
            return
        }
        guard let scrollView, let insetCoordinator else { return }
        updateRefreshViewFrame(in: scrollView)
        if reveal, role == .refresh, state == .active {
            maintainsContentInsetRefreshBoundary = true
        }
        preservesContentOffsetAcrossInsetChanges = !reveal
        let preservedContentOffset = scrollView.contentOffset
        let shouldReserveInset = shouldReserveInsetForCurrentState
        let changes = {
            self.isApplyingInsetEffect = true
            defer { self.isApplyingInsetEffect = false }

            guard shouldReserveInset else {
                insetCoordinator.removeContribution(owner: self)
                if reveal {
                    scrollView.contentOffset = self.lockedOverlayContentOffset(in: scrollView)
                } else {
                    self.applyMaintainedContentOffset(preservedContentOffset, in: scrollView)
                }
                return
            }

            insetCoordinator.setContribution(
                owner: self,
                edge: self.edge.physicalEdge(in: scrollView),
                amount: self.refreshingInsetExtent
            )
            if reveal {
                self.adjustContentOffsetForStartEdgeIfNeeded(in: scrollView)
            } else {
                self.applyMaintainedContentOffset(preservedContentOffset, in: scrollView)
            }
        }
        if resolvedOptions.animationDuration > 0 {
            UIView.animate(withDuration: resolvedOptions.animationDuration, animations: changes)
        } else {
            changes()
        }
    }

    func removeInset(animated: Bool, completion: @escaping @MainActor () -> Void) {
        guard resolvedOptions.presentation.usesContentInset, let insetCoordinator else {
            if let scrollView {
                restoreMaintainedRefreshBoundaryIfNeeded(in: scrollView)
            }
            maintainsLockedOverlayBoundary = false
            completion()
            return
        }

        let shouldRestoreRefreshBoundary = maintainsContentInsetRefreshBoundary
        let shouldPreserveContentOffset = preservesContentOffsetAcrossInsetChanges
        let preservedContentOffset = scrollView?.contentOffset
        let changes = {
            self.isApplyingInsetEffect = true
            defer { self.isApplyingInsetEffect = false }
            insetCoordinator.removeContribution(owner: self)
            if shouldRestoreRefreshBoundary, let scrollView = self.scrollView {
                self.applyMaintainedContentOffset(
                    self.lockedOverlayContentOffset(in: scrollView),
                    in: scrollView
                )
            } else if shouldPreserveContentOffset,
                      let scrollView = self.scrollView,
                      let preservedContentOffset {
                self.applyMaintainedContentOffset(preservedContentOffset, in: scrollView)
            }
        }
        guard animated, resolvedOptions.animationDuration > 0 else {
            changes()
            maintainsContentInsetRefreshBoundary = false
            preservesContentOffsetAcrossInsetChanges = false
            completion()
            return
        }
        UIView.animate(
            withDuration: resolvedOptions.animationDuration,
            animations: changes,
            completion: { _ in
                self.maintainsContentInsetRefreshBoundary = false
                self.preservesContentOffsetAcrossInsetChanges = false
                completion()
            }
        )
    }

    // MARK: - 手动触发

    func beginRefreshing() {
        dispatch(.begin)
    }

    func beginLoadingMore() {
        dispatch(.begin)
    }

    // MARK: - 没有更多数据

    func markNoMoreData() {
        guard role == .loadMore else { return }
        let isAtBoundary = scrollView.map(isAtTargetBoundary(in:)) ?? false
        dispatch(.markNoMoreData(revealAtBoundary: isAtBoundary))
    }

    func resetNoMoreData() {
        guard role == .loadMore else { return }
        dispatch(.resetNoMoreData)
    }

    // MARK: - 几何布局

    private var displayExtent: CGFloat {
        styleExtent
    }

    private var resolvedPlacement: RefreshablePlacement {
        resolvedOptions.placement
    }

    private var sanitizedContentSpacing: CGFloat {
        let rawValue = resolvedPlacement.contentSpacing
        guard rawValue.isFinite else { return 0 }
        return max(rawValue, 0)
    }

    private var sanitizedOuterSpacing: CGFloat {
        let rawValue = resolvedPlacement.outerSpacing
        guard rawValue.isFinite else { return 0 }
        return max(rawValue, 0)
    }

    private var sanitizedCrossAxisInset: CGFloat {
        let rawValue = resolvedPlacement.crossAxisInset
        guard rawValue.isFinite else { return 0 }
        return max(rawValue, 0)
    }

    private var reservedExtent: CGFloat {
        sanitizedOuterSpacing + displayExtent + sanitizedContentSpacing
    }

    private var shouldReserveInsetForCurrentState: Bool {
        guard state == .noMoreData else { return true }
        return (style as? any RefreshableNoMoreDataInsetProviding)?
            .reservesInsetForNoMoreData ?? true
    }

    private func frame(in scrollView: UIScrollView, contentSize: CGSize? = nil) -> CGRect {
        geometry(in: scrollView, contentSize: contentSize).hostFrame(
            presentation: resolvedOptions.presentation,
            overlayAnchor: resolvedOptions.overlayAnchor
        )
    }

    private func updateRefreshViewFrame(in scrollView: UIScrollView, contentSize: CGSize? = nil) {
        let physicalEdge = edge.physicalEdge(in: scrollView)
        refreshHostView.frame = frame(in: scrollView, contentSize: contentSize)
        refreshHostView.autoresizingMask = autoresizingMask(in: scrollView)

        let refreshView = renderer.view
        refreshView.frame = geometry(in: scrollView, contentSize: contentSize)
            .rendererFrame(in: refreshHostView.bounds)
        refreshView.autoresizingMask = visualAutoresizingMask(for: physicalEdge)
    }

    private func updateForEnvironmentChange(in scrollView: UIScrollView) {
        updateRefreshViewFrame(in: scrollView)
        restoreMaintainedRefreshBoundaryIfNeeded(in: scrollView)
        guard resolvedOptions.presentation.usesContentInset,
              let insetCoordinator,
              insetCoordinator.contribution(for: self) > 0
        else {
            return
        }
        insetCoordinator.setContribution(
            owner: self,
            edge: edge.physicalEdge(in: scrollView),
            amount: refreshingInsetExtent
        )
    }

    private func autoresizingMask(in scrollView: UIScrollView) -> UIView.AutoresizingMask {
        switch edge.physicalEdge(in: scrollView).axis {
        case .vertical:
            [.flexibleWidth]
        case .horizontal:
            [.flexibleWidth, .flexibleHeight]
        }
    }

    private func visualAutoresizingMask(for physicalEdge: RefreshablePhysicalEdge) -> UIView.AutoresizingMask {
        switch physicalEdge {
        case .top, .bottom:
            [.flexibleWidth]
        case .left:
            [.flexibleHeight]
        case .right:
            [.flexibleLeftMargin, .flexibleHeight]
        }
    }

    private func pullDistance(in scrollView: UIScrollView, contentOffset: CGPoint) -> CGFloat {
        let physicalEdge = edge.physicalEdge(in: scrollView)
        let contentOffsetDistance = geometry(
            in: scrollView,
            contentOffset: contentOffset
        ).pullDistance

        guard shouldUseLockedOverlayGestureDistance(
            in: scrollView,
            contentOffset: contentOffset,
            contentOffsetDistance: contentOffsetDistance,
            physicalEdge: physicalEdge
        ) else {
            return contentOffsetDistance
        }

        return max(contentOffsetDistance, lockedOverlayGestureDistance(in: scrollView, physicalEdge: physicalEdge))
    }

    private func shouldUseLockedOverlayGestureDistance(
        in scrollView: UIScrollView,
        contentOffset: CGPoint,
        contentOffsetDistance: CGFloat,
        physicalEdge: RefreshablePhysicalEdge
    ) -> Bool {
        guard resolvedOptions.presentation.locksContentOffset else { return false }
        guard scrollView.isDragging else { return false }
        guard contentOffsetDistance > 0 || isAtLockedOverlayBoundary(
            in: scrollView,
            contentOffset: contentOffset,
            physicalEdge: physicalEdge
        ) else { return false }

        return true
    }

    private func isAtLockedOverlayBoundary(
        in scrollView: UIScrollView,
        contentOffset: CGPoint,
        physicalEdge: RefreshablePhysicalEdge
    ) -> Bool {
        let lockedOffset = lockedOverlayContentOffset(in: scrollView)
        let tolerance: CGFloat = 0.5

        switch physicalEdge {
        case .top:
            return contentOffset.y <= lockedOffset.y + tolerance
        case .bottom:
            return contentOffset.y >= lockedOffset.y - tolerance
        case .left:
            return contentOffset.x <= lockedOffset.x + tolerance
        case .right:
            return contentOffset.x >= lockedOffset.x - tolerance
        }
    }

    private func lockedOverlayGestureDistance(
        in scrollView: UIScrollView,
        physicalEdge: RefreshablePhysicalEdge
    ) -> CGFloat {
        let translation = scrollView.panGestureRecognizer.translation(in: scrollView)

        switch physicalEdge {
        case .top:
            return max(translation.y, 0)
        case .bottom:
            return max(-translation.y, 0)
        case .left:
            return max(translation.x, 0)
        case .right:
            return max(-translation.x, 0)
        }
    }

    private func triggerAutomaticallyIfNeeded(in scrollView: UIScrollView, contentOffset: CGPoint) -> Bool {
        guard let triggerDistance = automaticTriggerDistance(in: scrollView) else { return false }
        guard distanceToAutomaticTriggerEdge(in: scrollView, contentOffset: contentOffset) <= triggerDistance else {
            return false
        }

        dispatch(.automaticTrigger)
        return state.isActive
    }

    private func automaticTriggerDistance(in scrollView: UIScrollView) -> CGFloat? {
        guard let configuredDistance = resolvedOptions.automaticTriggerDistance else { return nil }

        let rawValue: CGFloat
        switch configuredDistance {
        case .default:
            guard role == .loadMore, edge.physicalEdge(in: scrollView) == .bottom else { return nil }
            rawValue = 0
        case .distance(let value):
            rawValue = value
        }

        guard rawValue.isFinite, rawValue >= 0 else { return nil }
        return rawValue
    }

    private func distanceToAutomaticTriggerEdge(in scrollView: UIScrollView, contentOffset: CGPoint) -> CGFloat {
        geometry(in: scrollView, contentOffset: contentOffset).distanceToBoundary
    }

    private func isAtTargetBoundary(in scrollView: UIScrollView) -> Bool {
        distanceToAutomaticTriggerEdge(
            in: scrollView,
            contentOffset: scrollView.contentOffset
        ) <= 0.5
    }

    private func contentLength(in scrollView: UIScrollView) -> CGFloat {
        switch edge.physicalEdge(in: scrollView).axis {
        case .vertical:
            scrollView.contentSize.height
        case .horizontal:
            scrollView.contentSize.width
        }
    }

    private func viewportLength(in scrollView: UIScrollView) -> CGFloat {
        let adjustedInset = scrollView.adjustedContentInset

        let rawLength = switch edge.physicalEdge(in: scrollView).axis {
        case .vertical:
            scrollView.bounds.height
        case .horizontal:
            scrollView.bounds.width
        }

        let insetLength = switch edge.physicalEdge(in: scrollView).axis {
        case .vertical:
            adjustedInset.top + adjustedInset.bottom
        case .horizontal:
            adjustedInset.left + adjustedInset.right
        }

        return max(rawLength - insetLength, 0)
    }

    private func updatePresentationFrameForScrolling(in scrollView: UIScrollView) {
        if resolvedOptions.presentation.usesContentInset {
            var frame = refreshHostView.frame
            switch edge.physicalEdge(in: scrollView).axis {
            case .vertical:
                frame.origin.x = scrollView.bounds.minX
            case .horizontal:
                frame.origin.y = scrollView.bounds.minY
            }
            refreshHostView.frame = frame
        } else {
            updateRefreshViewFrame(in: scrollView)
        }
    }

    private func lockOverlayContentOffsetIfNeeded(in scrollView: UIScrollView, distance: CGFloat) {
        guard resolvedOptions.presentation.locksContentOffset else { return }
        guard scrollView.isDragging, distance > 0 else { return }

        let lockedOffset = lockedOverlayContentOffset(in: scrollView)
        guard lockedOffset != scrollView.contentOffset else { return }

        isLockingOverlayContentOffset = true
        scrollView.contentOffset = lockedOffset
        isLockingOverlayContentOffset = false
    }

    private func establishLockedOverlayBoundaryIfNeeded(reveal: Bool) {
        guard reveal, state == .active else { return }
        guard resolvedOptions.presentation.locksContentOffset else { return }
        guard let scrollView, isAtTargetBoundary(in: scrollView) else { return }

        maintainsLockedOverlayBoundary = true
        restoreMaintainedRefreshBoundaryIfNeeded(in: scrollView)
    }

    private func restoreMaintainedRefreshBoundaryIfNeeded(in scrollView: UIScrollView) {
        let maintainedOffset: CGPoint
        if maintainsLockedOverlayBoundary {
            maintainedOffset = lockedOverlayContentOffset(in: scrollView)
        } else if maintainsContentInsetRefreshBoundary {
            switch state {
            case .active:
                maintainedOffset = geometry(in: scrollView).revealContentOffset
            case .idle, .pulling, .triggered, .ending, .noMoreData:
                maintainedOffset = lockedOverlayContentOffset(in: scrollView)
            }
        } else {
            return
        }

        applyMaintainedContentOffset(maintainedOffset, in: scrollView)
    }

    private func applyMaintainedContentOffset(_ contentOffset: CGPoint, in scrollView: UIScrollView) {
        guard contentOffset != scrollView.contentOffset else { return }
        isLockingOverlayContentOffset = true
        scrollView.contentOffset = contentOffset
        isLockingOverlayContentOffset = false
    }

    private func lockedOverlayContentOffset(in scrollView: UIScrollView) -> CGPoint {
        var lockedOffset = scrollView.contentOffset
        let adjustedOriginalInset = geometry(in: scrollView).adjustedBaselineInset

        switch edge.physicalEdge(in: scrollView) {
        case .top:
            lockedOffset.y = -adjustedOriginalInset.top
        case .bottom:
            let minimumY = -adjustedOriginalInset.top
            lockedOffset.y = max(
                scrollView.contentSize.height - scrollView.bounds.height + adjustedOriginalInset.bottom,
                minimumY
            )
        case .left:
            lockedOffset.x = -adjustedOriginalInset.left
        case .right:
            let minimumX = -adjustedOriginalInset.left
            lockedOffset.x = max(
                scrollView.contentSize.width - scrollView.bounds.width + adjustedOriginalInset.right,
                minimumX
            )
        }

        return lockedOffset
    }

    private var refreshingInsetExtent: CGFloat {
        reservedExtent
    }

    private func adjustContentOffsetForStartEdgeIfNeeded(in scrollView: UIScrollView) {
        scrollView.contentOffset = geometry(in: scrollView).revealContentOffset
    }

    private func geometry(
        in scrollView: UIScrollView,
        contentSize: CGSize? = nil,
        contentOffset: CGPoint? = nil
    ) -> EdgeRefreshGeometry {
        EdgeRefreshGeometry(
            physicalEdge: edge.physicalEdge(in: scrollView),
            bounds: scrollView.bounds,
            contentSize: contentSize ?? scrollView.contentSize,
            contentOffset: contentOffset ?? scrollView.contentOffset,
            baselineInset: insetCoordinator?.baselineInset ?? scrollView.contentInset,
            boundaryAdjustment: contentBoundaryInsetAdjustment(in: scrollView),
            automaticAdjustment: automaticInsetAdjustment(in: scrollView),
            safeAreaInsets: scrollView.safeAreaInsets,
            displayExtent: displayExtent,
            placement: resolvedPlacement
        )
    }

    private func adjustedContentInsetDelta(in scrollView: UIScrollView) -> UIEdgeInsets {
        UIEdgeInsets(
            top: scrollView.adjustedContentInset.top - scrollView.contentInset.top,
            left: scrollView.adjustedContentInset.left - scrollView.contentInset.left,
            bottom: scrollView.adjustedContentInset.bottom - scrollView.contentInset.bottom,
            right: scrollView.adjustedContentInset.right - scrollView.contentInset.right
        )
    }

    private func contentBoundaryInsetAdjustment(in scrollView: UIScrollView) -> UIEdgeInsets {
        let adjustedDelta = adjustedContentInsetDelta(in: scrollView)
        guard edge.physicalEdge(in: scrollView).axis == .horizontal else { return adjustedDelta }

        let safeAreaInsets = scrollView.safeAreaInsets
        return UIEdgeInsets(
            top: adjustedDelta.top,
            left: max(adjustedDelta.left, safeAreaInsets.left),
            bottom: adjustedDelta.bottom,
            right: max(adjustedDelta.right, safeAreaInsets.right)
        )
    }

    private func automaticInsetAdjustment(in scrollView: UIScrollView) -> UIEdgeInsets {
        let adjustedDelta = adjustedContentInsetDelta(in: scrollView)
        let safeAreaInsets = scrollView.safeAreaInsets
        return UIEdgeInsets(
            top: max(adjustedDelta.top, safeAreaInsets.top),
            left: max(adjustedDelta.left, safeAreaInsets.left),
            bottom: max(adjustedDelta.bottom, safeAreaInsets.bottom),
            right: max(adjustedDelta.right, safeAreaInsets.right)
        )
    }

}
