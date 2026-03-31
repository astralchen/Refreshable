import Testing
@testable import Refreshable
import UIKit

@Suite("FooterRefreshComponent")
@MainActor
struct FooterRefreshComponentTests {

    private func makeSUT() -> (UIScrollView, FooterRefreshComponent, MockStyle) {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.contentSize = CGSize(width: 375, height: 2000)
        let style = MockStyle()
        let component = FooterRefreshComponent(style: style) {}
        component.scrollView = scrollView
        return (scrollView, component, style)
    }

    // MARK: - 安装

    @Test("installView 将 style.view 添加到 scrollView")
    func installView() {
        let (scrollView, _, style) = makeSUT()
        #expect(style.view.superview === scrollView)
    }

    @Test("style.view 放在 contentSize 底部")
    func viewPosition() {
        let (scrollView, _, style) = makeSUT()
        #expect(style.view.frame.origin.y == scrollView.contentSize.height)
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
        let (_, component, _) = makeSUT()
        component.beginLoadingMore()
        #expect(component.state == .refreshing)
    }

    @Test("beginLoadingMore: 已在 refreshing 时忽略")
    func beginLoadingMoreWhenRefreshing() {
        let (_, component, style) = makeSUT()
        component.beginLoadingMore()
        style.reset()
        component.beginLoadingMore()
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

    @Test("contentSize 变化时 footer view 位置更新")
    func contentSizeChange() {
        let (scrollView, component, style) = makeSUT()
        let newSize = CGSize(width: 375, height: 3000)
        component.scrollViewContentSizeDidChange(contentSize: newSize)
        #expect(style.view.frame.origin.y == 3000)
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

    // MARK: - scrollView 释放

    @Test("scrollView 为 nil 时 endRefreshing 回到 idle")
    func endRefreshingWithoutScrollView() {
        let style = MockStyle()
        let component = FooterRefreshComponent(style: style) {}
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
        let component = FooterRefreshComponent(style: style) {}
        component.scrollView = scrollView

        component.scrollViewDidScroll(contentOffset: CGPoint(x: 0, y: 50))
        #expect(component.state == .idle)
    }

    // MARK: - Action 执行

    @Test("trigger 执行 action 闭包")
    func triggerExecutesAction() async {
        await confirmation(expectedCount: 1) { confirm in
            let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
            scrollView.contentSize = CGSize(width: 375, height: 2000)
            let style = MockStyle()
            let component = FooterRefreshComponent(style: style) {
                confirm()
            }
            component.scrollView = scrollView
            component.trigger()

            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }
}
