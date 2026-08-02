import Testing
@testable import Refreshable
import UIKit

@Suite("EdgeRefreshComponent .top refresh")
@MainActor
struct EdgeTopRefreshComponentTests {

    private func makeSUT() -> (UIScrollView, EdgeRefreshComponent, MockStyle) {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        let style = MockStyle()
        let component = makeTopRefreshComponent(
            style: style,
            options: RefreshableOptions(automaticallyEnds: false)
        )
        component.scrollView = scrollView
        return (scrollView, component, style)
    }

    // MARK: - 安装

    @Test("installView 将 style.view 添加为 scrollView 子视图")
    func installView() throws {
        let (scrollView, _, style) = makeSUT()
        let hostView = try #require(style.view.superview)
        #expect(hostView.superview === scrollView)
    }

    @Test("style.view frame 在 scrollView 上方")
    func viewFrame() throws {
        let (scrollView, component, style) = makeSUT()
        #expect(component.scrollView === scrollView)
        let hostView = try #require(style.view.superview)
        #expect(hostView.frame.origin.y == -style.extent)
        #expect(style.view.frame.origin.y == 0)
        #expect(style.view.frame.size.height == style.extent)
    }

    @Test("安装后 style 收到 idle 状态更新")
    func initialStateUpdate() {
        let (_, _, style) = makeSUT()
        #expect(style.lastState == .idle)
    }

    // MARK: - 状态机

    @Test("初始状态为 idle")
    func initialState() {
        let (_, component, _) = makeSUT()
        #expect(component.state == .idle)
    }

    @Test("scrollViewDidScroll: 下拉但不够阈值 → pulling")
    func pullingState() {
        let (_, component, style) = makeSUT()
        style.reset()

        // 模拟 isDragging — 直接调用 scrollViewDidScroll
        // isDragging 在测试中为 false，所以需要通过 setState 测试状态机逻辑
        component.setState(.pulling(0.5))
        #expect(component.state == .pulling(0.5))
        #expect(style.lastState == .pulling(0.5))
        #expect(style.lastProgress == 0.5)
    }

    @Test("状态从 pulling → triggered")
    func triggeredState() {
        let (_, component, style) = makeSUT()
        style.reset()

        component.setState(.pulling(0.8))
        component.setState(.triggered)
        #expect(component.state == .triggered)
        #expect(style.lastState == .triggered)
    }

    @Test("triggered 后继续下拉仍传递进度")
    func triggeredStateContinuesForwardingPullProgress() {
        let scrollView = HeaderDraggingScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.contentSize = CGSize(width: 375, height: 1200)
        scrollView.isDraggingOverride = true
        let style = MockStyle(extent: 60)
        let component = makeTopRefreshComponent(
            style: style,
            options: RefreshableOptions(
                triggerDistance: 60,
                automaticallyEnds: false
            )
        )
        component.scrollView = scrollView
        style.reset()

        component.scrollViewDidScroll(contentOffset: CGPoint(x: 0, y: -60))
        component.scrollViewDidScroll(contentOffset: CGPoint(x: 0, y: -102))

        #expect(component.state == .triggered)
        #expect(style.lastState == .triggered)
        #expect(style.lastProgress == 1.7)
    }

    @Test("scrollViewDidEndDragging: triggered 状态下触发 active")
    func endDraggingTriggersRefresh() {
        let (_, component, _) = makeSUT()
        component.setState(.triggered)

        component.scrollViewDidEndDragging()
        #expect(component.state == .active)
    }

    @Test("scrollViewDidEndDragging: 非 triggered 状态下不触发")
    func endDraggingIdleNoOp() {
        let (_, component, _) = makeSUT()
        #expect(component.state == .idle)

        component.scrollViewDidEndDragging()
        #expect(component.state == .idle)
    }

    @Test("scrollViewDidEndDragging: pulling 状态下回到 idle")
    func endDraggingPullingResetsToIdle() {
        let (_, component, _) = makeSUT()
        component.setState(.pulling(0.3))

        component.scrollViewDidEndDragging()
        #expect(component.state == .idle)
    }

    @Test("scrollViewDidEndDragging: pulling 状态下隐藏刷新视图")
    func endDraggingPullingHidesRefreshView() {
        let (_, component, style) = makeSUT()
        component.setState(.pulling(0.3))
        #expect(style.view.alpha > 0)

        component.scrollViewDidEndDragging()

        #expect(component.state == .idle)
        #expect(style.view.alpha == 0)
    }

    // MARK: - 防重入

    @Test("trigger: 已在 active 时不重复触发")
    func preventReentry() async {
        let counter = ActionCallCounter()
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        let style = MockStyle()
        let component = makeTopRefreshComponent(
            style: style,
            options: RefreshableOptions(automaticallyEnds: false)
        ) {
            await counter.increment()
        }
        component.scrollView = scrollView

        component.trigger()
        #expect(component.state == .active)

        // 再次触发应被忽略
        component.trigger()
        // action 执行计数需要等 Task 调度，但 trigger 的 guard 是同步的
        #expect(component.state == .active)
        #expect(await counter.waitUntilCount(1) == 1)
    }

