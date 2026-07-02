import UIKit

/// 按边缘和语义角色驱动的刷新组件。
@MainActor
class EdgeRefreshComponent: RefreshComponent {

    let edge: RefreshableEdge
    let role: RefreshableRole
    private var activeInsetEdge: RefreshablePhysicalEdge?
    private var isLockingOverlayContentOffset = false

    init(
        edge: RefreshableEdge,
        role: RefreshableRole,
        style: any RefreshableStyle,
        options: RefreshableOptions = RefreshableOptions(),
        action: @escaping @Sendable () async -> Void
    ) {
        self.edge = edge
        self.role = role
        super.init(style: style, options: options, action: action)
    }

    override func installView(in scrollView: UIScrollView) {
        let refreshView = style.view
        updateRefreshViewFrame(in: scrollView)
        refreshView.autoresizingMask = autoresizingMask(in: scrollView)
        refreshView.alpha = 0
        scrollView.addSubview(refreshView)
        style.update(state: .idle, progress: 0)
    }

    override func scrollViewContentSizeDidChange(contentSize: CGSize) {
        guard let scrollView else { return }
        updateRefreshViewFrame(in: scrollView, contentSize: contentSize)
    }

    override func scrollViewDidScroll(contentOffset: CGPoint) {
        guard isEnabled else { return }
        guard let scrollView else { return }
        guard role != .loadMore || state != .noMoreData else { return }

        if isLockingOverlayContentOffset {
            updateOverlayFrameIfNeeded(in: scrollView)
            return
        }

        if role == .loadMore && !options.allowsLoadMoreWhenContentFits {
            guard contentLength(in: scrollView) > viewportLength(in: scrollView) else { return }
        }

        let distance = pullDistance(in: scrollView, contentOffset: contentOffset)
        lockOverlayContentOffsetIfNeeded(in: scrollView, distance: distance)
        updateOverlayFrameIfNeeded(in: scrollView)

        let rawProgress = distance / triggerThreshold

        switch state {
        case .idle, .pulling:
            guard scrollView.isDragging, distance > 0 else { return }
            let progress = min(rawProgress, 1.0)
            if distance >= triggerThreshold {
                setState(.triggered)
                updateTriggeredPullProgress(rawProgress)
            } else {
                setState(.pulling(progress))
            }

        case .triggered:
            guard scrollView.isDragging else { return }
            guard distance < triggerThreshold else {
                updateTriggeredPullProgress(rawProgress)
                return
            }
            if distance > 0 {
                setState(.pulling(min(distance / triggerThreshold, 1.0)))
            } else {
                setState(.idle)
            }

        case .refreshing, .ending, .noMoreData:
            break
        }
    }

    private func updateTriggeredPullProgress(_ progress: CGFloat) {
        style.update(state: .triggered, progress: min(max(progress, 1), 2))
    }

    override func scrollViewDidEndDragging() {
        switch state {
        case .triggered:
            trigger()
        case .pulling:
            setState(.idle)
        case .idle, .refreshing, .ending, .noMoreData:
            break
        }
    }

    override func stateDidChange(from oldState: RefreshState, to newState: RefreshState) {
        guard let scrollView else { return }
        updateRefreshViewFrame(in: scrollView)
        guard newState == .refreshing else { return }
        guard options.presentation.usesContentInset else { return }

        UIView.animate(withDuration: options.animationDuration) {
            self.applyRefreshingInset(to: scrollView)
        }
    }

    override func resetInset(for scrollView: UIScrollView) {
        let physicalEdge: RefreshablePhysicalEdge
        if let activeInsetEdge {
            physicalEdge = activeInsetEdge
        } else {
            guard options.presentation.usesContentInset else { return }
            physicalEdge = edge.physicalEdge(in: scrollView)
        }

        var inset = scrollView.contentInset
        inset.setValue(originalInset.value(for: physicalEdge), for: physicalEdge)
        scrollView.contentInset = inset
        activeInsetEdge = nil
    }

    // MARK: - Manual Trigger

    func beginRefreshing() {
        beginAction()
    }

    func beginLoadingMore() {
        guard state != .noMoreData else { return }
        beginAction()
    }

    // MARK: - No More Data

    func setNoMoreData() {
        guard role == .loadMore else { return }
        guard state != .noMoreData else { return }

        if options.presentation.usesContentInset, let scrollView {
            if !state.isRefreshing {
                captureOriginalInset()
            }
            UIView.animate(withDuration: options.animationDuration) {
                self.applyRefreshingInset(to: scrollView)
            }
        }

        setState(.noMoreData)
    }

    func resetNoMoreData() {
        guard role == .loadMore else { return }
        guard state == .noMoreData else { return }

        if options.presentation.usesContentInset, let scrollView {
            UIView.animate(withDuration: options.animationDuration) {
                self.resetInset(for: scrollView)
            }
        }

        setState(.idle)
    }

