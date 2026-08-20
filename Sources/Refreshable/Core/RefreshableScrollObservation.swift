import UIKit

/// A complete, immutable view of the scroll-view inputs used by edge runtimes.
@MainActor
struct RefreshableScrollSnapshot {
    let contentOffset: CGPoint
    let contentSize: CGSize
    let bounds: CGRect
    let contentInset: UIEdgeInsets
    let adjustedInsetDelta: UIEdgeInsets
    let safeAreaInsets: UIEdgeInsets
    let layoutDirection: UIUserInterfaceLayoutDirection
    let isDragging: Bool
    let panState: UIGestureRecognizer.State

    init(scrollView: UIScrollView) {
        contentOffset = scrollView.contentOffset
        contentSize = scrollView.contentSize
        bounds = scrollView.bounds
        contentInset = scrollView.contentInset
        adjustedInsetDelta = UIEdgeInsets(
            top: scrollView.adjustedContentInset.top - scrollView.contentInset.top,
            left: scrollView.adjustedContentInset.left - scrollView.contentInset.left,
            bottom: scrollView.adjustedContentInset.bottom - scrollView.contentInset.bottom,
            right: scrollView.adjustedContentInset.right - scrollView.contentInset.right
        )
        safeAreaInsets = scrollView.safeAreaInsets
        layoutDirection = scrollView.effectiveUserInterfaceLayoutDirection
        isDragging = scrollView.isDragging
        panState = scrollView.panGestureRecognizer.state
    }
}

/// Owns one set of UIKit observations for a scroll view and forwards snapshots.
@MainActor
final class RefreshableScrollObservationSet: NSObject {
    private weak var scrollView: UIScrollView?
    private var observations: [NSKeyValueObservation] = []
    private var observesPan = false
    private(set) var startCount = 0

    var onSnapshot: (@MainActor (RefreshableScrollSnapshot) -> Void)?
    var onPanEnded: (@MainActor () -> Void)?
    var onPanCancelled: (@MainActor () -> Void)?

    func start(for scrollView: UIScrollView) {
        stop()
        startCount += 1
        self.scrollView = scrollView
        observations = [
            scrollView.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.emit() }
            },
            scrollView.observe(\.contentSize, options: [.new]) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.emit() }
            },
            scrollView.observe(\.bounds, options: [.new]) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.emit() }
            },
            scrollView.observe(\.contentInset, options: [.new]) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.emit() }
            },
            scrollView.observe(\.semanticContentAttribute, options: [.new]) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.emit() }
            }
        ]
        scrollView.panGestureRecognizer.addTarget(self, action: #selector(handlePan(_:)))
        observesPan = true
        emit()
    }

    func stop() {
        if observesPan {
            scrollView?.panGestureRecognizer.removeTarget(self, action: #selector(handlePan(_:)))
        }
        observations.forEach { $0.invalidate() }
        observations.removeAll()
        observesPan = false
        scrollView = nil
    }

    @objc
    private func handlePan(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .ended:
            onPanEnded?()
        case .cancelled, .failed:
            onPanCancelled?()
        default:
            break
        }
        emit()
    }

    private func emit() {
        guard let scrollView else { return }
        MainActor.assumeIsolated {
            onSnapshot?(RefreshableScrollSnapshot(scrollView: scrollView))
        }
    }
}
