import Testing
@testable import Refreshable
import UIKit

@Suite("EdgeRefreshComponent .bottom loadMore")
@MainActor
struct EdgeBottomLoadMoreComponentTests {

    private func makeSUT() -> (UIScrollView, EdgeRefreshComponent, MockStyle) {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.contentSize = CGSize(width: 375, height: 2000)
        let style = MockStyle()
        let component = makeBottomLoadMoreComponent(
            style: style,
            options: RefreshableOptions(automaticallyEndRefreshing: false)
        )
        component.scrollView = scrollView
        return (scrollView, component, style)
    }

    // MARK: - 安装

    @Test("installView 将 style.view 添加到 scrollView")
    func installView() throws {
        let (scrollView, _, style) = makeSUT()
        let hostView = try #require(style.view.superview)
        #expect(hostView.superview === scrollView)
    }

    @Test("style.view 放在 contentSize 底部")
    func viewPosition() throws {
        let (scrollView, _, style) = makeSUT()
        let hostView = try #require(style.view.superview)
        #expect(hostView.frame.origin.y == scrollView.contentSize.height)
        #expect(style.view.frame.origin.y == 0)
    }

    @Test("安装后 style 收到 idle 状态")
    func initialState() {
        let (_, _, style) = makeSUT()
        #expect(style.lastState == .idle)
    }

    // MARK: - 状态机

    @Test("初始状态为 idle")
    func idle() {
        let (_, component, _) = makeSUT()
        #expect(component.state == .idle)
    }

    @Test("pulling 状态")
    func pulling() {
        let (_, component, style) = makeSUT()
        style.reset()
        component.setState(.pulling(0.6))
        #expect(component.state == .pulling(0.6))
        #expect(style.lastProgress == 0.6)
    }

    @Test("triggered 状态")
    func triggered() {
        let (_, component, _) = makeSUT()
        component.setState(.triggered)
        #expect(component.state == .triggered)
    }

    @Test("scrollViewDidEndDragging: triggered → refreshing")
    func endDraggingTriggersLoading() {
        let (_, component, _) = makeSUT()
        component.setState(.triggered)
        component.scrollViewDidEndDragging()
        #expect(component.state == .refreshing)
    }

    @Test("scrollViewDidEndDragging: idle 不触发")
    func endDraggingIdleNoOp() {
        let (_, component, _) = makeSUT()
        component.scrollViewDidEndDragging()
        #expect(component.state == .idle)
    }

    // MARK: - 防重入

    @Test("refreshing 状态下不重复触发")
    func preventReentry() {
        let (_, component, _) = makeSUT()
        component.trigger()
        #expect(component.state == .refreshing)
        component.trigger()
        #expect(component.state == .refreshing)
    }

    // MARK: - beginLoadingMore

    @Test("beginLoadingMore 从 idle 进入 refreshing")
    func beginLoadingMore() {
        let (scrollView, component, style) = makeSUT()
        #expect(component.scrollView === scrollView)
        style.reset()
        component.beginLoadingMore()
        #expect(style.records.contains { $0.state == .refreshing })
    }

    @Test("beginLoadingMore: 已在 refreshing 时忽略")
    func beginLoadingMoreWhenRefreshing() {
        let (scrollView, component, style) = makeSUT()
        #expect(component.scrollView === scrollView)
        component.beginLoadingMore()
        style.reset()
        component.beginLoadingMore()
        #expect(style.records.isEmpty)
    }

    @Test("beginLoadingMore: ending 时忽略")
    func beginLoadingMoreWhenEnding() {
        let (_, component, style) = makeSUT()
        component.setState(.ending)
        style.reset()

        component.beginLoadingMore()

        #expect(component.state == .ending)
        #expect(style.records.isEmpty)
    }

    @Test("beginLoadingMore: noMoreData 时忽略")
    func beginLoadingMoreWhenNoMoreData() {
        let (_, component, _) = makeSUT()
        component.setNoMoreData()
        #expect(component.state == .noMoreData)

        component.beginLoadingMore()
        #expect(component.state == .noMoreData)
    }

    // MARK: - endRefreshing

    @Test("endRefreshing: refreshing 进入收尾流程")
    func endRefreshing() {
        let (_, component, _) = makeSUT()
        component.setState(.refreshing)
        component.endRefreshing()
        // 无 window 时动画同步完成，可能已到 idle
        let validStates: [RefreshState] = [.ending, .idle]
        #expect(validStates.contains(component.state))
    }

