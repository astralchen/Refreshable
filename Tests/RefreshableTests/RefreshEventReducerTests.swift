import Testing
@testable import Refreshable

@Suite("RefreshEventReducer")
struct RefreshEventReducerTests {

    @Test("拖动距离回到零时从 pulling 恢复 idle")
    func pullingReturnsToIdleAtZeroProgress() {
        var reducer = RefreshEventReducer(role: .refresh, automaticallyEnds: true)
        _ = reducer.reduce(.attach)
        _ = reducer.reduce(.dragChanged(progress: 0.4))

        let reduction = reducer.reduce(.dragChanged(progress: 0))

        #expect(reducer.publicState == .idle)
        #expect(reduction.notifiedState == .idle)
        #expect(reduction.shouldRender)
    }

    @Test("取消已经触发的手势不会启动 action")
    func cancelledTriggeredGestureReturnsToIdle() {
        var reducer = RefreshEventReducer(role: .refresh, automaticallyEnds: true)
        _ = reducer.reduce(.attach)
        _ = reducer.reduce(.dragChanged(progress: 1.2))

        let reduction = reducer.reduce(.panCancelled)

        #expect(reducer.publicState == .idle)
        #expect(reduction.effects.contains(where: \.startsAction) == false)
    }

    @Test("松开 triggered 手势进入 active 并生成 action token")
    func endedTriggeredGestureBeginsAction() throws {
        var reducer = RefreshEventReducer(role: .refresh, automaticallyEnds: true)
        _ = reducer.reduce(.attach)
        _ = reducer.reduce(.dragChanged(progress: 1.25))

        let reduction = reducer.reduce(.panEnded)
        let actionGeneration = try #require(reduction.effects.compactMap(\.actionStartGeneration).first)

        #expect(reducer.publicState == .active)
        #expect(reduction.effects.contains(.setInsetVisible(reveal: true)))
        #expect(reducer.canStartAction(generation: actionGeneration))
    }

    @Test("自动触发 action 时保留用户当前位置")
    func automaticTriggerDoesNotRevealInset() {
        var reducer = RefreshEventReducer(role: .loadMore, automaticallyEnds: true)
        _ = reducer.reduce(.attach)

        let reduction = reducer.reduce(.automaticTrigger)

        #expect(reducer.publicState == .active)
        #expect(reduction.effects.contains(.setInsetVisible(reveal: false)))
        #expect(reduction.effects.contains(.setInsetVisible(reveal: true)) == false)
    }

    @Test("回调重入 detach 后旧 action token 失效")
    func detachedReducerRejectsDeferredActionStart() throws {
        var reducer = RefreshEventReducer(role: .refresh, automaticallyEnds: true)
        _ = reducer.reduce(.attach)
        let beginReduction = reducer.reduce(.begin)
        let actionGeneration = try #require(beginReduction.effects.compactMap(\.actionStartGeneration).first)

        let detachReduction = reducer.reduce(.detach)

        #expect(reducer.canStartAction(generation: actionGeneration) == false)
        #expect(detachReduction.effects.contains(.cancelAction))
        #expect(detachReduction.effects.contains(.removeInset(animated: false, completionGeneration: nil)))
    }

    @Test("旧 ending 动画 completion 不得结束新一轮状态")
    func staleEndingCompletionIsIgnored() throws {
        var reducer = RefreshEventReducer(role: .refresh, automaticallyEnds: false)
        _ = reducer.reduce(.attach)
        _ = reducer.reduce(.begin)
        let endingReduction = reducer.reduce(.endRequested)
        let endingGeneration = try #require(
            endingReduction.effects.compactMap(\.insetRemovalGeneration).first
        )
        _ = reducer.reduce(.setEnabled(false))

        let staleCompletion = reducer.reduce(.endAnimationCompleted(generation: endingGeneration))

