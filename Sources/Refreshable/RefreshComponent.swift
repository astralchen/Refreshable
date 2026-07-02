import UIKit

/// 刷新组件的基础类型。
///
/// 此类型协调共享的状态切换、滚动视图观察和 inset 恢复逻辑。
/// 通常不需要直接使用此类型；请通过 `UIScrollView` 的刷新 API 安装组件。
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
    let options: RefreshableOptions
    var action: (@Sendable () async -> Void)?

    var triggerThreshold: CGFloat {
        let rawValue = options.triggerOffset ?? style.extent
        guard rawValue.isFinite, rawValue > 0 else { return 1 }
        return rawValue
    }

    private(set) var state: RefreshState = .idle {
        didSet {
            guard state != oldValue else { return }
            let progress: CGFloat = if case .pulling(let p) = state { p } else { 0 }
            style.update(state: state, progress: progress)
            updateViewVisibility(state: state, progress: progress)
            options.onStateChange?(state)
            stateDidChange(from: oldValue, to: state)
        }
    }

    /// 记录滚动视图的原始 `contentInset`，刷新时在此基础上增减。
    var originalInset: UIEdgeInsets = .zero

    private var offsetObservation: NSKeyValueObservation?
    private var sizeObservation: NSKeyValueObservation?
    private var panStateObservation: NSKeyValueObservation?
    private var currentTask: Task<Void, Never>?
    private var actionGeneration = 0

    var isEnabled = true

    // MARK: - Init

    init(
        style: any RefreshableStyle,
        options: RefreshableOptions = RefreshableOptions(),
        action: @escaping @Sendable () async -> Void
    ) {
        self.style = style
        self.options = options
        self.action = action
        super.init()
    }

    deinit {
        // NSKeyValueObservation 会在 deinit 时自动 invalidate
        currentTask?.cancel()
    }

    // MARK: - Subclass Hooks

    /// 将 `style.view` 安装到指定滚动视图中。
    func installView(in scrollView: UIScrollView) {
        // override
    }

    /// 当前组件安装到滚动视图上的外层视图。
    var installedView: UIView {
        style.view
    }

    /// 状态变化时用于控制可见性的视图。
    var visibilityView: UIView {
        style.view
    }

    /// 移除组件安装的视图。
    func removeInstalledView() {
        installedView.removeFromSuperview()
    }

    /// 滚动视图的 `contentOffset` 变化时调用。
    func scrollViewDidScroll(contentOffset: CGPoint) {
        // override
    }

    /// 滚动视图的 `contentSize` 变化时调用。
    func scrollViewContentSizeDidChange(contentSize: CGSize) {
        // override
    }

    /// 用户结束拖动时调用。
    func scrollViewDidEndDragging() {
        // override
    }

    /// 状态变化时调用，子类可重写以调整 inset。
    func stateDidChange(from oldState: RefreshState, to newState: RefreshState) {
        // override
    }

    // MARK: - View Visibility

    /// 控制 `style.view` 的可见性，模拟 `UIRefreshControl` 的显示逻辑。
    private func updateViewVisibility(state: RefreshState, progress: CGFloat) {
        switch state {
        case .idle:
            visibilityView.alpha = 0
        case .pulling(let p):
            visibilityView.alpha = min(p, 1.0)
        case .triggered:
            visibilityView.alpha = 1
        case .refreshing:
            visibilityView.alpha = 1
        case .ending:
            // ending 期间保持可见，动画结束后回到 idle 时会置 0
            break
        case .noMoreData:
            visibilityView.alpha = 1
        }
    }

    // MARK: - State Management

    func setState(_ newState: RefreshState) {
        state = newState
    }

    func trigger() {
        guard isEnabled else { return }
        guard !state.isRefreshing else { return }
        guard state != .ending else { return }
        captureOriginalInset()
        setState(.refreshing)
        startActionTask()
    }

    func endRefreshing() {
        guard state.isRefreshing || state == .ending else { return }
        setState(.ending)

        guard let scrollView else {
            setState(.idle)
            return
        }

        UIView.animate(withDuration: options.animationDuration, animations: {
            self.resetInset(for: scrollView)
        }, completion: { _ in
            if self.state == .ending {
                self.setState(.idle)
            }
        })
    }

    /// 恢复指定滚动视图的 inset。
    func resetInset(for scrollView: UIScrollView) {
        // override
    }

    func captureOriginalInset() {
        if let scrollView {
            originalInset = scrollView.contentInset
        }
    }

    func startActionTask() {
        currentTask?.cancel()
        actionGeneration += 1
        let generation = actionGeneration
        let action = action

        currentTask = Task.detached { [weak self, action] in
            guard let action else { return }
            await action()

            guard !Task.isCancelled else { return }
            let shouldAutomaticallyEnd = await MainActor.run { [weak self] in
                guard let self else { return false }
                guard self.options.automaticallyEndRefreshing else {
                    self.currentTask = nil
                    return false
                }
                return true
            }
            guard shouldAutomaticallyEnd else { return }

            try? await Task.sleep(nanoseconds: 1_000_000)

            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                guard !Task.isCancelled, let self, self.actionGeneration == generation else { return }
                self.currentTask = nil
                self.endRefreshing()
            }
        }
    }

    func cancelCurrentTask(resetState: Bool) {
        currentTask?.cancel()
        currentTask = nil
        actionGeneration += 1

        guard resetState else { return }
        if state.isRefreshing || state == .ending {
            endRefreshing()
        } else if state != .idle && state != .noMoreData {
            setState(.idle)
        }
    }

    func setEnabled(_ enabled: Bool) {
        guard isEnabled != enabled else { return }
        isEnabled = enabled

        if !enabled {
            cancelCurrentTask(resetState: true)
        }
    }

    func prepareForRemoval() {
        cancelCurrentTask(resetState: false)
        restoreInsetIfNeeded()
        removeInstalledView()
        scrollView = nil
    }

    private func restoreInsetIfNeeded() {
        guard state.isRefreshing || state == .ending || state == .noMoreData else { return }
        guard let scrollView else { return }

        UIView.performWithoutAnimation {
            resetInset(for: scrollView)
        }
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
