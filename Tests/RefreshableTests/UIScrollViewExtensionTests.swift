import Testing
@testable import Refreshable
import Dispatch
import UIKit

@Suite("UIScrollView+Refreshable")
@MainActor
struct UIScrollViewExtensionTests {

    // MARK: - refreshable

    @Test("refreshable 设置 headerComponent")
    func refreshableSetsHeader() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.refreshable { }
        #expect(scrollView.headerComponent != nil)
    }

    @Test("refreshable 自定义 style")
    func refreshableCustomStyle() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        let style = MockStyle()
        scrollView.refreshable(style: style) { }
        #expect(scrollView.headerComponent != nil)
        #expect((scrollView.headerComponent?.style as? MockStyle) === style)
    }

    @Test("重复调用 refreshable 替换旧组件")
    func refreshableReplacesOld() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        let style1 = MockStyle()
        scrollView.refreshable(style: style1) { }
        let first = scrollView.headerComponent

        let style2 = MockStyle()
        scrollView.refreshable(style: style2) { }
        let second = scrollView.headerComponent

        #expect(first !== second)
        #expect((scrollView.headerComponent?.style as? MockStyle) === style2)
        // 旧 style view 应已从 superview 移除
        #expect(style1.view.superview == nil)
    }

    @Test("刷新中替换 header 会恢复 top inset")
    func replacingRefreshingHeaderRestoresInset() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.contentInset.top = 20
        let style1 = MockStyle()
        scrollView.refreshable(
            style: style1,
            options: RefreshableOptions(animationDuration: 0, automaticallyEndRefreshing: false)
        ) {}
        scrollView.beginRefreshing()
        #expect(scrollView.contentInset.top == 74)

        let style2 = MockStyle()
        scrollView.refreshable(
            style: style2,
            options: RefreshableOptions(animationDuration: 0, automaticallyEndRefreshing: false)
        ) {}

        #expect(style1.view.superview == nil)
        #expect(scrollView.contentInset.top == 20)
        #expect(RefreshableInsetCoordinator.coordinator(for: scrollView).baselineInset.top == 20)
    }

    @Test("beginRefreshing 转发到 headerComponent")
    func beginRefreshing() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.refreshable { }
        scrollView.beginRefreshing()
        #expect(scrollView.headerComponent?.state == .refreshing)
    }

    @Test("refreshable action 可在后台语义下执行")
    func refreshableActionCanRunWithBackgroundSemantics() async {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        let probe = SendableActionProbe()
        let action = makeMainActorSignalAction(probe: probe)

        scrollView.refreshable(options: RefreshableOptions(animationDuration: 0), action: action)
        scrollView.beginRefreshing()

        #expect(await probe.waitUntilRun() == true)
        #expect(await probe.didSignalMainActor() == true)
        for _ in 0..<100 where scrollView.refreshState != .idle {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        #expect(scrollView.refreshState == .idle)
    }

    @Test("默认横向无文字刷新保留 54pt 触发距离、54pt 显示空间和 8pt 外侧留白")
    func defaultHorizontalRefreshUsesCompactDisplayExtentWithDefaultTriggerOffset() throws {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 844, height: 390))
        scrollView.semanticContentAttribute = .forceLeftToRight
        scrollView.contentSize = CGSize(width: 1600, height: 390)

        scrollView.refreshable(
            edge: .leading,
            options: RefreshableOptions(animationDuration: 0, automaticallyEndRefreshing: false)
        ) {}

        let component = scrollView.component(for: .leading)
        #expect(component?.options.triggerOffset == nil)
        #expect(component?.resolvedOptions.triggerOffset == 54)
        #expect(component?.options.placement == nil)
        #expect(component?.resolvedOptions.placement.outerSpacing == 8)
        #expect(component?.style.extent == 54)
        let styleView = try #require(component?.renderer.view)
        let hostView = try #require(styleView.superview)
        #expect(hostView.frame == CGRect(x: -62, y: 0, width: 844, height: 390))
        #expect(styleView.frame == CGRect(x: 8, y: 0, width: 54, height: 390))

        scrollView.beginRefreshing(edge: .leading)

        #expect(scrollView.contentInset.left == 62)
        #expect(scrollView.contentOffset.x == -62)
    }

    @Test("所有无样式 edge 与 role 路由都安装 unified default style")
    func allNoStyleRoutesInstallDefaultRefreshControlStyle() {
        for edge in RefreshableEdge.allCases {
            let refreshScrollView = UIScrollView()
            refreshScrollView.refreshable(
                edge: edge,
                options: RefreshableOptions(textConfiguration: RefreshableTextConfiguration(idle: "Refresh"))
            ) {}
            let refreshComponent = refreshScrollView.component(for: edge)
            #expect(refreshComponent?.style is DefaultRefreshControlStyle)
            #expect(refreshComponent?.renderer.view.firstDefaultRouteLabel?.text == "Refresh")

            let loadMoreScrollView = UIScrollView()
            loadMoreScrollView.loadMoreable(
                edge: edge,
                options: RefreshableOptions(textConfiguration: RefreshableTextConfiguration(idle: "Load"))
            ) {}
            let loadMoreComponent = loadMoreScrollView.component(for: edge)
            #expect(loadMoreComponent?.style is DefaultRefreshControlStyle)
            #expect(loadMoreComponent?.renderer.view.firstDefaultRouteLabel?.text == "Load")
        }
    }

    @Test("显式 custom style 忽略 non-nil textConfiguration 并保持对象身份")
    func customStyleIgnoresTextConfiguration() {
        let scrollView = UIScrollView()
        let refreshStyle = MockStyle()
        let loadMoreStyle = MockStyle()
        let options = RefreshableOptions(
            textConfiguration: RefreshableTextConfiguration(idle: "Must not be interpreted")
        )

        scrollView.refreshable(edge: .leading, style: refreshStyle, options: options) {}
        scrollView.loadMoreable(edge: .trailing, style: loadMoreStyle, options: options) {}

        #expect((scrollView.component(for: .leading)?.style as? MockStyle) === refreshStyle)
        #expect((scrollView.component(for: .trailing)?.style as? MockStyle) === loadMoreStyle)
    }

    @Test("endRefreshing 转发到 headerComponent")
    func endRefreshing() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.refreshable { }
        scrollView.beginRefreshing()
        scrollView.endRefreshing()
        let validStates: [RefreshState] = [.ending, .idle]
        #expect(validStates.contains(scrollView.headerComponent!.state))
    }

    @Test("无 header 时 beginRefreshing 不 crash")
    func beginRefreshingWithoutHeader() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.beginRefreshing() // 不应 crash
    }

    // MARK: - loadMoreable

    @Test("loadMoreable 设置 footerComponent")
    func loadMoreableSetsFooter() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.loadMoreable { }
        #expect(scrollView.footerComponent != nil)
    }

    @Test("默认底部 loadMoreable 滚到底部自动触发")
    func defaultBottomLoadMoreAutomaticallyTriggersAtBottom() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.contentSize = CGSize(width: 375, height: 2000)
        scrollView.loadMoreable { }

        scrollView.footerComponent?.scrollViewDidScroll(contentOffset: CGPoint(x: 0, y: 2000 - 667))

        #expect(scrollView.loadMoreState == .refreshing)
    }

    @Test("loadMoreable 自定义 style")
    func loadMoreableCustomStyle() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        let style = MockStyle()
        scrollView.loadMoreable(style: style) { }
        #expect((scrollView.footerComponent?.style as? MockStyle) === style)
    }

    @Test("重复调用 loadMoreable 替换旧组件")
    func loadMoreableReplacesOld() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        let style1 = MockStyle()
        scrollView.loadMoreable(style: style1) { }

        let style2 = MockStyle()
        scrollView.loadMoreable(style: style2) { }

        #expect((scrollView.footerComponent?.style as? MockStyle) === style2)
        #expect(style1.view.superview == nil)
    }

    @Test("加载中替换 footer 会恢复 bottom inset")
    func replacingLoadingFooterRestoresInset() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.contentSize = CGSize(width: 375, height: 2000)
        scrollView.contentInset.bottom = 12
        let style1 = MockStyle()
        scrollView.loadMoreable(
            style: style1,
            options: RefreshableOptions(animationDuration: 0, automaticallyEndRefreshing: false)
        ) {}
        scrollView.beginLoadingMore()
        #expect(scrollView.contentInset.bottom == 66)

        let style2 = MockStyle()
        scrollView.loadMoreable(
            style: style2,
            options: RefreshableOptions(animationDuration: 0, automaticallyEndRefreshing: false)
        ) {}

        #expect(style1.view.superview == nil)
        #expect(scrollView.contentInset.bottom == 12)
        #expect(RefreshableInsetCoordinator.coordinator(for: scrollView).baselineInset.bottom == 12)
    }

    @Test("noMoreData 状态替换 footer 会恢复 bottom inset")
    func replacingNoMoreDataFooterRestoresInset() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.contentSize = CGSize(width: 375, height: 2000)
        scrollView.contentInset.bottom = 12
        let style1 = MockStyle()
        scrollView.loadMoreable(
            style: style1,
            options: RefreshableOptions(animationDuration: 0, automaticallyEndRefreshing: false)
        ) {}
        scrollView.beginLoadingMore()
        scrollView.noMoreData()
        #expect(scrollView.contentInset.bottom == 66)

        let style2 = MockStyle()
        scrollView.loadMoreable(
            style: style2,
            options: RefreshableOptions(animationDuration: 0, automaticallyEndRefreshing: false)
        ) {}

        #expect(style1.view.superview == nil)
        #expect(scrollView.contentInset.bottom == 12)
        #expect(RefreshableInsetCoordinator.coordinator(for: scrollView).baselineInset.bottom == 12)
    }

    @Test("beginLoadingMore 转发到 footerComponent")
    func beginLoadingMore() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.loadMoreable { }
        scrollView.beginLoadingMore()
        #expect(scrollView.footerComponent?.state == .refreshing)
    }

    @Test("loadMoreable action 可显式切回 MainActor")
    func loadMoreableActionCanHopToMainActor() async {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        let probe = MainActorActionProbe()
        let action: @Sendable () async -> Void = {
            await MainActor.run {
                probe.mark()
            }
        }

        scrollView.loadMoreable(options: RefreshableOptions(animationDuration: 0), action: action)
        scrollView.beginLoadingMore()
        for _ in 0..<100 where probe.didRun == false {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }

        #expect(probe.didRun == true)
    }

    @Test("endLoadingMore 转发到 footerComponent")
    func endLoadingMore() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.loadMoreable { }
        scrollView.beginLoadingMore()
        scrollView.endLoadingMore()
        let validStates: [RefreshState] = [.ending, .idle]
        #expect(validStates.contains(scrollView.footerComponent!.state))
    }

    @Test("无 footer 时 beginLoadingMore 不 crash")
    func beginLoadingMoreWithoutFooter() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.beginLoadingMore()
    }

    // MARK: - noMoreData

    @Test("noMoreData 转发到 footerComponent")
    func noMoreData() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.loadMoreable { }
        scrollView.noMoreData()
        #expect(scrollView.footerComponent?.state == .noMoreData)
    }

    @Test("默认无文案 noMoreData 不保留不可见的 bottom inset")
    func defaultNoTextNoMoreDataDoesNotReserveInset() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.contentSize = CGSize(width: 375, height: 2000)
        scrollView.contentInset.bottom = 12
        scrollView.loadMoreable(
            options: RefreshableOptions(
                animationDuration: 0,
                automaticallyEndRefreshing: false,
                placement: RefreshablePlacement(contentSpacing: 6)
            )
        ) {}

        scrollView.beginLoadingMore()
        #expect(scrollView.contentInset.bottom == 72)

        scrollView.noMoreData()

        #expect(scrollView.loadMoreState == .noMoreData)
        #expect(scrollView.contentInset.bottom == 12)
        #expect(scrollView.contentOffset.y == 1345)
    }

    @Test("显式隐藏 noMoreData 文案不保留不可见的 bottom inset")
    func emptyNoMoreDataTextDoesNotReserveInset() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.contentSize = CGSize(width: 375, height: 2000)
        scrollView.contentInset.bottom = 12
        scrollView.loadMoreable(
            options: RefreshableOptions(
                animationDuration: 0,
                automaticallyEndRefreshing: false,
                placement: RefreshablePlacement(contentSpacing: 6),
                textConfiguration: RefreshableTextConfiguration(noMoreData: "")
            )
        ) {}

        scrollView.beginLoadingMore()
        #expect(scrollView.contentInset.bottom == 72)

        scrollView.noMoreData()

        #expect(scrollView.loadMoreState == .noMoreData)
        #expect(scrollView.contentInset.bottom == 12)
    }

    @Test("开启默认文案时 noMoreData 继续保留终态区域")
    func configuredNoMoreDataTextKeepsInsetVisible() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.contentSize = CGSize(width: 375, height: 2000)
        scrollView.contentInset.bottom = 12
        scrollView.loadMoreable(
            options: RefreshableOptions(
                animationDuration: 0,
                automaticallyEndRefreshing: false,
                placement: RefreshablePlacement(contentSpacing: 6),
                textConfiguration: RefreshableTextConfiguration()
            )
        ) {}

        scrollView.beginLoadingMore()
        scrollView.noMoreData()

        #expect(scrollView.loadMoreState == .noMoreData)
        #expect(scrollView.contentInset.bottom == 72)
    }

    @Test("resetNoMoreData 转发到 footerComponent")
    func resetNoMoreData() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.loadMoreable { }
        scrollView.noMoreData()
        scrollView.resetNoMoreData()
        #expect(scrollView.footerComponent?.state == .idle)
    }

    @Test("无 footer 时 noMoreData 不 crash")
    func noMoreDataWithoutFooter() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.noMoreData()
        scrollView.resetNoMoreData()
    }

    // MARK: - Header + Footer 共存

    @Test("可同时设置 header 和 footer")
    func bothHeaderAndFooter() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.refreshable { }
        scrollView.loadMoreable { }
        #expect(scrollView.headerComponent != nil)
        #expect(scrollView.footerComponent != nil)
    }

    @Test("header 和 footer 独立工作")
    func headerAndFooterIndependent() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.refreshable { }
        scrollView.loadMoreable { }

        scrollView.beginRefreshing()
        #expect(scrollView.headerComponent?.state == .refreshing)
        #expect(scrollView.footerComponent?.state == .idle)

        scrollView.endRefreshing()
        scrollView.beginLoadingMore()
        #expect(scrollView.footerComponent?.state == .refreshing)
    }

    // MARK: - UITableView / UICollectionView

    @Test("UITableView 也能使用 refreshable")
    func tableView() {
        let tableView = UITableView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        tableView.refreshable { }
        #expect(tableView.headerComponent != nil)
    }

    @Test("UICollectionView 也能使用 refreshable")
    func collectionView() {
        let layout = UICollectionViewFlowLayout()
        let cv = UICollectionView(frame: CGRect(x: 0, y: 0, width: 375, height: 667), collectionViewLayout: layout)
        cv.refreshable { }
        cv.loadMoreable { }
        #expect(cv.headerComponent != nil)
        #expect(cv.footerComponent != nil)
    }

    // MARK: - 状态查询

    @Test("公开查询 header 和 footer 状态")
    func publicStateQuery() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.contentSize = CGSize(width: 375, height: 2000)

        scrollView.refreshable(options: RefreshableOptions(automaticallyEndRefreshing: false)) {}
        scrollView.loadMoreable(options: RefreshableOptions(automaticallyEndRefreshing: false)) {}

        #expect(scrollView.refreshState == .idle)
        #expect(scrollView.loadMoreState == .idle)

        scrollView.beginRefreshing()
        scrollView.beginLoadingMore()

        #expect(scrollView.refreshState == .refreshing)
        #expect(scrollView.loadMoreState == .refreshing)
        #expect(scrollView.isRefreshActive == true)
        #expect(scrollView.isLoadMoreActive == true)
    }

    // MARK: - 运行时控制

    @Test("禁用 header 后 beginRefreshing 不触发")
    func disableHeaderPreventsBeginRefreshing() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.refreshable(options: RefreshableOptions(automaticallyEndRefreshing: false)) {}

        scrollView.setRefreshEnabled(false)
        scrollView.beginRefreshing()

        #expect(scrollView.refreshState == .idle)
    }

    @Test("禁用 footer 后 beginLoadingMore 不触发")
    func disableFooterPreventsBeginLoadingMore() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.contentSize = CGSize(width: 375, height: 2000)
        scrollView.loadMoreable(options: RefreshableOptions(automaticallyEndRefreshing: false)) {}

        scrollView.setLoadMoreEnabled(false)
        scrollView.beginLoadingMore()

        #expect(scrollView.loadMoreState == .idle)
    }

    @Test("removeRefreshable 移除 header 组件和视图")
    func removeRefreshable() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        let style = MockStyle()
        scrollView.refreshable(style: style, options: RefreshableOptions()) {}

        scrollView.removeRefreshable()

        #expect(scrollView.headerComponent == nil)
        #expect(style.view.superview == nil)
    }

    @Test("刷新中移除 header 会恢复 top inset")
    func removeRefreshableWhileRefreshingRestoresInset() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.contentInset.top = 20
        let style = MockStyle()
        scrollView.refreshable(
            style: style,
            options: RefreshableOptions(animationDuration: 0, automaticallyEndRefreshing: false)
        ) {}
        scrollView.beginRefreshing()
        #expect(scrollView.contentInset.top == 74)

        scrollView.removeRefreshable()

        #expect(scrollView.headerComponent == nil)
        #expect(style.view.superview == nil)
        #expect(scrollView.contentInset.top == 20)
    }

    @Test("removeLoadMoreable 移除 footer 组件和视图")
    func removeLoadMoreable() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        let style = MockStyle()
        scrollView.loadMoreable(style: style, options: RefreshableOptions()) {}

        scrollView.removeLoadMoreable()

        #expect(scrollView.footerComponent == nil)
        #expect(style.view.superview == nil)
    }

    @Test("加载中移除 footer 会恢复 bottom inset")
    func removeLoadMoreableWhileLoadingRestoresInset() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.contentSize = CGSize(width: 375, height: 2000)
        scrollView.contentInset.bottom = 12
        let style = MockStyle()
        scrollView.loadMoreable(
            style: style,
            options: RefreshableOptions(animationDuration: 0, automaticallyEndRefreshing: false)
        ) {}
        scrollView.beginLoadingMore()
        #expect(scrollView.contentInset.bottom == 66)

        scrollView.removeLoadMoreable()

        #expect(scrollView.footerComponent == nil)
        #expect(style.view.superview == nil)
        #expect(scrollView.contentInset.bottom == 12)
    }

    @Test("noMoreData 状态移除 footer 会恢复 bottom inset")
    func removeLoadMoreableWhileNoMoreDataRestoresInset() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.contentSize = CGSize(width: 375, height: 2000)
        scrollView.contentInset.bottom = 12
        let style = MockStyle()
        scrollView.loadMoreable(
            style: style,
            options: RefreshableOptions(animationDuration: 0, automaticallyEndRefreshing: false)
        ) {}
        scrollView.beginLoadingMore()
        scrollView.noMoreData()
        #expect(scrollView.contentInset.bottom == 66)

        scrollView.removeLoadMoreable()

        #expect(scrollView.footerComponent == nil)
        #expect(style.view.superview == nil)
        #expect(scrollView.contentInset.bottom == 12)
    }
}

