import Testing
@testable import Refreshable
import UIKit

@Suite("DefaultTopRefreshStyle", .tags(.ui))
@MainActor
struct DefaultTopRefreshStyleTests {

    @Test("初始化后 extent 为 54")
    func extent() {
        let style = DefaultTopRefreshStyle()
        #expect(style.extent == 54)
    }

    @Test("view 不为 nil 且有子视图")
    func viewHasSubviews() {
        let style = DefaultTopRefreshStyle()
        #expect(style.view.subviews.count >= 2)
    }

    @Test("update 不 crash，各状态均可调用")
    func updateAllStates() {
        let style = DefaultTopRefreshStyle()
        style.update(state: .idle, progress: 0)
        style.update(state: .pulling(0.5), progress: 0.5)
        style.update(state: .triggered, progress: 1.0)
        style.update(state: .refreshing, progress: 0)
        style.update(state: .ending, progress: 0)
        style.update(state: .noMoreData, progress: 0)
    }

    @Test("默认 top refresh 文案保持现有中文行为")
    func defaultTopRefreshTextsStayChinese() throws {
        let style = DefaultTopRefreshStyle()
        let label = try #require(style.view.firstSubview(ofType: UILabel.self))

        style.update(state: .idle, progress: 0)
        #expect(label.text == "下拉刷新")

        style.update(state: .triggered, progress: 1)
        #expect(label.text == "释放刷新")

        style.update(state: .refreshing, progress: 0)
        #expect(label.text == "正在刷新...")

        style.update(state: .ending, progress: 0)
        #expect(label.text == "刷新完成")
    }

    @Test("自定义 top refresh 文案和 VoiceOver 值随状态更新")
    func customTopRefreshTextsAndAccessibilityValues() throws {
        let texts = DefaultTopRefreshTexts(
            idle: "Pull down",
            pulling: "Keep pulling",
            triggered: "Release now",
            refreshing: "Refreshing feed",
            ending: "Updated",
            accessibilityLabel: "Timeline refresh",
            idleAccessibilityValue: "Idle",
            pullingAccessibilityValue: "Pulling",
            triggeredAccessibilityValue: "Ready",
            refreshingAccessibilityValue: "Loading",
            endingAccessibilityValue: "Done"
        )
        let style = DefaultTopRefreshStyle(texts: texts)
        let label = try #require(style.view.firstSubview(ofType: UILabel.self))

        style.update(state: .pulling(0.5), progress: 0.5)
        #expect(label.text == "Keep pulling")
        #expect(style.view.isAccessibilityElement)
        #expect(style.view.accessibilityLabel == "Timeline refresh")
        #expect(style.view.accessibilityValue == "Pulling")

        style.update(state: .triggered, progress: 1)
        #expect(label.text == "Release now")
        #expect(style.view.accessibilityValue == "Ready")
    }

    @Test("top refresh 支持 Dynamic Type 配置")
    func topRefreshSupportsDynamicTypeConfiguration() throws {
        let style = DefaultTopRefreshStyle(
            configuration: DefaultRefreshStyleConfiguration(
                font: .systemFont(ofSize: 17, weight: .semibold),
                fontTextStyle: .headline,
                adjustsFontForContentSizeCategory: true
            )
        )
        let label = try #require(style.view.firstSubview(ofType: UILabel.self))

        #expect(label.adjustsFontForContentSizeCategory)
        #expect(label.font.pointSize >= 17)
    }

    @Test("Reduce Motion 开启时 top refresh 不使用渐进旋转")
    func topRefreshHonorsReduceMotion() throws {
        let style = DefaultTopRefreshStyle(
            accessibilityEnvironment: DefaultRefreshStyleAccessibilityEnvironment(
                isReduceMotionEnabled: true,
                isReduceTransparencyEnabled: false
            )
        )
        let arrowView = try #require(style.view.firstSubview(ofType: UIImageView.self))

        style.update(state: .pulling(0.5), progress: 0.5)

        #expect(arrowView.transform == .identity)
    }
}

@Suite("DefaultBottomLoadMoreStyle", .tags(.ui))
@MainActor
struct DefaultBottomLoadMoreStyleTests {

    @Test("初始化后 extent 为 54")
    func extent() {
        let style = DefaultBottomLoadMoreStyle()
        #expect(style.extent == 54)
    }

