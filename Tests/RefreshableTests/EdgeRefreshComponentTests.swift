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
        #expect(style.view.frame == CGRect(x: -44, y: 0, width: 320, height: 480))
        #expect(style.view.autoresizingMask == [.flexibleWidth, .flexibleHeight])
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
        scrollView.contentOffset.x = 1000 - 320 + 10
        let style = MockStyle(extent: 48)
        let expectedOffsetX = CGFloat(1000 - 320 + 10 + 48)

        scrollView.loadMoreable(
            edge: .trailing,
            style: style,
            options: RefreshableOptions(animationDuration: 0, automaticallyEndRefreshing: false)
        ) {}
        scrollView.beginLoadingMore(edge: .trailing)

        #expect(scrollView.loadMoreState(edge: .trailing) == .refreshing)
        #expect(scrollView.contentInset.right == 58)
        #expect(scrollView.contentOffset.x == expectedOffsetX)

        scrollView.noMoreData(edge: .trailing)

        #expect(scrollView.contentInset.right == 58)
        #expect(scrollView.loadMoreState(edge: .trailing) == .noMoreData)

        scrollView.resetNoMoreData(edge: .trailing)

        #expect(scrollView.contentInset.right == 10)
        #expect(scrollView.loadMoreState(edge: .trailing) == .idle)
    }

    @Test("bottom loadMore 露出位置避开自动安全区 inset")
    func bottomLoadMoreRevealOffsetIncludesAdjustedInset() {
        let scrollView = AdjustedInsetScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.contentSize = CGSize(width: 375, height: 2000)
        scrollView.contentInset.bottom = 12
        scrollView.automaticInsetAdjustment.bottom = 83
        scrollView.contentOffset.y = 2000 - 667 + 12 + 83
        let style = MockStyle(extent: 54)
        let expectedOffsetY = CGFloat(2000 - 667 + 12 + 83 + 54)

        scrollView.loadMoreable(
            edge: .bottom,
            style: style,
            options: RefreshableOptions(animationDuration: 0, automaticallyEndRefreshing: false)
        ) {}

        scrollView.beginLoadingMore(edge: .bottom)

        #expect(scrollView.contentInset.bottom == 66)
        #expect(scrollView.contentOffset.y == expectedOffsetY)
    }

    @Test("停在 adjusted bottom 边界时不误判为上拉加载")
    func adjustedBottomBoundaryDoesNotStartPulling() {
        let scrollView = AdjustedInsetScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        scrollView.contentSize = CGSize(width: 375, height: 2000)
        scrollView.contentInset.bottom = 12
        scrollView.automaticInsetAdjustment.bottom = 83
        scrollView.contentOffset.y = 2000 - 667 + 12 + 83
        scrollView.isDraggingOverride = true

        scrollView.loadMoreable(
            edge: .bottom,
            style: MockStyle(extent: 54),
            options: RefreshableOptions(animationDuration: 0, automaticallyEndRefreshing: false)
        ) {}

        scrollView.component(for: .bottom)?.scrollViewDidScroll(contentOffset: scrollView.contentOffset)

        #expect(scrollView.loadMoreState(edge: .bottom) == .idle)
    }

    @Test("横向 edge 控件使用完整可见宽度以支持横屏布局")
    func horizontalEdgeFrameUsesViewportWidth() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 844, height: 390))
        scrollView.semanticContentAttribute = .forceLeftToRight
        scrollView.contentSize = CGSize(width: 1600, height: 390)
        let leadingStyle = MockStyle(extent: 54)
        let trailingStyle = MockStyle(extent: 54)

        scrollView.refreshable(edge: .leading, style: leadingStyle) {}
        scrollView.loadMoreable(edge: .trailing, style: trailingStyle) {}

        #expect(leadingStyle.view.frame == CGRect(x: -54, y: 0, width: 844, height: 390))
        #expect(trailingStyle.view.frame == CGRect(x: 810, y: 0, width: 844, height: 390))
    }

    @Test("横向 edge 在关闭自动 inset 调整时仍避开 safe area")
    func horizontalEdgeFrameUsesSafeAreaInsetsWhenAdjustmentIsDisabled() {
        let scrollView = SafeAreaInsetScrollView(frame: CGRect(x: 0, y: 0, width: 844, height: 390))
        scrollView.semanticContentAttribute = .forceLeftToRight
        scrollView.contentSize = CGSize(width: 1600, height: 390)
        scrollView.safeAreaInsetOverride = UIEdgeInsets(top: 0, left: 47, bottom: 0, right: 47)
        let leadingStyle = MockStyle(extent: 54)
        let trailingStyle = MockStyle(extent: 54)

        scrollView.refreshable(
            edge: .leading,
            style: leadingStyle,
            options: RefreshableOptions(animationDuration: 0, automaticallyEndRefreshing: false)
        ) {}
        scrollView.loadMoreable(
            edge: .trailing,
            style: trailingStyle,
            options: RefreshableOptions(animationDuration: 0, automaticallyEndRefreshing: false)
        ) {}

        #expect(leadingStyle.view.frame == CGRect(x: -54, y: 0, width: 750, height: 390))
        #expect(trailingStyle.view.frame == CGRect(x: 904, y: 0, width: 750, height: 390))
        #expect(leadingStyle.view.layoutMargins.left == 0)
        #expect(leadingStyle.view.layoutMargins.right == 620)
        #expect(trailingStyle.view.layoutMargins.left == 620)
        #expect(trailingStyle.view.layoutMargins.right == 0)

        scrollView.beginRefreshing(edge: .leading)
        #expect(scrollView.contentOffset.x == -101)

        scrollView.endRefreshing(edge: .leading)
        scrollView.contentOffset.x = 1600 - 844 + 47
        scrollView.beginLoadingMore(edge: .trailing)
        #expect(scrollView.contentOffset.x == 857)
    }

    @Test("overlay loadMore 在 action 执行期间保持可见但不占位")
    func overlayLoadMoreStaysVisibleWithoutPersistentInsetWhileActionRuns() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        scrollView.contentSize = CGSize(width: 320, height: 1200)
        scrollView.contentInset.bottom = 12
        scrollView.contentOffset.y = 732
        let style = MockStyle(extent: 76)

        scrollView.loadMoreable(
            edge: .bottom,
            style: style,
            options: RefreshableOptions(
                animationDuration: 0,
                automaticallyEndRefreshing: false,
                presentation: .overlay(spacing: 12)
            )
        ) {}
        scrollView.beginLoadingMore(edge: .bottom)

        #expect(scrollView.loadMoreState(edge: .bottom) == .refreshing)
        #expect(scrollView.contentInset.bottom == 12)
        #expect(scrollView.contentOffset.y == 732)
        #expect(style.view.alpha == 1)
        #expect(style.lastState == .refreshing)
    }

    @Test("overlay 展示模式将刷新视图固定在可见区域边缘且不调整 inset")
    func overlayPresentationPinsViewInVisibleViewportWithoutInset() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        scrollView.contentSize = CGSize(width: 320, height: 1200)
        scrollView.contentOffset = CGPoint(x: 0, y: 120)
        scrollView.contentInset.top = 8
        let style = MockStyle(extent: 44)

        scrollView.refreshable(
            edge: .top,
            style: style,
            options: RefreshableOptions(
                animationDuration: 0,
                automaticallyEndRefreshing: false,
                presentation: .overlay(spacing: 12)
            )
        ) {}

        #expect(style.view.frame == CGRect(x: 0, y: 132, width: 320, height: 44))

        scrollView.beginRefreshing(edge: .top)

        #expect(scrollView.refreshState(edge: .top) == .refreshing)
        #expect(scrollView.contentInset.top == 8)
        #expect(style.view.alpha == 1)
        #expect(style.view.frame == CGRect(x: 0, y: 132, width: 320, height: 44))
    }

    @Test("overlay 展示模式默认保留系统弹性位移")
    func overlayPresentationAllowsContentOffsetMovementByDefault() {
        let scrollView = EdgeDraggingScrollView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        scrollView.contentSize = CGSize(width: 320, height: 1200)
        scrollView.contentInset.top = 8
        scrollView.contentOffset = CGPoint(x: 0, y: -8)
        scrollView.isDraggingOverride = true
        let style = MockStyle(extent: 44)

        scrollView.refreshable(
            edge: .top,
            style: style,
            options: RefreshableOptions(
                triggerOffset: 60,
                animationDuration: 0,
                automaticallyEndRefreshing: false,
                presentation: .overlay(spacing: 12)
            )
        ) {}

        scrollView.contentOffset = CGPoint(x: 0, y: -68)
        scrollView.component(for: .top)?.scrollViewDidScroll(contentOffset: CGPoint(x: 0, y: -68))

        #expect(scrollView.refreshState(edge: .top) == .triggered)
        #expect(scrollView.contentOffset.y == -68)
    }

    @Test("overlay 锁定内容位移时下拉仍触发但 contentOffset 保持顶部边界")
    func overlayPresentationCanLockTopContentOffsetWhilePulling() {
        let scrollView = EdgeDraggingScrollView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        scrollView.contentSize = CGSize(width: 320, height: 1200)
        scrollView.contentInset.top = 8
        scrollView.contentOffset = CGPoint(x: 0, y: -8)
        scrollView.isDraggingOverride = true
        let style = MockStyle(extent: 44)

        scrollView.refreshable(
            edge: .top,
            style: style,
            options: RefreshableOptions(
                triggerOffset: 60,
                animationDuration: 0,
                automaticallyEndRefreshing: false,
                presentation: .overlay(spacing: 12, locksContentOffset: true)
            )
        ) {}

        scrollView.contentOffset = CGPoint(x: 0, y: -68)
        scrollView.component(for: .top)?.scrollViewDidScroll(contentOffset: CGPoint(x: 0, y: -68))

        #expect(scrollView.refreshState(edge: .top) == .triggered)
        #expect(scrollView.contentOffset.y == -8)
        #expect(style.view.frame == CGRect(x: 0, y: 4, width: 320, height: 44))
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

        #expect(leadingStyle.view.frame.origin.x == 720)
        #expect(leadingStyle.view.frame.width == 320)
        #expect(trailingStyle.view.frame.origin.x == -50)
        #expect(trailingStyle.view.frame.width == 320)
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

private class EdgeDraggingScrollView: UIScrollView {
    var isDraggingOverride = false

    override var isDragging: Bool {
        isDraggingOverride
    }
}

private final class AdjustedInsetScrollView: EdgeDraggingScrollView {
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

private final class SafeAreaInsetScrollView: EdgeDraggingScrollView {
    var safeAreaInsetOverride: UIEdgeInsets = .zero

    override var safeAreaInsets: UIEdgeInsets {
        safeAreaInsetOverride
    }

    override var adjustedContentInset: UIEdgeInsets {
        contentInset
    }
}
