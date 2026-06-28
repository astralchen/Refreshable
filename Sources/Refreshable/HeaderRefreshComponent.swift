import UIKit

/// 下拉刷新组件
@MainActor
final class HeaderRefreshComponent: RefreshComponent {

    override func installView(in scrollView: UIScrollView) {
        let sv = style.view
        sv.frame = CGRect(x: 0, y: -style.height, width: scrollView.bounds.width, height: style.height)
        sv.autoresizingMask = [.flexibleWidth]
        sv.alpha = 0
        scrollView.addSubview(sv)
        style.update(state: .idle, progress: 0)
    }

    override func scrollViewDidScroll(contentOffset: CGPoint) {
        guard isEnabled else { return }
        guard let scrollView else { return }

        let adjustedTop = originalInset.top
        let offsetY = contentOffset.y + adjustedTop

        switch state {
        case .idle, .pulling:
            if scrollView.isDragging && offsetY < 0 {
                let progress = min(-offsetY / triggerThreshold, 1.0)
                if -offsetY >= triggerThreshold {
                    setState(.triggered)
                } else {
                    setState(.pulling(progress))
                }
            }

        case .triggered:
            if scrollView.isDragging {
                if -offsetY < triggerThreshold {
                    let progress = min(-offsetY / triggerThreshold, 1.0)
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
            UIView.animate(withDuration: options.animationDuration) {
                scrollView.contentInset.top = self.originalInset.top + self.triggerThreshold
            }
        }
    }

    override func resetInset(for scrollView: UIScrollView) {
        scrollView.contentInset.top = originalInset.top
    }

    // MARK: - Manual Trigger

    func beginRefreshing() {
        guard isEnabled else { return }
        guard !state.isRefreshing else { return }
        guard state != .ending else { return }
        guard let scrollView else { return }

        captureOriginalInset()
        setState(.refreshing)

        UIView.animate(withDuration: options.animationDuration) {
            scrollView.contentInset.top = self.originalInset.top + self.triggerThreshold
            scrollView.contentOffset.y = -self.originalInset.top - self.triggerThreshold
        }

        startActionTask()
    }
}