private extension UIView {
    var firstDefaultRouteLabel: UILabel? {
        if let label = self as? UILabel {
            return label
        }
        for subview in subviews {
            if let label = subview.firstDefaultRouteLabel {
                return label
            }
        }
        return nil
    }
}

private actor SendableActionProbe {
    private var hasRun = false
    private var signaledMainActor: Bool?

    func mark(signaledMainActor: Bool) {
        hasRun = true
        self.signaledMainActor = signaledMainActor
    }

    func waitUntilRun() async -> Bool {
        for _ in 0..<100 {
            if hasRun { return true }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return hasRun
    }

    func didSignalMainActor() -> Bool? {
        signaledMainActor
    }
}

private func makeMainActorSignalAction(probe: SendableActionProbe) -> @Sendable () async -> Void {
    {
        let semaphore = DispatchSemaphore(value: 0)
        Task { @MainActor in
            semaphore.signal()
        }
        let signaled = waitForMainActorSignal(semaphore)
        await probe.mark(signaledMainActor: signaled)
    }
}

private func waitForMainActorSignal(_ semaphore: DispatchSemaphore) -> Bool {
    semaphore.wait(timeout: .now() + 2) == .success
}

@MainActor
private final class MainActorActionProbe {
    private(set) var didRun = false

    func mark() {
        didRun = true
    }
}
