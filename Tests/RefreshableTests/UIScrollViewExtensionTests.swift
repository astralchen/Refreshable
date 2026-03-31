import Testing
@testable import Refreshable
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
        #expect(scrollView.headerComponent?.style === style)
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
        #expect(scrollView.headerComponent?.style === style2)
        // 旧 style view 应已从 superview 移除
        #expect(style1.view.superview == nil)
    }

    @Test("beginRefreshing 转发到 headerComponent")
    func beginRefreshing() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.refreshable { }
        scrollView.beginRefreshing()
        #expect(scrollView.headerComponent?.state == .refreshing)
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

    @Test("loadMoreable 自定义 style")
    func loadMoreableCustomStyle() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        let style = MockStyle()
        scrollView.loadMoreable(style: style) { }
        #expect(scrollView.footerComponent?.style === style)
    }

    @Test("重复调用 loadMoreable 替换旧组件")
    func loadMoreableReplacesOld() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        let style1 = MockStyle()
        scrollView.loadMoreable(style: style1) { }

        let style2 = MockStyle()
        scrollView.loadMoreable(style: style2) { }

        #expect(scrollView.footerComponent?.style === style2)
        #expect(style1.view.superview == nil)
    }

    @Test("beginLoadingMore 转发到 footerComponent")
    func beginLoadingMore() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.loadMoreable { }
        scrollView.beginLoadingMore()
        #expect(scrollView.footerComponent?.state == .refreshing)
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
}
