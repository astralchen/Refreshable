import Foundation

enum RefreshEvent: Equatable {
    case attach
    case detach
    case setEnabled(Bool)
    case dragChanged(progress: CGFloat)
    case panEnded
    case panCancelled
    case automaticTrigger
    case begin
    case actionCompleted(generation: UInt)
    case endRequested
    case endAnimationCompleted(generation: UInt)
    case markNoMoreData(revealAtBoundary: Bool)
    case resetNoMoreData
}

enum RefreshEffect: Equatable {
    case setInsetVisible(reveal: Bool)
    case removeInset(animated: Bool, completionGeneration: UInt?)
    case startAction(generation: UInt)
    case cancelAction
    case clearAction(generation: UInt)
}

struct RefreshReduction: Equatable {
    var shouldRender = false
    var notifiedState: RefreshState?
    var effects: [RefreshEffect] = []
}

private enum RefreshMachinePhase: Equatable {
    case idle
    case pulling
    case triggered
    case active
    case ending
    case noMoreData
}

struct RefreshEventReducer {
    private let role: RefreshableRole
    private let automaticallyEnds: Bool

    private var phase: RefreshMachinePhase = .idle
    private(set) var pullProgress: CGFloat = 0
    private(set) var isAttached = false
    private(set) var isEnabled = true
    private(set) var transitionGeneration: UInt = 0
    private var nextActionGeneration: UInt = 0
    private var activeActionGeneration: UInt?

    init(role: RefreshableRole, automaticallyEnds: Bool) {
        self.role = role
        self.automaticallyEnds = automaticallyEnds
    }

    var publicState: RefreshState {
        switch phase {
        case .idle:
            .idle
        case .pulling:
            .pulling(pullProgress)
        case .triggered:
            .triggered
        case .active:
            .active
        case .ending:
            .ending
        case .noMoreData:
            .noMoreData
        }
    }

    var renderProgress: CGFloat {
        switch phase {
        case .idle, .noMoreData:
            0
        case .pulling, .triggered:
            pullProgress
        case .active, .ending:
            1
        }
    }

    func canStartAction(generation: UInt) -> Bool {
        isAttached
            && isEnabled
            && phase == .active
            && activeActionGeneration == generation
    }

    mutating func reduce(_ event: RefreshEvent) -> RefreshReduction {
        let previousState = publicState
        let previousProgress = renderProgress
        var effects: [RefreshEffect] = []
        var forceRender = false
        var suppressNotification = false

        switch event {
        case .attach:
            guard !isAttached else { return RefreshReduction() }
            isAttached = true
            transitionGeneration &+= 1
            forceRender = true
            suppressNotification = true

        case .detach:
            guard isAttached else { return RefreshReduction() }
            isAttached = false
            transitionGeneration &+= 1
            nextActionGeneration &+= 1
            activeActionGeneration = nil
            setPhase(.idle, progress: 0)
            effects = [.cancelAction, .removeInset(animated: false, completionGeneration: nil)]
            suppressNotification = true

        case .setEnabled(let enabled):
            guard isEnabled != enabled else { return RefreshReduction() }
            isEnabled = enabled
            guard !enabled else {
                // 重新启用不能使正在执行的 ending 动画失效；该 completion 仍负责回到 idle。
                return RefreshReduction()
            }
            transitionGeneration &+= 1

            if activeActionGeneration != nil {
                activeActionGeneration = nil
                nextActionGeneration &+= 1
                effects.append(.cancelAction)
            }

            switch phase {
            case .active, .ending:
                setPhase(.ending, progress: 1)
                effects.append(
                    .removeInset(animated: true, completionGeneration: transitionGeneration)
                )
            case .pulling, .triggered:
                setPhase(.idle, progress: 0)
            case .idle, .noMoreData:
                break
            }

        case .dragChanged(let progress):
            guard isAttached, isEnabled else { return RefreshReduction() }
            guard phase == .idle || phase == .pulling || phase == .triggered else {
                return RefreshReduction()
            }

            let normalized = min(max(progress.isFinite ? progress : 0, 0), 2)
            if normalized <= 0 {
                setPhase(.idle, progress: 0)
            } else if normalized < 1 {
                setPhase(.pulling, progress: normalized)
            } else {
                setPhase(.triggered, progress: normalized)
            }

        case .panEnded:
            switch phase {
            case .triggered:
                effects = beginActionIfPossible(revealInset: true)
            case .pulling:
                setPhase(.idle, progress: 0)
            case .idle, .active, .ending, .noMoreData:
                break
            }

        case .panCancelled:
            if phase == .pulling || phase == .triggered {
                setPhase(.idle, progress: 0)
            }

        case .automaticTrigger:
            effects = beginActionIfPossible(revealInset: false)

        case .begin:
            effects = beginActionIfPossible(revealInset: true)

        case .actionCompleted(let generation):
            guard activeActionGeneration == generation else { return RefreshReduction() }
            activeActionGeneration = nil
            effects.append(.clearAction(generation: generation))

            if phase == .active, automaticallyEnds {
                transitionGeneration &+= 1
                setPhase(.ending, progress: 1)
                effects.append(
                    .removeInset(animated: true, completionGeneration: transitionGeneration)
                )
            }

        case .endRequested:
            guard phase == .active || phase == .ending else { return RefreshReduction() }
            transitionGeneration &+= 1
            setPhase(.ending, progress: 1)
            effects.append(
                .removeInset(animated: true, completionGeneration: transitionGeneration)
            )

        case .endAnimationCompleted(let generation):
            guard phase == .ending, generation == transitionGeneration else {
                return RefreshReduction()
            }
            setPhase(.idle, progress: 0)

        case .markNoMoreData(let revealAtBoundary):
            guard role == .loadMore, isAttached, phase != .noMoreData else {
                return RefreshReduction()
            }
            transitionGeneration &+= 1
            setPhase(.noMoreData, progress: 0)
            effects.append(.setInsetVisible(reveal: revealAtBoundary))

        case .resetNoMoreData:
            guard role == .loadMore, phase == .noMoreData else {
                return RefreshReduction()
            }
            transitionGeneration &+= 1
            setPhase(.idle, progress: 0)
            effects.append(.removeInset(animated: true, completionGeneration: nil))
        }

        let nextState = publicState
        let stateChanged = nextState != previousState
        let renderChanged = renderProgress != previousProgress

        return RefreshReduction(
            shouldRender: forceRender || stateChanged || renderChanged,
            notifiedState: stateChanged && !suppressNotification ? nextState : nil,
            effects: effects
        )
    }

    private mutating func beginActionIfPossible(revealInset: Bool) -> [RefreshEffect] {
        guard isAttached, isEnabled else { return [] }
        guard phase != .active, phase != .ending else { return [] }
        guard !(role == .loadMore && phase == .noMoreData) else { return [] }

        transitionGeneration &+= 1
        nextActionGeneration &+= 1
        activeActionGeneration = nextActionGeneration
        setPhase(.active, progress: 1)
        return [
            .setInsetVisible(reveal: revealInset),
            .startAction(generation: nextActionGeneration),
        ]
    }

    private mutating func setPhase(_ phase: RefreshMachinePhase, progress: CGFloat) {
        self.phase = phase
        pullProgress = progress
    }
}
