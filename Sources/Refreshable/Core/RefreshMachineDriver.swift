import UIKit

/// 持有单个 edge session 的 reducer 和异步 action 生命周期。
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
        // 新 action 启动前取消旧 task，并记录 generation；旧 completion 即使返回也不能提交状态。
        currentTask?.cancel()
        currentActionGeneration = generation
        let action = action

        currentTask = Task { [weak self, action] in
            guard let action else { return }
            await action()
            guard !Task.isCancelled else { return }
            await MainActor.run {
                // completion 仍带着启动时的 generation，由上层 reducer 再次校验有效性。
                guard !Task.isCancelled, self != nil else { return }
                completion(generation)
            }
        }
    }

    func cancelAction() {
        // 移除、替换和禁用都会走这里，确保 action 与 generation 一起失效。
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
