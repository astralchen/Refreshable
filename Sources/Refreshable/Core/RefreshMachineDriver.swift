import UIKit

/// Owns the reducer and asynchronous action lifecycle for one edge session.
@MainActor
final class RefreshMachineDriver {
    private var reducer: RefreshEventReducer
    private var currentTask: Task<Void, Never>?
    private var currentActionGeneration: UInt?
    var action: (@Sendable () async -> Void)?

    init(
        role: RefreshableRole,
        automaticallyEnds: Bool,
        action: @escaping @Sendable () async -> Void
    ) {
        reducer = RefreshEventReducer(role: role, automaticallyEnds: automaticallyEnds)
        self.action = action
    }

    deinit {
        currentTask?.cancel()
    }

    var state: RefreshState { reducer.publicState }
    var renderProgress: CGFloat { reducer.renderProgress }
    var isEnabled: Bool { reducer.isEnabled }
    var transitionGeneration: UInt { reducer.transitionGeneration }

    func reduce(_ event: RefreshEvent) -> RefreshReduction {
        reducer.reduce(event)
    }

    func canStartAction(generation: UInt) -> Bool {
        reducer.canStartAction(generation: generation)
    }

    func startAction(
        generation: UInt,
        completion: @escaping @MainActor (UInt) -> Void
    ) {
        currentTask?.cancel()
        currentActionGeneration = generation
        let action = action

        currentTask = Task { [weak self, action] in
            guard let action else { return }
            await action()
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard !Task.isCancelled, self != nil else { return }
                completion(generation)
            }
        }
    }

    func cancelAction() {
        currentTask?.cancel()
        currentTask = nil
        currentActionGeneration = nil
    }

    func clearAction(generation: UInt) {
        guard currentActionGeneration == generation else { return }
        currentTask = nil
        currentActionGeneration = nil
    }
}
