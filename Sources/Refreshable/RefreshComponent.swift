import UIKit

/// 刷新组件基类，管理状态机、KVO 和 inset
@MainActor
public class RefreshComponent: NSObject {

    // MARK: - Properties

    weak var scrollView: UIScrollView? {
        didSet {
            guard scrollView !== oldValue else { return }
            removeObservers(from: oldValue)
            if let sv = scrollView {
                addObservers(to: sv)
                installView(in: sv)
            }
        }
    }

    let style: any RefreshableStyle
    var action: (@MainActor () async -> Void)?

    private(set) var state: RefreshState = .idle {
        didSet {
            guard state != oldValue else { return }
            let progress: CGFloat = if case .pulling(let p) = state { p } else { 0 }
            style.update(state: state, progress: progress)
            updateViewVisibility(state: state, progress: progress)
            stateDidChange(from: oldValue, to: state)
        }
    }

    /// 记录 scrollView 原始 contentInset，刷新时在此基础上增减
    var originalInset: UIEdgeInsets = .zero

    private var offsetObservation: NSKeyValueObservation?
    private var sizeObservation: NSKeyValueObservation?
    private var panStateObservation: NSKeyValueObservation?

    // MARK: - Init

    init(style: some RefreshableStyle, action: @MainActor @escaping () async -> Void) {
        self.style = style
        self.action = action
        super.init()
    }

    deinit {
        // NSKeyValueObservation 会在 deinit 时自动 invalidate
    }

    // MARK: - Subclass Hooks

    /// 将 style.view 安装到 scrollView 中，子类实现
    func installView(in scrollView: UIScrollView) {
        // override
    }

    /// scrollView 的 contentOffset 变化时调用
    func scrollViewDidScroll(contentOffset: CGPoint) {
        // override
    }

    /// scrollView 的 contentSize 变化时调用
    func scrollViewContentSizeDidChange(contentSize: CGSize) {
        // override
    }

    /// 用户松手时调用
    func scrollViewDidEndDragging() {
        // override
    }

    /// 状态变化回调，子类可重写以调整 inset
    func stateDidChange(from oldState: RefreshState, to newState: RefreshState) {
        // override
    }

    // MARK: - View Visibility

    /// 控制 style.view 的可见性，模拟 UIRefreshControl 的显示逻辑：
    /// idle 时完全透明，pulling 时跟随 progress 渐显，triggered/refreshing 时完全显示
    private func updateViewVisibility(state: RefreshState, progress: CGFloat) {
        switch state {
        case .idle:
            style.view.alpha = 0
        case .pulling(let p):
            style.view.alpha = min(p, 1.0)
        case .triggered, .refreshing:
            style.view.alpha = 1
        case .ending:
            // ending 期间保持可见，动画结束后回到 idle 时会置 0
            break
        case .noMoreData:
            style.view.alpha = 1
        }
    }

    // MARK: - State Management

    func setState(_ newState: RefreshState) {
        state = newState
    }

    func trigger() {
        guard !state.isRefreshing else { return }
        setState(.refreshing)

        Task { @MainActor [weak self] in
            await self?.action?()
            self?.endRefreshing()
        }
    }

    func endRefreshing() {
        guard state.isRefreshing || state == .ending else { return }
        setState(.ending)

        guard let scrollView else {
            setState(.idle)
            return
        }

        UIView.animate(withDuration: 0.25, animations: {
            self.resetInset(for: scrollView)
        }, completion: { _ in
            self.setState(.idle)
        })
    }

    /// 子类重写以恢复 inset
    func resetInset(for scrollView: UIScrollView) {
        // override
    }

    // MARK: - KVO

    private func addObservers(to scrollView: UIScrollView) {
        originalInset = scrollView.contentInset

        offsetObservation = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] _, change in
            MainActor.assumeIsolated {
                guard let offset = change.newValue else { return }
                self?.scrollViewDidScroll(contentOffset: offset)
            }
        }

        sizeObservation = scrollView.observe(\.contentSize, options: [.new]) { [weak self] _, change in
            MainActor.assumeIsolated {
                guard let size = change.newValue else { return }
                self?.scrollViewContentSizeDidChange(contentSize: size)
            }
        }

        panStateObservation = scrollView.observe(\.panGestureRecognizer.state, options: [.new]) { [weak self] sv, _ in
            MainActor.assumeIsolated {
                if sv.panGestureRecognizer.state == .ended {
                    self?.scrollViewDidEndDragging()
                }
            }
        }
    }

    private func removeObservers(from scrollView: UIScrollView?) {
        offsetObservation?.invalidate()
        offsetObservation = nil
        sizeObservation?.invalidate()
        sizeObservation = nil
        panStateObservation?.invalidate()
        panStateObservation = nil
    }
}
