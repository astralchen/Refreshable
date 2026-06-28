import Testing
@testable import Refreshable
import UIKit

@Suite("EdgeRefreshComponent")
@MainActor
struct EdgeRefreshComponentTests {

    @Test("refreshable(edge: .leading) 在 LTR 下安装到左侧")
    func leadingRefreshInstallsOnLeftInLTR() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        scrollView.semanticContentAttribute = .forceLeftToRight
        scrollView.contentSize = CGSize(width: 1000, height: 480)
        let style = MockStyle(extent: 44)

        scrollView.refreshable(
            edge: .leading,
            style: style,
            options: RefreshableOptions(animationDuration: 0)
        ) {}

        let component = scrollView.component(for: .leading)
        #expect(component?.edge == .leading)
        #expect(component?.role == .refresh)
        #expect(style.view.frame == CGRect(x: -44, y: 0, width: 44, height: 480))
        #expect(style.view.autoresizingMask == [.flexibleHeight])
    }

    @Test("beginRefreshing(edge: .leading) 只调整 left inset 和 x offset")
    func beginLeadingRefreshUsesHorizontalAxis() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        scrollView.semanticContentAttribute = .forceLeftToRight
        scrollView.contentInset = UIEdgeInsets(top: 20, left: 6, bottom: 12, right: 8)
        let style = MockStyle(extent: 44)

        scrollView.refreshable(
            edge: .leading,
            style: style,
            options: RefreshableOptions(animationDuration: 0, automaticallyEndRefreshing: false)
        ) {}
        scrollView.beginRefreshing(edge: .leading)

        #expect(scrollView.refreshState(edge: .leading) == .refreshing)
        #expect(scrollView.contentInset.top == 20)
        #expect(scrollView.contentInset.left == 50)
        #expect(scrollView.contentInset.bottom == 12)
        #expect(scrollView.contentInset.right == 8)
        #expect(scrollView.contentOffset.x == -50)
    }

    @Test("loadMoreable(edge: .trailing) 使用 right inset 并支持 noMoreData")
    func trailingLoadMoreUsesRightInsetAndNoMoreData() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        scrollView.semanticContentAttribute = .forceLeftToRight
        scrollView.contentSize = CGSize(width: 1000, height: 480)
        scrollView.contentInset.right = 10
        let style = MockStyle(extent: 48)

        scrollView.loadMoreable(
            edge: .trailing,
            style: style,
            options: RefreshableOptions(animationDuration: 0, automaticallyEndRefreshing: false)
        ) {}
        scrollView.beginLoadingMore(edge: .trailing)

        #expect(scrollView.loadMoreState(edge: .trailing) == .refreshing)
        #expect(scrollView.contentInset.right == 58)

        scrollView.noMoreData(edge: .trailing)

        #expect(scrollView.contentInset.right == 10)
        #expect(scrollView.loadMoreState(edge: .trailing) == .noMoreData)
    }

    @Test("loadMore 可在 action 执行期间不保持占位 UI")
    func loadMoreCanAvoidPersistentInsetWhileActionRuns() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        scrollView.contentSize = CGSize(width: 320, height: 1200)
        scrollView.contentInset.bottom = 12
        let style = MockStyle(extent: 76)

        scrollView.loadMoreable(
            edge: .bottom,
            style: style,
            options: RefreshableOptions(
                animationDuration: 0,
                automaticallyEndRefreshing: false,
                keepsRefreshViewVisibleDuringAction: false
            )
        ) {}
        scrollView.beginLoadingMore(edge: .bottom)

        #expect(scrollView.loadMoreState(edge: .bottom) == .refreshing)
        #expect(scrollView.contentInset.bottom == 12)
        #expect(style.view.alpha == 0)
        #expect(style.lastState == .refreshing)
    }

    @Test("noMoreData(edge:) 对 refresh 组件无副作用")
    func noMoreDataIsNoOpForRefreshComponent() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let style = MockStyle()

        scrollView.refreshable(edge: .leading, style: style) {}
        scrollView.noMoreData(edge: .leading)

        #expect(scrollView.refreshState(edge: .leading) == .idle)
        #expect(style.lastState == .idle)
    }

    @Test("leading 和 trailing 在 RTL 下映射到相反物理边")
    func leadingAndTrailingResolveWithRTLLayoutDirection() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        scrollView.semanticContentAttribute = .forceRightToLeft
        scrollView.contentSize = CGSize(width: 1000, height: 480)
        let leadingStyle = MockStyle(extent: 40)
        let trailingStyle = MockStyle(extent: 50)

        scrollView.refreshable(edge: .leading, style: leadingStyle) {}
        scrollView.loadMoreable(edge: .trailing, style: trailingStyle) {}

        #expect(leadingStyle.view.frame.origin.x == 1000)
        #expect(leadingStyle.view.frame.width == 40)
        #expect(trailingStyle.view.frame.origin.x == -50)
        #expect(trailingStyle.view.frame.width == 50)
    }

    @Test("刷新中切换布局方向后仍恢复原本占用的物理 inset")
    func changingLayoutDirectionWhileRefreshingRestoresOriginalPhysicalInset() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        scrollView.semanticContentAttribute = .forceLeftToRight
        scrollView.contentInset = UIEdgeInsets(top: 20, left: 6, bottom: 12, right: 8)
        let style = MockStyle(extent: 44)

        scrollView.refreshable(
            edge: .leading,
            style: style,
            options: RefreshableOptions(animationDuration: 0, automaticallyEndRefreshing: false)
        ) {}
        scrollView.beginRefreshing(edge: .leading)
        scrollView.semanticContentAttribute = .forceRightToLeft
        scrollView.endRefreshing(edge: .leading)

        #expect(scrollView.contentInset.left == 6)
        #expect(scrollView.contentInset.right == 8)
    }

    @Test("移除一个 edge 不污染其他 edge 的 inset")
    func removingOneEdgePreservesOtherEdgeInset() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        scrollView.semanticContentAttribute = .forceLeftToRight
        scrollView.contentSize = CGSize(width: 1000, height: 1000)
        scrollView.contentInset = UIEdgeInsets(top: 20, left: 6, bottom: 12, right: 8)
        let topStyle = MockStyle()
        let trailingStyle = MockStyle()

        scrollView.refreshable(
            edge: .top,
            style: topStyle,
            options: RefreshableOptions(animationDuration: 0, automaticallyEndRefreshing: false)
        ) {}
        scrollView.loadMoreable(
            edge: .trailing,
            style: trailingStyle,
            options: RefreshableOptions(animationDuration: 0, automaticallyEndRefreshing: false)
        ) {}

        scrollView.beginRefreshing(edge: .top)
        scrollView.beginLoadingMore(edge: .trailing)
        #expect(scrollView.contentInset.top == 74)
        #expect(scrollView.contentInset.right == 62)

        scrollView.removeLoadMoreable(edge: .trailing)

        #expect(scrollView.component(for: .trailing) == nil)
        #expect(scrollView.contentInset.top == 74)
        #expect(scrollView.contentInset.right == 8)

        scrollView.removeRefreshable(edge: .top)

        #expect(scrollView.component(for: .top) == nil)
        #expect(scrollView.contentInset.top == 20)
    }

    @Test("trailing loadMore 按水平内容是否填满判断触发")
    func trailingLoadMoreUsesHorizontalContentFit() {
        let scrollView = EdgeDraggingScrollView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        scrollView.semanticContentAttribute = .forceLeftToRight
        scrollView.contentSize = CGSize(width: 100, height: 480)
        scrollView.isDraggingOverride = true

        scrollView.loadMoreable(
            edge: .trailing,
            style: MockStyle(),
            options: RefreshableOptions(animationDuration: 0)
        ) {}
        scrollView.component(for: .trailing)?.scrollViewDidScroll(contentOffset: CGPoint(x: 200, y: 0))
        #expect(scrollView.loadMoreState(edge: .trailing) == .idle)

        scrollView.loadMoreable(
            edge: .trailing,
            style: MockStyle(),
            options: RefreshableOptions(animationDuration: 0, allowsLoadMoreWhenContentFits: true)
        ) {}
        scrollView.component(for: .trailing)?.scrollViewDidScroll(contentOffset: CGPoint(x: 200, y: 0))
        #expect(scrollView.loadMoreState(edge: .trailing) == .triggered)
    }
}

private final class EdgeDraggingScrollView: UIScrollView {
    var isDraggingOverride = false

    override var isDragging: Bool {
        isDraggingOverride
    }
}