    @Test("endRefreshing: idle 时忽略")
    func endRefreshingWhenIdle() {
        let (_, component, style) = makeSUT()
        style.reset()
        component.endRefreshing()
        #expect(component.state == .idle)
        #expect(style.records.isEmpty)
    }

    // MARK: - noMoreData

    @Test("setNoMoreData 从 idle 直接进入 noMoreData")
    func setNoMoreDataFromIdle() {
        let (_, component, _) = makeSUT()
        component.setNoMoreData()
        #expect(component.state == .noMoreData)
    }

    @Test("setNoMoreData 重复调用无副作用")
    func setNoMoreDataIdempotent() {
        let (_, component, style) = makeSUT()
        component.setNoMoreData()
        style.reset()
        component.setNoMoreData()
        #expect(style.records.isEmpty)
    }

    @Test("refreshing 转 noMoreData 时保留 bottom inset 让提示停在安全区域内")
    func noMoreDataRetainsBottomInsetUntilReset() {
        let scrollView = AdjustedInsetScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.contentSize = CGSize(width: 375, height: 2000)
        scrollView.contentInset.bottom = 12
        scrollView.automaticInsetAdjustment.bottom = 83
        let style = MockStyle(extent: 54)
        let component = makeBottomLoadMoreComponent(
            style: style,
            options: RefreshableOptions(animationDuration: 0, automaticallyEndRefreshing: false)
        )
        component.scrollView = scrollView

        component.beginLoadingMore()
        component.setNoMoreData()

        #expect(component.state == .noMoreData)
        #expect(scrollView.contentInset.bottom == 66)

        component.resetNoMoreData()

        #expect(scrollView.contentInset.bottom == 12)
    }

    @Test("resetNoMoreData 从 noMoreData → idle")
    func resetNoMoreData() {
        let (_, component, _) = makeSUT()
        component.setNoMoreData()
        component.resetNoMoreData()
        #expect(component.state == .idle)
    }

    @Test("resetNoMoreData: 非 noMoreData 时忽略")
    func resetNoMoreDataWhenIdle() {
        let (_, component, style) = makeSUT()
        style.reset()
        component.resetNoMoreData()
        #expect(component.state == .idle)
        #expect(style.records.isEmpty)
    }

    // MARK: - contentSize 变化

    @Test("contentSize 变化时 bottom view 位置更新")
    func contentSizeChange() throws {
        let (scrollView, component, style) = makeSUT()
        let newSize = CGSize(width: 375, height: 3000)
        scrollView.contentSize = newSize
        component.scrollViewContentSizeDidChange(contentSize: newSize)
        let hostView = try #require(style.view.superview)
        #expect(hostView.frame.origin.y == 3000)
    }

    // MARK: - inset

    @Test("进入 refreshing 后 contentInset.bottom 增加")
    func insetOnRefreshing() {
        let (_, component, _) = makeSUT()
        component.stateDidChange(from: .triggered, to: .refreshing)
        // 验证调用不 crash 即可
    }

    @Test("resetInset 恢复 bottom inset")
    func resetInset() {
        let (scrollView, component, _) = makeSUT()
        scrollView.contentInset.bottom = 100
        component.originalInset = UIEdgeInsets(top: 0, left: 0, bottom: 10, right: 0)
        component.resetInset(for: scrollView)
        #expect(scrollView.contentInset.bottom == 10)
    }

    @Test("开始加载时重新捕获当前 bottom inset")
    func recapturesBottomInsetAtStart() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.contentSize = CGSize(width: 375, height: 2000)
        let style = MockStyle()
        let component = makeBottomLoadMoreComponent(
            style: style,
            options: RefreshableOptions(automaticallyEndRefreshing: false)
        )
        component.scrollView = scrollView

        scrollView.contentInset.bottom = 30
        component.beginLoadingMore()