    @Test("update 不 crash，各状态均可调用")
    func updateAllStates() {
        let style = DefaultBottomLoadMoreStyle()
        style.update(state: .idle, progress: 0)
        style.update(state: .pulling(0.3), progress: 0.3)
        style.update(state: .triggered, progress: 1.0)
        style.update(state: .refreshing, progress: 0)
        style.update(state: .ending, progress: 0)
        style.update(state: .noMoreData, progress: 0)
    }

    @Test("默认 bottom load-more 文案保持现有中文行为")
    func defaultBottomLoadMoreTextsStayChinese() throws {
        let style = DefaultBottomLoadMoreStyle()
        let label = try #require(style.view.firstSubview(ofType: UILabel.self))

        style.update(state: .idle, progress: 0)
        #expect(label.text == "上拉加载更多")

        style.update(state: .triggered, progress: 1)
        #expect(label.text == "释放加载")

        style.update(state: .refreshing, progress: 0)
        #expect(label.text == "正在加载...")

        style.update(state: .ending, progress: 0)
        #expect(label.text == "加载完成")

        style.update(state: .noMoreData, progress: 0)
        #expect(label.text == "没有更多数据")
    }

    @Test("自定义 bottom load-more 文案和 VoiceOver 值随状态更新")
    func customBottomLoadMoreTextsAndAccessibilityValues() throws {
        let texts = DefaultBottomLoadMoreTexts(
            idle: "Pull up",
            pulling: "Keep pulling",
            triggered: "Release to load",
            refreshing: "Loading next page",
            ending: "Loaded",
            noMoreData: "All caught up",
            accessibilityLabel: "Timeline load more",
            idleAccessibilityValue: "Idle",
            pullingAccessibilityValue: "Pulling",
            triggeredAccessibilityValue: "Ready",
            refreshingAccessibilityValue: "Loading",
            endingAccessibilityValue: "Done",
            noMoreDataAccessibilityValue: "No more items"
        )
        let style = DefaultBottomLoadMoreStyle(texts: texts)
        let label = try #require(style.view.firstSubview(ofType: UILabel.self))

        style.update(state: .refreshing, progress: 0)
        #expect(label.text == "Loading next page")
        #expect(style.view.isAccessibilityElement)
        #expect(style.view.accessibilityLabel == "Timeline load more")
        #expect(style.view.accessibilityValue == "Loading")

        style.update(state: .noMoreData, progress: 0)
        #expect(label.text == "All caught up")
        #expect(style.view.accessibilityValue == "No more items")
    }

    @Test("Reduce Transparency 开启时 bottom load-more 使用高对比文字颜色")
    func bottomLoadMoreHonorsReduceTransparency() throws {
        let style = DefaultBottomLoadMoreStyle(
            configuration: DefaultRefreshStyleConfiguration(
                textColor: .red,
                reducedTransparencyTextColor: .blue,
                honorsReduceTransparency: true
            ),
            accessibilityEnvironment: DefaultRefreshStyleAccessibilityEnvironment(
                isReduceMotionEnabled: false,
                isReduceTransparencyEnabled: true
            )
        )
        let label = try #require(style.view.firstSubview(ofType: UILabel.self))

        style.update(state: .idle, progress: 0)

        #expect(label.textColor == .blue)
    }
}

@Suite("DefaultEdgeStyle", .tags(.ui))
@MainActor
struct DefaultEdgeStyleTests {

    @Test("horizontal edge style uses circular progress and no activity indicator")
    func horizontalEdgeStyleUsesCircularProgressWithoutSpinner() {
        let style = DefaultEdgeStyle(edge: .leading, role: .refresh)

        #expect(style.extent == 130)
        #expect(style.view.firstSubview(ofType: UIActivityIndicatorView.self) == nil)
        #expect(!style.view.allSubviews(ofType: CAShapeLayerHostView.self).isEmpty)
    }

    @Test("horizontal edge visual content uses visual bounds without margin contract")
    func horizontalEdgeVisualContentUsesVisualBoundsWithoutMarginContract() throws {
        let style = DefaultEdgeStyle(edge: .leading, role: .refresh)
        style.view.frame = CGRect(x: 0, y: 0, width: 130, height: 390)
        let progressHost = try #require(style.view.firstSubview(ofType: CAShapeLayerHostView.self))
        let label = try #require(style.view.firstSubview(ofType: UILabel.self))

        style.update(state: .refreshing, progress: 1)
        style.view.layoutIfNeeded()

        #expect(progressHost.center.x == 65)
        #expect(label.frame.minX >= 0)
        #expect(label.frame.width > 70)
    }