        #expect(staleCompletion.shouldRender == false)
        #expect(staleCompletion.notifiedState == nil)
    }

    @Test("noMoreData 保持终态且 action 完成只清理任务")
    func noMoreDataIgnoresAutomaticActionEnd() throws {
        var reducer = RefreshEventReducer(role: .loadMore, automaticallyEnds: true)
        _ = reducer.reduce(.attach)
        let beginReduction = reducer.reduce(.begin)
        let actionGeneration = try #require(beginReduction.effects.compactMap(\.actionStartGeneration).first)

        let terminalReduction = reducer.reduce(.markNoMoreData(revealAtBoundary: false))
        let completionReduction = reducer.reduce(.actionCompleted(generation: actionGeneration))

        #expect(terminalReduction.effects.contains(.setInsetVisible(reveal: false)))
        #expect(reducer.publicState == .noMoreData)
        #expect(completionReduction.effects.contains(.clearAction(generation: actionGeneration)))
        #expect(completionReduction.effects.contains(where: \.removesInset) == false)
    }

    @Test("triggered overshoot 只刷新进度，不重复状态回调")
    func triggeredOvershootOnlyRendersProgress() {
        var reducer = RefreshEventReducer(role: .refresh, automaticallyEnds: true)
        _ = reducer.reduce(.attach)
        _ = reducer.reduce(.dragChanged(progress: 1.1))

        let reduction = reducer.reduce(.dragChanged(progress: 1.8))

        #expect(reducer.publicState == .triggered)
        #expect(reducer.renderProgress == 1.8)
        #expect(reduction.shouldRender)
        #expect(reduction.notifiedState == nil)
    }

    @Test("action 自动完成进入 ending，只有匹配 animation generation 才回 idle")
    func automaticCompletionUsesTransitionGeneration() throws {
        var reducer = RefreshEventReducer(role: .refresh, automaticallyEnds: true)
        _ = reducer.reduce(.attach)
        let begin = reducer.reduce(.begin)
        let actionGeneration = try #require(begin.effects.compactMap(\.actionStartGeneration).first)

        let ending = reducer.reduce(.actionCompleted(generation: actionGeneration))
        let transitionGeneration = try #require(
            ending.effects.compactMap(\.insetRemovalGeneration).first
        )
        _ = reducer.reduce(.endAnimationCompleted(generation: transitionGeneration &- 1))
        #expect(reducer.publicState == .ending)

        _ = reducer.reduce(.endAnimationCompleted(generation: transitionGeneration))
        #expect(reducer.publicState == .idle)
    }

    @Test("禁用刷新中的组件取消 action，并让旧 action generation 失效")
    func disablingInvalidatesActiveAction() throws {
        var reducer = RefreshEventReducer(role: .refresh, automaticallyEnds: false)
        _ = reducer.reduce(.attach)
        let begin = reducer.reduce(.automaticTrigger)
        let actionGeneration = try #require(begin.effects.compactMap(\.actionStartGeneration).first)

        let disabled = reducer.reduce(.setEnabled(false))

        #expect(reducer.publicState == .ending)
        #expect(reducer.canStartAction(generation: actionGeneration) == false)
        #expect(disabled.effects.contains(.cancelAction))
        #expect(disabled.effects.map(\.removesInset).contains(true))
    }

    @Test("禁用后立即重新启用不会使 ending 动画 completion 失效")
    func reenableDuringDisabledEndingKeepsPendingCompletionValid() throws {
        var reducer = RefreshEventReducer(role: .refresh, automaticallyEnds: false)
        _ = reducer.reduce(.attach)
        _ = reducer.reduce(.begin)

        let disabled = reducer.reduce(.setEnabled(false))
        let endingGeneration = try #require(
            disabled.effects.compactMap(\.insetRemovalGeneration).first
        )
        _ = reducer.reduce(.setEnabled(true))
        _ = reducer.reduce(.endAnimationCompleted(generation: endingGeneration))

        #expect(reducer.isEnabled)
        #expect(reducer.publicState == .idle)

        let nextBegin = reducer.reduce(.begin)
        #expect(nextBegin.effects.contains(where: { $0.startsAction }))
    }

    @Test("reset noMoreData 回 idle 并只移除自身 inset")
    func resettingNoMoreDataRemovesInset() {
        var reducer = RefreshEventReducer(role: .loadMore, automaticallyEnds: true)
        _ = reducer.reduce(.attach)
        _ = reducer.reduce(.markNoMoreData(revealAtBoundary: true))

        let reset = reducer.reduce(.resetNoMoreData)

        #expect(reducer.publicState == .idle)
        #expect(reset.effects == [.removeInset(animated: true, completionGeneration: nil)])
    }
}

private extension RefreshEffect {
    var startsAction: Bool {
        if case .startAction = self { true } else { false }
    }

    var actionStartGeneration: UInt? {
        if case .startAction(let generation) = self { generation } else { nil }
    }

    var insetRemovalGeneration: UInt? {
        if case .removeInset(_, let generation) = self { generation } else { nil }
    }

    var removesInset: Bool {
        if case .removeInset = self { true } else { false }
    }
}