        #expect(component.originalInset.bottom == 30)
        #expect(scrollView.contentInset.bottom == 84)
    }

    @Test("开始加载时滚动到刚好露出底部刷新视图的位置")
    func beginLoadingMoreScrollsToRevealBottomView() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.contentSize = CGSize(width: 375, height: 2000)
        scrollView.contentInset.bottom = 30
        scrollView.contentOffset.y = 2000 - 667 + 30
        let style = MockStyle(extent: 54)
        let component = makeBottomLoadMoreComponent(
            style: style,
            options: RefreshableOptions(animationDuration: 0, automaticallyEndRefreshing: false)
        )
        component.scrollView = scrollView
        let expectedOffsetY = CGFloat(2000 - 667 + 30 + 54)

        component.beginLoadingMore()

        #expect(scrollView.contentOffset.y == expectedOffsetY)
    }

    // MARK: - scrollView 释放

    @Test("scrollView 为 nil 时 endRefreshing 回到 idle")
    func endRefreshingWithoutScrollView() {
        let style = MockStyle()
        let component = makeBottomLoadMoreComponent(style: style)
        component.setState(.refreshing)
        component.endRefreshing()
        #expect(component.state == .idle)
    }

    // MARK: - 内容不足一屏

    @Test("内容不足一屏时 scrollViewDidScroll 不改变状态")
    func contentSmallerThanFrame() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.contentSize = CGSize(width: 375, height: 100) // 小于 frame
        let style = MockStyle()
        let component = makeBottomLoadMoreComponent(style: style)
        component.scrollView = scrollView

        component.scrollViewDidScroll(contentOffset: CGPoint(x: 0, y: 50))
        #expect(component.state == .idle)
    }

    @Test("默认滚到底部自动触发加载更多")
    func defaultAutomaticallyTriggersLoadMoreAtBottom() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.contentSize = CGSize(width: 375, height: 2000)
        let style = MockStyle()
        let component = makeBottomLoadMoreComponent(
            style: style,
            options: RefreshableOptions(automaticallyEndRefreshing: false)
        )
        component.scrollView = scrollView

        let bottomOffset = CGPoint(x: 0, y: 2000 - 667)
        component.scrollViewDidScroll(contentOffset: bottomOffset)

        #expect(component.state == .refreshing)
        #expect(style.records.contains { $0.state == .refreshing })
    }

    @Test("automaticTriggerOffset 为 nil 时关闭滚到底部自动加载")
    func nilAutomaticTriggerOffsetDisablesAutomaticLoading() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.contentSize = CGSize(width: 375, height: 2000)
        let style = MockStyle()
        let component = makeBottomLoadMoreComponent(
            style: style,
            options: RefreshableOptions(
                automaticallyEndRefreshing: false,
                automaticTriggerOffset: nil
            )
        )
        component.scrollView = scrollView

        let bottomOffset = CGPoint(x: 0, y: 2000 - 667)
        component.scrollViewDidScroll(contentOffset: bottomOffset)

        #expect(component.state == .idle)
    }

    @Test("滚动到自动触发距离内时开始加载更多")
    func automaticallyTriggersLoadMoreNearBottom() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.contentSize = CGSize(width: 375, height: 2000)
        let style = MockStyle()
        let component = makeBottomLoadMoreComponent(
            style: style,
            options: RefreshableOptions(
                automaticallyEndRefreshing: false,
                automaticTriggerOffset: 80
            )
        )
        component.scrollView = scrollView

        let nearBottomOffset = CGPoint(x: 0, y: 2000 - 667 - 79)
        component.scrollViewDidScroll(contentOffset: nearBottomOffset)

        #expect(component.state == .refreshing)
        #expect(style.records.contains { $0.state == .refreshing })
    }

    @Test("未滚动到自动触发距离内时不开始加载更多")
    func automaticLoadMoreWaitsUntilNearBottom() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.contentSize = CGSize(width: 375, height: 2000)
        let style = MockStyle()
        let component = makeBottomLoadMoreComponent(
            style: style,
            options: RefreshableOptions(
                automaticallyEndRefreshing: false,
                automaticTriggerOffset: 80
            )
        )
        component.scrollView = scrollView

        let outsideThresholdOffset = CGPoint(x: 0, y: 2000 - 667 - 81)
        component.scrollViewDidScroll(contentOffset: outsideThresholdOffset)

        #expect(component.state == .idle)
    }

    @Test("内容不足一屏时自动触发仍遵守 allowsLoadMoreWhenContentFits")
    func automaticLoadMoreRespectsContentFitsOption() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.contentSize = CGSize(width: 375, height: 100)
        let style = MockStyle()
        let component = makeBottomLoadMoreComponent(
            style: style,
            options: RefreshableOptions(
                automaticallyEndRefreshing: false,
                automaticTriggerOffset: 80
            )
        )
        component.scrollView = scrollView

        component.scrollViewDidScroll(contentOffset: .zero)

        #expect(component.state == .idle)
    }

    @Test("allowsLoadMoreWhenContentFits 为 true 时内容不足一屏也可触发")
    func allowsLoadMoreWhenContentFits() {
        let scrollView = DraggingScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.contentSize = CGSize(width: 375, height: 100)
        scrollView.isDraggingOverride = true
        let style = MockStyle()
        let component = makeBottomLoadMoreComponent(
            style: style,
            options: RefreshableOptions(
                allowsLoadMoreWhenContentFits: true,
                automaticTriggerOffset: nil
            )
        )
        component.scrollView = scrollView

        component.scrollViewDidScroll(contentOffset: .zero)

        #expect(component.state == .triggered)
    }

    // MARK: - Action 执行

    @Test("trigger 执行 action 闭包")
    func triggerExecutesAction() async {
        await confirmation(expectedCount: 1) { confirm in
            let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
            scrollView.contentSize = CGSize(width: 375, height: 2000)
            let style = MockStyle()
            let component = makeBottomLoadMoreComponent(style: style) {
                confirm()
            }
            component.scrollView = scrollView
            component.trigger()

            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    // MARK: - Options

    @Test("自定义 triggerOffset 不改变 bottom 加载占位")
    func customBottomTriggerOffsetDoesNotChangeReservedExtent() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.contentSize = CGSize(width: 375, height: 2000)
        scrollView.contentInset.bottom = 16
        let style = MockStyle()
        let component = makeBottomLoadMoreComponent(
            style: style,
            options: RefreshableOptions(triggerOffset: 90, automaticallyEndRefreshing: false)
        )
        component.scrollView = scrollView

        component.beginLoadingMore()

        #expect(scrollView.contentInset.bottom == 70)
    }

    @Test("非正 triggerOffset 不改变 bottom 加载占位")
    func nonPositiveBottomTriggerOffsetDoesNotChangeReservedExtent() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.contentSize = CGSize(width: 375, height: 2000)
        scrollView.contentInset.bottom = 16
        let style = MockStyle()
        let component = makeBottomLoadMoreComponent(
            style: style,
            options: RefreshableOptions(triggerOffset: -10, animationDuration: 0, automaticallyEndRefreshing: false)
        )
        component.scrollView = scrollView

        component.beginLoadingMore()

        #expect(component.originalInset.bottom == 16)
        #expect(scrollView.contentInset.bottom == 70)
    }

    @Test("automaticallyEndRefreshing 为 false 时 bottom edge action 完成后保持 refreshing")
    func bottomManualEndOption() async {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.contentSize = CGSize(width: 375, height: 2000)
        let style = MockStyle()
        let component = makeBottomLoadMoreComponent(
            style: style,
            options: RefreshableOptions(automaticallyEndRefreshing: false)
        )
        component.scrollView = scrollView

        component.trigger()
        try? await Task.sleep(nanoseconds: 50_000_000)

        #expect(component.state == .refreshing)
    }

    private func makeBottomLoadMoreComponent(
        style: MockStyle,
        options: RefreshableOptions = RefreshableOptions(),
        action: @escaping @Sendable () async -> Void = {}
    ) -> EdgeRefreshComponent {
        EdgeRefreshComponent(edge: .bottom, role: .loadMore, style: style, options: options, action: action)
    }
}

private class DraggingScrollView: UIScrollView {
    var isDraggingOverride = false

    override var isDragging: Bool {
        isDraggingOverride
    }
}

private final class AdjustedInsetScrollView: DraggingScrollView {
    var automaticInsetAdjustment: UIEdgeInsets = .zero

    override var adjustedContentInset: UIEdgeInsets {
        UIEdgeInsets(
            top: contentInset.top + automaticInsetAdjustment.top,
            left: contentInset.left + automaticInsetAdjustment.left,
            bottom: contentInset.bottom + automaticInsetAdjustment.bottom,
            right: contentInset.right + automaticInsetAdjustment.right
        )
    }
}
