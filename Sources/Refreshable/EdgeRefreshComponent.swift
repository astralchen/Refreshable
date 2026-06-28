import UIKit

/// 按边缘和语义角色驱动的刷新组件。
@MainActor
class EdgeRefreshComponent: RefreshComponent {

    let edge: RefreshableEdge
    let role: RefreshableRole

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
        refreshView.frame = frame(in: scrollView)
        refreshView.autoresizingMask = autoresizingMask(in: scrollView)
        refreshView.alpha = 0
        scrollView.addSubview(refreshView)
        style.update(state: .idle, progress: 0)
    }

    override func scrollViewContentSizeDidChange(contentSize: CGSize) {
        guard let scrollView else { return }
        style.view.frame = frame(in: scrollView, contentSize: contentSize)
    }

    override func scrollViewDidScroll(contentOffset: CGPoint) {
        guard isEnabled else { return }
        guard let scrollView else { return }
        guard role != .loadMore || state != .noMoreData else { return }

        if role == .loadMore && !options.allowsLoadMoreWhenContentFits {
            guard contentLength(in: scrollView) > viewportLength(in: scrollView) else { return }
        }

        let distance = pullDistance(in: scrollView, contentOffset: contentOffset)

        switch state {
        case .idle, .pulling:
            guard scrollView.isDragging, distance > 0 else { return }
            let progress = min(distance / triggerThreshold, 1.0)
            if distance >= triggerThreshold {
                setState(.triggered)
            } else {
                setState(.pulling(progress))
            }

        case .triggered:
            guard scrollView.isDragging, distance < triggerThreshold else { return }
            if distance > 0 {
                setState(.pulling(min(distance / triggerThreshold, 1.0)))
            } else {
                setState(.idle)
            }

        case .refreshing, .ending, .noMoreData:
            break
        }
    }

    override func scrollViewDidEndDragging() {
        if state == .triggered {
            trigger()
        }
    }

    override func stateDidChange(from oldState: RefreshState, to newState: RefreshState) {
        guard let scrollView else { return }
        guard newState == .refreshing else { return }

        UIView.animate(withDuration: options.animationDuration) {
            self.applyRefreshingInset(to: scrollView)
        }
    }

    override func resetInset(for scrollView: UIScrollView) {
        let physicalEdge = edge.physicalEdge(in: scrollView)
        var inset = scrollView.contentInset
        inset.setValue(originalInset.value(for: physicalEdge), for: physicalEdge)
        scrollView.contentInset = inset
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

        if state.isRefreshing {
            if let scrollView {
                UIView.animate(withDuration: options.animationDuration) {
                    self.resetInset(for: scrollView)
                }
            }
            setState(.noMoreData)
        } else {
            setState(.noMoreData)
        }
    }

    func resetNoMoreData() {
        guard role == .loadMore else { return }
        guard state == .noMoreData else { return }
        setState(.idle)
    }

    // MARK: - Geometry

    private var displayExtent: CGFloat {
        let rawValue = style.extent
        guard rawValue.isFinite, rawValue > 0 else { return triggerThreshold }
        return rawValue
    }

    private func frame(in scrollView: UIScrollView, contentSize: CGSize? = nil) -> CGRect {
        let extent = displayExtent
        let contentSize = contentSize ?? scrollView.contentSize

        switch edge.physicalEdge(in: scrollView) {
        case .top:
            return CGRect(x: 0, y: -extent, width: scrollView.bounds.width, height: extent)
        case .bottom:
            return CGRect(x: 0, y: contentSize.height, width: scrollView.bounds.width, height: extent)
        case .left:
            return CGRect(x: -extent, y: 0, width: extent, height: scrollView.bounds.height)
        case .right:
            return CGRect(x: contentSize.width, y: 0, width: extent, height: scrollView.bounds.height)
        }
    }

    private func autoresizingMask(in scrollView: UIScrollView) -> UIView.AutoresizingMask {
        switch edge.physicalEdge(in: scrollView).axis {
        case .vertical:
            [.flexibleWidth]
        case .horizontal:
            [.flexibleHeight]
        }
    }

    private func pullDistance(in scrollView: UIScrollView, contentOffset: CGPoint) -> CGFloat {
        switch edge.physicalEdge(in: scrollView) {
        case .top:
            let offset = contentOffset.y + originalInset.top
            return max(-offset, 0)
        case .bottom:
            let offset = contentOffset.y + scrollView.bounds.height - scrollView.contentSize.height - originalInset.bottom
            return max(offset, 0)
        case .left:
            let offset = contentOffset.x + originalInset.left
            return max(-offset, 0)
        case .right:
            let offset = contentOffset.x + scrollView.bounds.width - scrollView.contentSize.width - originalInset.right
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
        switch edge.physicalEdge(in: scrollView).axis {
        case .vertical:
            scrollView.bounds.height
        case .horizontal:
            scrollView.bounds.width
        }
    }

    private func beginAction() {
        guard isEnabled else { return }
        guard !state.isRefreshing else { return }
        guard state != .ending else { return }
        guard let scrollView else { return }

        captureOriginalInset()
        setState(.refreshing)

        UIView.animate(withDuration: options.animationDuration) {
            self.applyRefreshingInset(to: scrollView)
            self.adjustContentOffsetForStartEdgeIfNeeded(in: scrollView)
        }

        startActionTask()
    }

    private func applyRefreshingInset(to scrollView: UIScrollView) {
        let physicalEdge = edge.physicalEdge(in: scrollView)
        var inset = scrollView.contentInset
        inset.setValue(originalInset.value(for: physicalEdge) + triggerThreshold, for: physicalEdge)
        scrollView.contentInset = inset
    }

    private func adjustContentOffsetForStartEdgeIfNeeded(in scrollView: UIScrollView) {
        switch edge.physicalEdge(in: scrollView) {
        case .top:
            scrollView.contentOffset.y = -originalInset.top - triggerThreshold
        case .left:
            scrollView.contentOffset.x = -originalInset.left - triggerThreshold
        case .bottom, .right:
            break
        }
    }
}
