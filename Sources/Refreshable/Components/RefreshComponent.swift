import UIKit

@MainActor
protocol RefreshComponentEffects: AnyObject {
    var installedView: UIView { get }
    var visibilityView: UIView { get }
    func installView(in scrollView: UIScrollView)
    func removeInstalledView()
    func scrollViewDidScroll(contentOffset: CGPoint)
    func scrollViewContentSizeDidChange(contentSize: CGSize)
    func scrollViewBoundsDidChange(bounds: CGRect)
    func scrollViewContentInsetDidChange(contentInset: UIEdgeInsets)
    func scrollViewEnvironmentDidChange()
    func scrollViewDidEndDragging()
    func scrollViewDidCancelDragging()
    func setInsetVisible(reveal: Bool)
    func removeInset(animated: Bool, completion: @escaping @MainActor () -> Void)
}

/// 组合状态机、action、渲染和观察驱动职责的内部组件。
@MainActor
final class RefreshComponent: NSObject {

    weak var effects: (any RefreshComponentEffects)?

    weak var scrollView: UIScrollView? {
        willSet {
            guard scrollView !== newValue else { return }
            if scrollView != nil {
                dispatch(.detach)
                stopObservations()
            }
        }
        didSet {
            guard scrollView !== oldValue else { return }
            guard let scrollView else { return }
            effects?.installView(in: scrollView)
            if !usesExternalObservation {
                startObservations(in: scrollView)
            }
            dispatch(.attach)
        }
    }

    let renderer: any RefreshableStyleRenderer
    let style: any RefreshableStyle
    let options: RefreshableOptions
    let resolvedOptions: ResolvedRefreshableOptions
    var action: (@Sendable () async -> Void)? {
        get { machine.action }
        set { machine.action = newValue }
    }

    var triggerThreshold: CGFloat { resolvedOptions.triggerDistance }
    var styleExtent: CGFloat { resolvedOptions.extent }
    var state: RefreshState { machine.state }
    var isEnabled: Bool { machine.isEnabled }

    private let machine: RefreshMachineDriver
    private let usesExternalObservation: Bool
    private let observationSet = RefreshableScrollObservationSet()
    private var dispatchDepth = 0
    private var deferredEffectEvents: [RefreshEvent] = []

    init(
        role: RefreshableRole,
        style: any RefreshableStyle,
        options: RefreshableOptions = RefreshableOptions(),
        usesExternalObservation: Bool = false,
        action: @escaping @Sendable () async -> Void
    ) {
        self.style = style
        renderer = style.makeRenderer()
        self.options = options
        resolvedOptions = ResolvedRefreshableOptions(
            options: options,
            styleExtent: style.extent,
            styleTriggerDistance: style.defaultTriggerDistance,
            stylePlacement: style.defaultPlacement
        )
        self.usesExternalObservation = usesExternalObservation
        machine = RefreshMachineDriver(
            role: role,
            automaticallyEnds: options.automaticallyEnds,
            action: action
        )
        super.init()
    }

    func startObservations(in scrollView: UIScrollView) {
        observationSet.onSnapshot = { [weak self] snapshot in
            self?.receive(snapshot)
        }
        observationSet.onPanEnded = { [weak self] in
            self?.effects?.scrollViewDidEndDragging()
        }
        observationSet.onPanCancelled = { [weak self] in
            self?.effects?.scrollViewDidCancelDragging()
        }
        observationSet.start(for: scrollView)
    }

    func stopObservations() {
        observationSet.stop()
        observationSet.onSnapshot = nil
        observationSet.onPanEnded = nil
        observationSet.onPanCancelled = nil
    }

    func receive(_ snapshot: RefreshableScrollSnapshot) {
        effects?.scrollViewDidScroll(contentOffset: snapshot.contentOffset)
        effects?.scrollViewContentSizeDidChange(contentSize: snapshot.contentSize)
        effects?.scrollViewBoundsDidChange(bounds: snapshot.bounds)
        effects?.scrollViewContentInsetDidChange(contentInset: snapshot.contentInset)
        effects?.scrollViewEnvironmentDidChange()
    }

    // MARK: - 状态归约

    func dispatch(_ event: RefreshEvent) {
        dispatchDepth += 1
        let reduction = machine.reduce(event)

        // 严格保持 reducer 约定的副作用顺序：先布局，再渲染和回调，最后启动 action。
        for effect in reduction.effects {
            switch effect {
            case .setInsetVisible(let reveal):
                effects?.setInsetVisible(reveal: reveal)

            case .removeInset(let animated, let generation):
                effects?.removeInset(animated: animated) { [weak self] in
                    guard let self, let generation else { return }
                    self.dispatchEffectCompletion(
                        .endAnimationCompleted(generation: generation)
                    )
                }

            case .cancelAction:
                machine.cancelAction()

            case .clearAction(let generation):
                machine.clearAction(generation: generation)

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
            // generation 校验必须紧邻启动点，避免前面的回调改变 session 后仍启动旧 action。
            guard machine.canStartAction(generation: generation) else { continue }
            machine.startAction(generation: generation) { [weak self] generation in
                self?.dispatch(.actionCompleted(generation: generation))
            }
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
        let state = machine.state
        let progress = machine.renderProgress

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
            effects?.visibilityView.alpha = 0
        case .pulling(let progress):
            effects?.visibilityView.alpha = min(max(progress, 0), 1)
        case .triggered, .active, .noMoreData:
            effects?.visibilityView.alpha = 1
        case .ending:
            break
        }
    }

    // MARK: - 控制

    func trigger() {
        dispatch(.begin)
    }

    func endAction() {
        dispatch(.endRequested)
    }

    func setEnabled(_ enabled: Bool) {
        dispatch(.setEnabled(enabled))
    }

    func prepareForRemoval() {
        dispatch(.detach)
        effects?.removeInstalledView()
        action = nil
        scrollView = nil
    }

    /// 保留给内部组件测试使用，但仍通过正式事件进入 reducer。
    func setState(_ newState: RefreshState) {
        switch newState {
        case .idle:
            switch state {
            case .ending:
                dispatch(.endAnimationCompleted(generation: machine.transitionGeneration))
            case .active:
                dispatch(.endRequested)
                dispatch(.endAnimationCompleted(generation: machine.transitionGeneration))
            default:
                dispatch(.panCancelled)
            }
        case .pulling(let progress):
            dispatch(.dragChanged(progress: progress))
        case .triggered:
            dispatch(.dragChanged(progress: max(machine.renderProgress, 1)))
        case .active:
            dispatch(.begin)
        case .ending:
            dispatch(.endRequested)
        case .noMoreData:
            dispatch(.markNoMoreData(revealAtBoundary: false))
        }
    }

}