    // MARK: - Geometry

    private var displayExtent: CGFloat {
        let rawValue = style.extent
        guard rawValue.isFinite, rawValue > 0 else { return triggerThreshold }
        return rawValue
    }

    private func frame(in scrollView: UIScrollView, contentSize: CGSize? = nil) -> CGRect {
        switch options.presentation {
        case .contentInset:
            contentInsetFrame(in: scrollView, contentSize: contentSize)
        case .overlay(let spacing, _):
            overlayFrame(in: scrollView, spacing: spacing)
        }
    }

    private func updateRefreshViewFrame(in scrollView: UIScrollView, contentSize: CGSize? = nil) {
        let refreshView = style.view
        refreshView.frame = frame(in: scrollView, contentSize: contentSize)
        updateRefreshViewLayoutMargins(refreshView, in: scrollView)
    }

    private func updateRefreshViewLayoutMargins(_ refreshView: UIView, in scrollView: UIScrollView) {
        guard options.presentation.usesContentInset else {
            refreshView.layoutMargins = .zero
            return
        }
        guard edge.physicalEdge(in: scrollView).axis == .horizontal else {
            refreshView.layoutMargins = .zero
            return
        }

        let visualWidth = min(displayExtent, refreshView.bounds.width)
        let insetWidth = max(refreshView.bounds.width - visualWidth, 0)
        switch edge.physicalEdge(in: scrollView) {
        case .left:
            refreshView.layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: insetWidth)
        case .right:
            refreshView.layoutMargins = UIEdgeInsets(top: 0, left: insetWidth, bottom: 0, right: 0)
        case .top, .bottom:
            refreshView.layoutMargins = .zero
        }
    }

    private func contentInsetFrame(in scrollView: UIScrollView, contentSize: CGSize? = nil) -> CGRect {
        let extent = displayExtent
        let contentSize = contentSize ?? scrollView.contentSize

        switch edge.physicalEdge(in: scrollView) {
        case .top:
            return CGRect(x: 0, y: -extent, width: scrollView.bounds.width, height: extent)
        case .bottom:
            return CGRect(x: 0, y: contentSize.height, width: scrollView.bounds.width, height: extent)
        case .left:
            return CGRect(
                x: -originalInset.left - extent,
                y: 0,
                width: horizontalViewportWidth(in: scrollView),
                height: scrollView.bounds.height
            )
        case .right:
            let adjustment = automaticInsetAdjustment(in: scrollView)
            return CGRect(
                x: contentSize.width
                    - scrollView.bounds.width
                    + originalInset.right
                    + adjustment.left
                    + adjustment.right
                    + extent,
                y: 0,
                width: horizontalViewportWidth(in: scrollView),
                height: scrollView.bounds.height
            )
        }
    }

    private func overlayFrame(in scrollView: UIScrollView, spacing: CGFloat) -> CGRect {
        let extent = displayExtent
        let visibleBounds = CGRect(origin: scrollView.contentOffset, size: scrollView.bounds.size)
        let safeAreaInsets = scrollView.safeAreaInsets

        switch edge.physicalEdge(in: scrollView) {
        case .top:
            return CGRect(
                x: visibleBounds.minX,
                y: visibleBounds.minY + safeAreaInsets.top + spacing,
                width: visibleBounds.width,
                height: extent
            )
        case .bottom:
            return CGRect(
                x: visibleBounds.minX,
                y: visibleBounds.maxY - safeAreaInsets.bottom - spacing - extent,
                width: visibleBounds.width,
                height: extent
            )
        case .left:
            return CGRect(
                x: visibleBounds.minX + safeAreaInsets.left + spacing,
                y: visibleBounds.minY,
                width: extent,
                height: visibleBounds.height
            )
        case .right:
            return CGRect(
                x: visibleBounds.maxX - safeAreaInsets.right - spacing - extent,
                y: visibleBounds.minY,
                width: extent,
                height: visibleBounds.height
            )
        }
    }

    private func autoresizingMask(in scrollView: UIScrollView) -> UIView.AutoresizingMask {
        switch edge.physicalEdge(in: scrollView).axis {
        case .vertical:
            [.flexibleWidth]
        case .horizontal:
            [.flexibleWidth, .flexibleHeight]
        }
    }

    private func pullDistance(in scrollView: UIScrollView, contentOffset: CGPoint) -> CGFloat {
        let adjustedOriginalInset = adjustedOriginalInset(in: scrollView)

        switch edge.physicalEdge(in: scrollView) {
        case .top:
            let offset = contentOffset.y + adjustedOriginalInset.top
            return max(-offset, 0)
        case .bottom:
            let offset = contentOffset.y
                + scrollView.bounds.height
                - scrollView.contentSize.height
                - adjustedOriginalInset.bottom
            return max(offset, 0)
        case .left:
            let offset = contentOffset.x + adjustedOriginalInset.left
            return max(-offset, 0)
        case .right:
            let offset = contentOffset.x
                + scrollView.bounds.width
                - scrollView.contentSize.width
                - adjustedOriginalInset.right
            return max(offset, 0)
        }
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

    private func updateOverlayFrameIfNeeded(in scrollView: UIScrollView) {
        guard !options.presentation.usesContentInset else { return }
        updateRefreshViewFrame(in: scrollView)
    }

    private func lockOverlayContentOffsetIfNeeded(in scrollView: UIScrollView, distance: CGFloat) {
        guard options.presentation.locksContentOffset else { return }
        guard scrollView.isDragging, distance > 0 else { return }

        let lockedOffset = lockedOverlayContentOffset(in: scrollView)
        guard lockedOffset != scrollView.contentOffset else { return }

        isLockingOverlayContentOffset = true
        scrollView.contentOffset = lockedOffset
        isLockingOverlayContentOffset = false
    }

    private func lockedOverlayContentOffset(in scrollView: UIScrollView) -> CGPoint {
        var lockedOffset = scrollView.contentOffset
        let adjustedOriginalInset = adjustedOriginalInset(in: scrollView)

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

    private func beginAction() {
        guard isEnabled else { return }
        guard !state.isRefreshing else { return }
        guard state != .ending else { return }
        guard let scrollView else { return }

        captureOriginalInset()
        setState(.refreshing)

        if options.presentation.usesContentInset {
            UIView.animate(withDuration: options.animationDuration) {
                self.applyRefreshingInset(to: scrollView)
                self.adjustContentOffsetForStartEdgeIfNeeded(in: scrollView)
            }
        }

        startActionTask()
    }

    private func applyRefreshingInset(to scrollView: UIScrollView) {
        let physicalEdge = edge.physicalEdge(in: scrollView)
        activeInsetEdge = physicalEdge
        var inset = scrollView.contentInset
        inset.setValue(originalInset.value(for: physicalEdge) + refreshingInsetExtent(in: scrollView), for: physicalEdge)
        scrollView.contentInset = inset
    }

    private func refreshingInsetExtent(in scrollView: UIScrollView) -> CGFloat {
        switch edge.physicalEdge(in: scrollView).axis {
        case .vertical:
            triggerThreshold
        case .horizontal:
            displayExtent
        }
    }

    private func adjustContentOffsetForStartEdgeIfNeeded(in scrollView: UIScrollView) {
        let adjustedOriginalInset = adjustedOriginalInset(in: scrollView)

        switch edge.physicalEdge(in: scrollView) {
        case .top:
            scrollView.contentOffset.y = -adjustedOriginalInset.top - triggerThreshold
        case .left:
            scrollView.contentOffset.x = -adjustedOriginalInset.left - displayExtent
        case .bottom:
            let minimumY = -adjustedOriginalInset.top
            scrollView.contentOffset.y = max(
                scrollView.contentSize.height
                    - scrollView.bounds.height
                    + adjustedOriginalInset.bottom
                    + triggerThreshold,
                minimumY
            )
        case .right:
            let minimumX = -adjustedOriginalInset.left
            scrollView.contentOffset.x = max(
                scrollView.contentSize.width
                    - scrollView.bounds.width
                    + adjustedOriginalInset.right
                    + displayExtent,
                minimumX
            )
        }
    }

    private func adjustedOriginalInset(in scrollView: UIScrollView) -> UIEdgeInsets {
        let adjustment = automaticInsetAdjustment(in: scrollView)
        return UIEdgeInsets(
            top: originalInset.top + adjustment.top,
            left: originalInset.left + adjustment.left,
            bottom: originalInset.bottom + adjustment.bottom,
            right: originalInset.right + adjustment.right
        )
    }

    private func automaticInsetAdjustment(in scrollView: UIScrollView) -> UIEdgeInsets {
        let adjustedDelta = UIEdgeInsets(
            top: scrollView.adjustedContentInset.top - scrollView.contentInset.top,
            left: scrollView.adjustedContentInset.left - scrollView.contentInset.left,
            bottom: scrollView.adjustedContentInset.bottom - scrollView.contentInset.bottom,
            right: scrollView.adjustedContentInset.right - scrollView.contentInset.right
        )
        let safeAreaInsets = scrollView.safeAreaInsets

        return UIEdgeInsets(
            top: max(adjustedDelta.top, safeAreaInsets.top),
            left: max(adjustedDelta.left, safeAreaInsets.left),
            bottom: max(adjustedDelta.bottom, safeAreaInsets.bottom),
            right: max(adjustedDelta.right, safeAreaInsets.right)
        )
    }

    private func horizontalViewportWidth(in scrollView: UIScrollView) -> CGFloat {
        let adjustment = automaticInsetAdjustment(in: scrollView)
        return max(scrollView.bounds.width - adjustment.left - adjustment.right, displayExtent)
    }
}
