import UIKit

/// 刷新组件的内部基础类型。
///
/// Reducer 是状态的唯一来源；此类型只负责把 UIKit 事件转换为事件并执行副作用。
@MainActor
class RefreshComponent: NSObject {

    weak var scrollView: UIScrollView? {
        willSet {
            guard scrollView !== newValue else { return }
            if scrollView != nil {
                dispatch(.detach)
                removeObservers()
            }
        }
        didSet {
            guard scrollView !== oldValue else { return }
            guard let scrollView else { return }
            installView(in: scrollView)
            addObservers(to: scrollView)
            dispatch(.attach)
        }
    }

    let renderer: any RefreshableStyleRenderer
    let style: any RefreshableStyle
    let options: RefreshableOptions
    let resolvedOptions: ResolvedRefreshableOptions
    var action: (@Sendable () async -> Void)?

    var triggerThreshold: CGFloat { resolvedOptions.triggerOffset }
    var styleExtent: CGFloat { resolvedOptions.extent }
    var state: RefreshState { reducer.publicState }
    var isEnabled: Bool { reducer.isEnabled }

    private var reducer: RefreshEventReducer
    private var offsetObservation: NSKeyValueObservation?
    private var sizeObservation: NSKeyValueObservation?
    private var boundsObservation: NSKeyValueObservation?
    private var insetObservation: NSKeyValueObservation?
    private var semanticContentObservation: NSKeyValueObservation?
    private var currentTask: Task<Void, Never>?
    private var currentActionGeneration: UInt?
    private var dispatchDepth = 0
    private var deferredEffectEvents: [RefreshEvent] = []

    init(
        role: RefreshableRole,
        style: any RefreshableStyle,
        options: RefreshableOptions = RefreshableOptions(),
        action: @escaping @Sendable () async -> Void
    ) {
        self.style = style
        renderer = style.makeRenderer()
        self.options = options
        resolvedOptions = ResolvedRefreshableOptions(
            options: options,
            styleExtent: style.extent,
            styleTriggerOffset: style.defaultTriggerOffset,
            stylePlacement: style.defaultPlacement
        )
        self.action = action
        reducer = RefreshEventReducer(
            role: role,
            automaticallyEnds: options.automaticallyEndRefreshing
        )
        super.init()
    }

    deinit {
        currentTask?.cancel()
    }

    // MARK: - 子类钩子

    func installView(in scrollView: UIScrollView) {}

    var installedView: UIView { renderer.view }
    var visibilityView: UIView { renderer.view }

    func removeInstalledView() {
        installedView.removeFromSuperview()
    }

    func scrollViewDidScroll(contentOffset: CGPoint) {}
    func scrollViewContentSizeDidChange(contentSize: CGSize) {}
    func scrollViewBoundsDidChange(bounds: CGRect) {}
    func scrollViewContentInsetDidChange(contentInset: UIEdgeInsets) {}
    func scrollViewEnvironmentDidChange() {}
    func scrollViewDidEndDragging() {}
    func scrollViewDidCancelDragging() {}

    /// 显示当前组件对 `contentInset` 的贡献。先于 renderer 和回调执行。
    func setInsetVisible(reveal: Bool) {}

    /// 移除当前组件对 `contentInset` 的贡献，并在动画结束时调用 completion。
    func removeInset(animated: Bool, completion: @escaping @MainActor () -> Void) {
        completion()
    }

    // MARK: - Reducer

    func dispatch(_ event: RefreshEvent) {
        dispatchDepth += 1
        let reduction = reducer.reduce(event)

        for effect in reduction.effects {
            switch effect {
            case .setInsetVisible(let reveal):
                setInsetVisible(reveal: reveal)

            case .removeInset(let animated, let generation):
                removeInset(animated: animated) { [weak self] in
                    guard let self, let generation else { return }
                    self.dispatchEffectCompletion(
                        .endAnimationCompleted(generation: generation)
                    )
                }

            case .cancelAction:
                cancelActionTask()

            case .clearAction(let generation):
                clearActionTask(generation: generation)

            case .startAction:
                break
            }
        }

        if reduction.shouldRender {
            renderCurrentState()
        }

        if let state = reduction.notifiedState {
            options.onStateChange?(state)
        }

        for effect in reduction.effects {
            guard case .startAction(let generation) = effect else { continue }
            guard reducer.canStartAction(generation: generation) else { continue }
            startActionTask(generation: generation)
        }

        dispatchDepth -= 1
        guard dispatchDepth == 0 else { return }
        while !deferredEffectEvents.isEmpty {
            dispatch(deferredEffectEvents.removeFirst())
        }
    }