    @Test("horizontal edge pulling text stays generic")
    func horizontalEdgePullingTextStaysGeneric() throws {
        let leading = DefaultEdgeStyle(edge: .leading, role: .refresh)
        let trailing = DefaultEdgeStyle(edge: .trailing, role: .refresh)
        let leadingLabel = try #require(leading.view.firstSubview(ofType: UILabel.self))
        let trailingLabel = try #require(trailing.view.firstSubview(ofType: UILabel.self))

        leading.update(state: .pulling(0.4), progress: 0.4)
        trailing.update(state: .pulling(0.4), progress: 0.4)

        #expect(leadingLabel.text == "拖动刷新")
        #expect(trailingLabel.text == "拖动刷新")
    }

    @Test("horizontal edge label follows refresh state")
    func horizontalEdgeLabelFollowsRefreshState() throws {
        let style = DefaultEdgeStyle(edge: .leading, role: .refresh)
        let label = try #require(style.view.firstSubview(ofType: UILabel.self))

        style.update(state: .triggered, progress: 1)
        #expect(label.text == "释放刷新")

        style.update(state: .refreshing, progress: 1)
        #expect(label.text == "正在刷新...")

        style.update(state: .ending, progress: 0)
        #expect(label.text == "刷新完成")
    }

    @Test("horizontal refreshing progress uses visible rotating arc")
    func horizontalRefreshingProgressUsesVisibleRotatingArc() throws {
        let style = DefaultEdgeStyle(edge: .leading, role: .refresh)
        let progressHost = try #require(style.view.firstSubview(ofType: CAShapeLayerHostView.self))

        style.update(state: .refreshing, progress: 1)

        #expect(progressHost.progressLayer.strokeEnd > 0)
        #expect(progressHost.progressLayer.strokeEnd < 1)
    }

    @Test("horizontal edge render state resolves physical arrow directions")
    func horizontalEdgeRenderStateResolvesPhysicalArrowDirections() {
        let ltrContainer = UIView()
        ltrContainer.semanticContentAttribute = .forceLeftToRight
        let rtlContainer = UIView()
        rtlContainer.semanticContentAttribute = .forceRightToLeft

        #expect(DefaultEdgeStyle.RenderState(edge: .leading, role: .refresh, state: .pulling(0.5), progress: 0.5, in: ltrContainer).arrowSystemName == "arrow.right")
        #expect(DefaultEdgeStyle.RenderState(edge: .trailing, role: .refresh, state: .pulling(0.5), progress: 0.5, in: ltrContainer).arrowSystemName == "arrow.left")
        #expect(DefaultEdgeStyle.RenderState(edge: .leading, role: .refresh, state: .pulling(0.5), progress: 0.5, in: rtlContainer).arrowSystemName == "arrow.left")
        #expect(DefaultEdgeStyle.RenderState(edge: .trailing, role: .refresh, state: .pulling(0.5), progress: 0.5, in: rtlContainer).arrowSystemName == "arrow.right")
    }

    @Test("horizontal progress clamps to zero and one")
    func horizontalProgressClamps() {
        let container = UIView()

        let negative = DefaultEdgeStyle.RenderState(edge: .leading, role: .refresh, state: .pulling(-0.5), progress: -0.5, in: container)
        let overflow = DefaultEdgeStyle.RenderState(edge: .leading, role: .refresh, state: .pulling(1.4), progress: 1.4, in: container)

        #expect(negative.progress == 0)
        #expect(overflow.progress == 1)
    }
}

extension Tag {
    @Tag static var ui: Self
}

private extension UIView {
    func firstSubview<T: UIView>(ofType type: T.Type) -> T? {
        if let view = self as? T {
            return view
        }

        for subview in subviews {
            if let found = subview.firstSubview(ofType: type) {
                return found
            }
        }

        return nil
    }

    func allSubviews<T: UIView>(ofType type: T.Type) -> [T] {
        var results: [T] = []
        if let view = self as? T {
            results.append(view)
        }

        for subview in subviews {
            results.append(contentsOf: subview.allSubviews(ofType: type))
        }

        return results
    }
}
