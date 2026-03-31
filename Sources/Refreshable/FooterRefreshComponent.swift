import UIKit

/// 上拉加载组件
@MainActor
final class FooterRefreshComponent: RefreshComponent {

    private var threshold: CGFloat { style.height }

    override func installView(in scrollView: UIScrollView) {
        let sv = style.view
        sv.frame = CGRect(
            x: 0,
            y: scrollView.contentSize.height,
            width: scrollView.bounds.width,
            height: style.height
        )
        sv.autoresizingMask = [.flexibleWidth]
        sv.alpha = 0
        scrollView.addSubview(sv)
        style.update(state: .idle, progress: 0)
    }

    override func scrollViewContentSizeDidChange(contentSize: CGSize) {
        // footer 始终跟随 contentSize 底部
        style.view.frame.origin.y = contentSize.height
    }

    override func scrollViewDidScroll(contentOffset: CGPoint) {
        guard let scrollView else { return }

        let contentHeight = scrollView.contentSize.height
        let frameHeight = scrollView.bounds.height
        let adjustedBottom = originalInset.bottom

        // 内容不足一屏时不触发上拉
        guard contentHeight > frameHeight else { return }

        let bottomOffset = contentOffset.y + frameHeight - contentHeight - adjustedBottom

        switch state {
        case .idle, .pulling:
            if scrollView.isDragging && bottomOffset > 0 {
                let progress = min(bottomOffset / threshold, 1.0)
                if bottomOffset >= threshold {
                    setState(.triggered)
                } else {
                    setState(.pulling(progress))
                }
            }

        case .triggered:
            if scrollView.isDragging {
                if bottomOffset < threshold {
                    let progress = min(bottomOffset / threshold, 1.0)
                    setState(.pulling(progress))
                }
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

        if newState == .refreshing {
            UIView.animate(withDuration: 0.25) {
                scrollView.contentInset.bottom = self.originalInset.bottom + self.threshold
            }
        }
    }

    override func resetInset(for scrollView: UIScrollView) {
        scrollView.contentInset.bottom = originalInset.bottom
    }

    // MARK: - Manual Trigger

    func beginLoadingMore() {
        guard !state.isRefreshing, state != .noMoreData else { return }

        setState(.refreshing)

        guard let scrollView else { return }
        UIView.animate(withDuration: 0.25) {
            scrollView.contentInset.bottom = self.originalInset.bottom + self.threshold
        }

        Task { @MainActor [weak self] in
            await self?.action?()
            self?.endRefreshing()
        }
    }

    // MARK: - No More Data

    func setNoMoreData() {
        guard state != .noMoreData else { return }
        if state.isRefreshing {
            guard let scrollView else {
                setState(.noMoreData)
                return
            }
            UIView.animate(withDuration: 0.25, animations: {
                scrollView.contentInset.bottom = self.originalInset.bottom
            }, completion: { _ in
                self.setState(.noMoreData)
            })
        } else {
            setState(.noMoreData)
        }
    }

    func resetNoMoreData() {
        guard state == .noMoreData else { return }
        setState(.idle)
    }
}