    /// UIKit 可能同步调用零时长动画的 completion。将这类完成事件延后到当前
    /// reduction 完整执行后，避免 renderer/onStateChange 观察到被嵌套事件覆盖的状态。
    private func dispatchEffectCompletion(_ event: RefreshEvent) {
        guard dispatchDepth > 0 else {
            dispatch(event)
            return
        }
        deferredEffectEvents.append(event)
    }

    private func renderCurrentState() {
        let state = reducer.publicState
        let progress = reducer.renderProgress

        if state == .idle {
            updateViewVisibility(state: state)
        }
        renderer.render(RefreshableStyleContext(state: state, pullProgress: progress))
        if state != .idle {
            updateViewVisibility(state: state)
        }
    }

    private func updateViewVisibility(state: RefreshState) {
        switch state {
        case .idle:
            visibilityView.alpha = 0
        case .pulling(let progress):
            visibilityView.alpha = min(max(progress, 0), 1)
        case .triggered, .refreshing, .noMoreData:
            visibilityView.alpha = 1
        case .ending:
            break
        }
    }

    // MARK: - 控制

    func trigger() {
        dispatch(.begin)
    }

    func endRefreshing() {
        dispatch(.endRequested)
    }

    func setEnabled(_ enabled: Bool) {
        dispatch(.setEnabled(enabled))
    }

    func prepareForRemoval() {
        dispatch(.detach)
        removeInstalledView()
        action = nil
        scrollView = nil
    }

    /// 保留给内部组件测试使用，但仍通过正式事件进入 reducer。
    func setState(_ newState: RefreshState) {
        switch newState {
        case .idle:
            switch state {
            case .ending:
                dispatch(.endAnimationCompleted(generation: reducer.transitionGeneration))
            case .refreshing:
                dispatch(.endRequested)
                dispatch(.endAnimationCompleted(generation: reducer.transitionGeneration))
            default:
                dispatch(.panCancelled)
            }
        case .pulling(let progress):
            dispatch(.dragChanged(progress: progress))
        case .triggered:
            dispatch(.dragChanged(progress: max(reducer.renderProgress, 1)))
        case .refreshing:
            dispatch(.begin)
        case .ending:
            dispatch(.endRequested)
        case .noMoreData:
            dispatch(.markNoMoreData(revealAtBoundary: false))
        }
    }

    private func startActionTask(generation: UInt) {
        currentTask?.cancel()
        currentActionGeneration = generation
        let action = action

        currentTask = Task { [weak self, action] in
            guard let action else { return }
            await action()
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                guard !Task.isCancelled else { return }
                self?.dispatch(.actionCompleted(generation: generation))
            }
        }
    }

    private func cancelActionTask() {
        currentTask?.cancel()
        currentTask = nil
        currentActionGeneration = nil
    }

    private func clearActionTask(generation: UInt) {
        guard currentActionGeneration == generation else { return }
        currentTask = nil
        currentActionGeneration = nil
    }

    // MARK: - KVO

    private func addObservers(to scrollView: UIScrollView) {
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

        boundsObservation = scrollView.observe(\.bounds, options: [.new]) { [weak self] _, change in
            MainActor.assumeIsolated {
                guard let bounds = change.newValue else { return }
                self?.scrollViewBoundsDidChange(bounds: bounds)
            }
        }

        insetObservation = scrollView.observe(\.contentInset, options: [.new]) { [weak self] _, change in
            MainActor.assumeIsolated {
                guard let inset = change.newValue else { return }
                self?.scrollViewContentInsetDidChange(contentInset: inset)
            }
        }

        scrollView.panGestureRecognizer.addTarget(
            self,
            action: #selector(handlePanGestureStateChange(_:))
        )

        semanticContentObservation = scrollView.observe(
            \.semanticContentAttribute,
            options: [.new]
        ) { [weak self] _, _ in
            MainActor.assumeIsolated {
                self?.scrollViewEnvironmentDidChange()
            }
        }
    }

    @objc
    private func handlePanGestureStateChange(_ gestureRecognizer: UIPanGestureRecognizer) {
        switch gestureRecognizer.state {
        case .ended:
            scrollViewDidEndDragging()
        case .cancelled, .failed:
            scrollViewDidCancelDragging()
        default:
            break
        }
    }

    private func removeObservers() {
        scrollView?.panGestureRecognizer.removeTarget(
            self,
            action: #selector(handlePanGestureStateChange(_:))
        )
        offsetObservation?.invalidate()
        sizeObservation?.invalidate()
        boundsObservation?.invalidate()
        insetObservation?.invalidate()
        semanticContentObservation?.invalidate()
        offsetObservation = nil
        sizeObservation = nil
        boundsObservation = nil
        insetObservation = nil
        semanticContentObservation = nil
    }
}