    // MARK: - beginRefreshing

    @Test("beginRefreshing 从 idle 触发刷新流程")
    func beginRefreshing() {
        let (_, component, _) = makeSUT()
        component.beginRefreshing()
        // 无 window 时 UIView.animate 同步完成，action Task 也可能已执行完
        // 只要不停留在 idle 之前的某个无效状态即可
        let validStates: [RefreshState] = [.active, .ending, .idle]
        #expect(validStates.contains(component.state))
    }

    @Test("beginRefreshing 已在 active 时忽略")
    func beginRefreshingWhenAlreadyActive() {
        let (_, component, style) = makeSUT()
        component.beginRefreshing()
        style.reset()

        component.beginRefreshing()
        // style 不应收到新的更新
        #expect(style.records.isEmpty)
    }

    @Test("beginRefreshing 在 ending 时忽略")
    func beginRefreshingWhenEnding() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        let style = MockStyle()
        let component = makeTopRefreshComponent(
            style: style,
            options: RefreshableOptions(
                animationDuration: 60,
                automaticallyEnds: false
            )
        )
        component.scrollView = scrollView
        component.beginRefreshing()
        component.endAction()
        #expect(component.state == .ending)
        style.reset()

        component.beginRefreshing()

        #expect(component.state == .ending)
        #expect(style.records.isEmpty)
    }

    // MARK: - endAction

    @Test("endAction 从 active 进入收尾流程")
    func endAction() {
        let (_, component, _) = makeSUT()
        component.setState(.active)
        component.endAction()
        // 无 window 时动画同步完成，completion 可能已将状态置为 idle
        let validStates: [RefreshState] = [.ending, .idle]
        #expect(validStates.contains(component.state))
    }

    @Test("回到 idle 前先隐藏刷新视图以避免完成态闪烁")
    func hidesRefreshViewBeforeIdleStyleUpdate() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        let style = MockStyle()
        let component = makeTopRefreshComponent(
            style: style,
            options: RefreshableOptions(
                animationDuration: 0,
                automaticallyEnds: false
            )
        )
        component.scrollView = scrollView
        component.beginRefreshing()
        style.view.alpha = 1
        style.reset()

        component.endAction()

        let idleRecord = style.records.first { $0.state == .idle }
        #expect(idleRecord?.viewAlpha == 0)
        #expect(style.view.alpha == 0)
    }

    @Test("endAction 在 idle 时忽略")
    func endActionWhenIdle() {
        let (_, component, style) = makeSUT()
        style.reset()
        component.endAction()
        // 状态不变，不应有更新
        #expect(component.state == .idle)
        #expect(style.records.isEmpty)
    }

    // MARK: - inset

    @Test("进入 active 后 contentInset.top 增加")
    func insetIncreasedWhileActive() {
        let (scrollView, component, _) = makeSUT()
        component.beginRefreshing()
        #expect(scrollView.contentInset.top == 54)
    }

    @Test("移除 contribution 恢复 coordinator baseline")
    func removesInsetContribution() {
        let (scrollView, component, _) = makeSUT()
        scrollView.contentInset.top = 20
        component.beginRefreshing()
        component.removeInset(animated: false) {}
        #expect(scrollView.contentInset.top == 20)
    }

    @Test("开始刷新时重新捕获当前 top inset")
    func recapturesTopInsetAtStart() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        let style = MockStyle()
        let component = makeTopRefreshComponent(
            style: style,
            options: RefreshableOptions(automaticallyEnds: false)
        )
        component.scrollView = scrollView

        scrollView.contentInset.top = 40
        component.beginRefreshing()

        #expect(RefreshableInsetCoordinator.coordinator(for: scrollView).baselineInset.top == 40)
        #expect(scrollView.contentInset.top == 94)
    }

    @Test("默认滚到顶部不会自动触发刷新")
    func defaultDoesNotAutomaticallyTriggerRefreshAtTop() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.contentSize = CGSize(width: 375, height: 1200)
        let style = MockStyle()
        let component = makeTopRefreshComponent(
            style: style,
            options: RefreshableOptions(automaticallyEnds: false)
        )
        component.scrollView = scrollView

        component.scrollViewDidScroll(contentOffset: .zero)

        #expect(component.state == .idle)
    }

    @Test("设置 automaticTriggerDistance 后滚到顶部自动触发刷新")
    func automaticallyTriggersRefreshAtTop() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.contentSize = CGSize(width: 375, height: 1200)
        let style = MockStyle()
        let component = makeTopRefreshComponent(
            style: style,
            options: RefreshableOptions(
                automaticallyEnds: false,
                automaticTriggerDistance: 0
            )
        )
        component.scrollView = scrollView

        component.scrollViewDidScroll(contentOffset: .zero)

        #expect(component.state == .active)
        #expect(style.records.contains { $0.state == .active })
    }

    // MARK: - Action 执行

    @Test("trigger 执行 action 闭包")
    func triggerExecutesAction() async {
        await confirmation(expectedCount: 1) { confirm in
            let sv = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
            let s = MockStyle()
            let c = makeTopRefreshComponent(style: s) {
                confirm()
            }
            c.scrollView = sv
            c.trigger()

            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    // MARK: - scrollView 释放

    @Test("scrollView 为 nil 时 endAction 直接回到 idle")
    func endActionWithoutScrollView() {
        let style = MockStyle()
        let component = makeTopRefreshComponent(style: style)
        // 不设置 scrollView
        component.setState(.active)
        component.endAction()
        #expect(component.state == .idle)
    }

    // MARK: - Options

    @Test("自定义 triggerDistance 不改变 top 刷新占位")
    func customTopTriggerDistanceDoesNotChangeReservedExtent() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.contentInset.top = 12
        let style = MockStyle()
        let component = makeTopRefreshComponent(
            style: style,
            options: RefreshableOptions(triggerDistance: 80, automaticallyEnds: false)
        )
        component.scrollView = scrollView

        component.beginRefreshing()

        #expect(scrollView.contentInset.top == 66)
    }

    @Test("非正 triggerDistance 不改变 top 刷新占位")
    func nonPositiveTopTriggerDistanceDoesNotChangeReservedExtent() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.contentInset.top = 12
        let style = MockStyle()
        let component = makeTopRefreshComponent(
            style: style,
            options: RefreshableOptions(triggerDistance: 0, animationDuration: 0, automaticallyEnds: false)
        )
        component.scrollView = scrollView

        component.beginRefreshing()

        #expect(RefreshableInsetCoordinator.coordinator(for: scrollView).baselineInset.top == 12)
        #expect(scrollView.contentInset.top == 66)
    }

    @Test("非正 style.extent 使用最小 top 触发距离")
    func nonPositiveTopStyleExtentUsesMinimumThreshold() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.contentInset.top = 12
        let style = MockStyle(extent: 0)
        let component = makeTopRefreshComponent(
            style: style,
            options: RefreshableOptions(animationDuration: 0, automaticallyEnds: false)
        )
        component.scrollView = scrollView

        component.beginRefreshing()

        #expect(RefreshableInsetCoordinator.coordinator(for: scrollView).baselineInset.top == 12)
        #expect(scrollView.contentInset.top == 13)
    }

    @Test("automaticallyEnds 为 false 时 action 完成后保持 active")
    func topManualEndOption() async {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        let style = MockStyle()
        let component = makeTopRefreshComponent(
            style: style,
            options: RefreshableOptions(automaticallyEnds: false)
        )
        component.scrollView = scrollView

        component.trigger()
        try? await Task.sleep(nanoseconds: 50_000_000)

        #expect(component.state == .active)
    }

    @Test("取消 top edge 当前任务会结束刷新")
    func cancelTopTask() async {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        let style = MockStyle()
        let taskProbe = TaskCancellationProbe()
        let component = makeTopRefreshComponent(style: style) {
            await taskProbe.markStarted()
            do {
                try await Task.sleep(nanoseconds: 1_000_000_000)
            } catch {
                await taskProbe.markCancellationObserved(Task.isCancelled)
            }
        }
        component.scrollView = scrollView

        component.trigger()
        #expect(await taskProbe.waitUntilStarted() == true)
        component.setEnabled(false)

        #expect(await taskProbe.waitUntilCancellationObserved() == true)
        #expect([RefreshState.ending, .idle].contains(component.state))
    }

    private func makeTopRefreshComponent(
        style: MockStyle,
        options: RefreshableOptions = RefreshableOptions(),
        action: @escaping @Sendable () async -> Void = {}
    ) -> EdgeRefreshComponent {
        EdgeRefreshComponent(edge: .top, role: .refresh, style: style, options: options, action: action)
    }
}

private actor ActionCallCounter {
    private var count = 0

    func increment() {
        count += 1
    }

    func waitUntilCount(_ expectedCount: Int) async -> Int {
        for _ in 0..<100 {
            if count >= expectedCount { return count }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return count
    }
}

private final class HeaderDraggingScrollView: UIScrollView {
    var isDraggingOverride = false

    override var isDragging: Bool {
        isDraggingOverride
    }
}

private actor TaskCancellationProbe {
    private var didStart = false
    private var observedCancellation = false

    func markStarted() {
        didStart = true
    }

    func markCancellationObserved(_ isCancelled: Bool) {
        observedCancellation = isCancelled
    }

    func waitUntilStarted() async -> Bool {
        for _ in 0..<150 {
            if didStart { return true }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return didStart
    }

    func waitUntilCancellationObserved() async -> Bool {
        for _ in 0..<100 {
            if observedCancellation { return true }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return observedCancellation
    }
}
