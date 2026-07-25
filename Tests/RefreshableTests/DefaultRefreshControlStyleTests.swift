import Testing
@testable import Refreshable
import UIKit

@Suite("DefaultRefreshControlStyle", .tags(.ui))
@MainActor
struct DefaultRefreshControlStyleTests {

    @Test("no text keeps every edge compact and spinner-only", arguments: RefreshableEdge.allCases)
    func hiddenDefaultUI(edge: RefreshableEdge) throws {
        let style = DefaultRefreshControlStyle(edge: edge, role: .refresh, textConfiguration: nil)
        let label = try #require(style.view.firstDefaultSubview(of: UILabel.self))
        let spinner = try #require(style.view.firstDefaultSubview(of: SegmentedRefreshSpinnerView.self))

        #expect(style.extent == 54)
        #expect(label.isHidden)
        #expect(style.view.firstDefaultSubview(of: UIImageView.self) == nil)
        #expect(spinner.superview != nil)
        #expect(style.view.accessibilityIdentifier == "Refreshable.DefaultIndicator")
        #expect(style.view.isAccessibilityElement)
    }

    @Test(
        "enabled text uses directional built-in copy and edge extent",
        arguments: [
            (RefreshableEdge.top, CGFloat(54), "下拉刷新"),
            (.bottom, 54, "上拉刷新"),
            (.leading, 72, "拖动刷新"),
            (.trailing, 72, "拖动刷新"),
        ]
    )
    func enabledTextLayout(edge: RefreshableEdge, expectedExtent: CGFloat, expectedText: String) throws {
        let style = DefaultRefreshControlStyle(
            edge: edge,
            role: .refresh,
            textConfiguration: RefreshableTextConfiguration()
        )
        let label = try #require(style.view.firstDefaultSubview(of: UILabel.self))
        let spinner = try #require(style.view.firstDefaultSubview(of: SegmentedRefreshSpinnerView.self))

        style.view.frame = edge.axis == .vertical
            ? CGRect(x: 0, y: 0, width: 320, height: expectedExtent)
            : CGRect(x: 0, y: 0, width: expectedExtent, height: 320)
        style.view.layoutIfNeeded()
        let spinnerFrame = spinner.convert(spinner.bounds, to: style.view)
        let labelFrame = label.convert(label.bounds, to: style.view)

        #expect(style.extent == expectedExtent)
        #expect(label.text == expectedText)
        #expect(label.isHidden == false)
        #expect(label.adjustsFontForContentSizeCategory)
        #expect(label.numberOfLines == 1)
        #expect(label.transform == .identity)
        #expect(spinner.bounds.size == CGSize(width: 24, height: 24))

        if edge.axis == .vertical {
            #expect(abs(spinnerFrame.maxX + 8 - labelFrame.minX) < 0.5)
            #expect(abs((spinnerFrame.minX + labelFrame.maxX) / 2 - style.view.bounds.midX) < 0.5)
        } else {
            #expect(abs(spinnerFrame.maxY + 6 - labelFrame.minY) < 0.5)
            #expect(abs((spinnerFrame.minY + labelFrame.maxY) / 2 - style.view.bounds.midY) < 0.5)
        }
    }

    @Test("spinner maps every state and honors Reduce Motion")
    func spinnerStateMapping() throws {
        let style = DefaultRefreshControlStyle(
            edge: .top,
            role: .refresh,
            textConfiguration: nil,
            accessibilityEnvironment: DefaultRefreshStyleAccessibilityEnvironment(
                isReduceMotionEnabled: false,
                isReduceTransparencyEnabled: false
            )
        )
        let spinner = try #require(style.view.firstDefaultSubview(of: SegmentedRefreshSpinnerView.self))

        style.update(state: .idle, progress: 1)
        #expect(spinner.currentProgress == 0)
        #expect(spinner.isSpinAnimationActive == false)

        style.update(state: .pulling(0.25), progress: 0.6)
        #expect(spinner.currentProgress == 0.6)
        #expect(spinner.isSpinAnimationActive == false)

        style.update(state: .pulling(1.5), progress: -0.5)
        #expect(spinner.currentProgress == 1)
        #expect(spinner.isSpinAnimationActive == false)

        style.update(state: .triggered, progress: 1.8)
        #expect(spinner.currentProgress == 1)
        #expect(spinner.isSpinAnimationActive == false)

        style.update(state: .refreshing, progress: 0)
        #expect(spinner.currentProgress == 1)
        #expect(spinner.isSpinAnimationActive)

        style.update(state: .ending, progress: 0)
        #expect(spinner.currentProgress == 1)
        #expect(spinner.isSpinAnimationActive == false)

        style.update(state: .noMoreData, progress: 1)
        #expect(spinner.currentProgress == 0)
        #expect(spinner.isSpinAnimationActive == false)

        let reducedMotionStyle = DefaultRefreshControlStyle(
            edge: .top,
            role: .refresh,
            textConfiguration: nil,
            accessibilityEnvironment: DefaultRefreshStyleAccessibilityEnvironment(
                isReduceMotionEnabled: true,
                isReduceTransparencyEnabled: false
            )
        )
        let reducedMotionSpinner = try #require(
            reducedMotionStyle.view.firstDefaultSubview(of: SegmentedRefreshSpinnerView.self)
        )
        reducedMotionStyle.update(state: .refreshing, progress: 0)
        #expect(reducedMotionSpinner.currentProgress == 1)
        #expect(reducedMotionSpinner.isSpinAnimationActive == false)
    }

    @Test(
        "built-in copy covers refresh and load-more in every direction",
        arguments: [
            (RefreshableEdge.top, RefreshableRole.refresh, "下拉刷新", "释放刷新", "正在刷新...", "刷新完成", "刷新完成"),
            (.bottom, .refresh, "上拉刷新", "释放刷新", "正在刷新...", "刷新完成", "刷新完成"),
            (.leading, .refresh, "拖动刷新", "释放刷新", "正在刷新...", "刷新完成", "刷新完成"),
            (.trailing, .refresh, "拖动刷新", "释放刷新", "正在刷新...", "刷新完成", "刷新完成"),
            (.top, .loadMore, "下拉加载", "释放加载", "正在加载...", "加载完成", "没有更多数据"),
            (.bottom, .loadMore, "上拉加载更多", "释放加载", "正在加载...", "加载完成", "没有更多数据"),
            (.leading, .loadMore, "拖动加载", "释放加载", "正在加载...", "加载完成", "没有更多数据"),
            (.trailing, .loadMore, "拖动加载", "释放加载", "正在加载...", "加载完成", "没有更多数据"),
        ]
    )
    func builtInCopy(
        edge: RefreshableEdge,
        role: RefreshableRole,
        idle: String,
        triggered: String,
        refreshing: String,
        ending: String,
        noMoreData: String
    ) throws {
        let style = DefaultRefreshControlStyle(
            edge: edge,
            role: role,
            textConfiguration: RefreshableTextConfiguration()
        )
        let label = try #require(style.view.firstDefaultSubview(of: UILabel.self))

        style.update(state: .idle, progress: 0)
        #expect(label.text == idle)
        style.update(state: .pulling(0.5), progress: 0.5)
        #expect(label.text == idle)
        style.update(state: .triggered, progress: 1)
        #expect(label.text == triggered)
        style.update(state: .refreshing, progress: 0)
        #expect(label.text == refreshing)
        style.update(state: .ending, progress: 0)
        #expect(label.text == ending)
        style.update(state: .noMoreData, progress: 0)
        #expect(label.text == noMoreData)
    }

    @Test("nil overrides fall back, nonempty overrides win, and empty strings hide")
    func textOverrideResolution() throws {
        let style = DefaultRefreshControlStyle(
            edge: .bottom,
            role: .loadMore,
            textConfiguration: RefreshableTextConfiguration(
                idle: nil,
                pulling: "继续拖动",
                triggered: "",
                refreshing: "载入中"
            )
        )
        let label = try #require(style.view.firstDefaultSubview(of: UILabel.self))

        style.update(state: .idle, progress: 0)
        #expect(label.text == "上拉加载更多")
        #expect(label.isHidden == false)

        style.update(state: .pulling(0.4), progress: 0.4)
        #expect(label.text == "继续拖动")
        #expect(label.isHidden == false)
        #expect(style.view.accessibilityValue == "继续拖动")

        style.update(state: .triggered, progress: 1)
        #expect(label.text == "")
        #expect(label.isHidden)
        #expect(style.view.accessibilityValue == "释放加载")

        style.update(state: .refreshing, progress: 0)
        #expect(label.text == "载入中")
        #expect(label.isHidden == false)
        #expect(style.view.accessibilityValue == "载入中")
    }

    @Test("accessibility remains useful without visible text and accepts overrides")
    func accessibilityValues() throws {
        let hiddenStyle = DefaultRefreshControlStyle(
            edge: .leading,
            role: .refresh,
            textConfiguration: nil
        )
        hiddenStyle.update(state: .refreshing, progress: 0)

        #expect(hiddenStyle.view.accessibilityLabel == "刷新")
        #expect(hiddenStyle.view.accessibilityValue == "正在刷新")
        let hiddenLabel = try #require(hiddenStyle.view.firstDefaultSubview(of: UILabel.self))
        #expect(hiddenLabel.isHidden)

        let configuredStyle = DefaultRefreshControlStyle(
            edge: .trailing,
            role: .loadMore,
            textConfiguration: RefreshableTextConfiguration(
                ending: "完成",
                accessibilityLabel: "下一页"
            )
        )
        configuredStyle.update(state: .ending, progress: 0)

        #expect(configuredStyle.view.accessibilityLabel == "下一页")
        #expect(configuredStyle.view.accessibilityValue == "完成")
    }

    @Test("dynamic secondary color resolves in light and dark appearance")
    func dynamicSystemColor() throws {
        let style = DefaultRefreshControlStyle(
            edge: .top,
            role: .refresh,
            textConfiguration: RefreshableTextConfiguration()
        )
        let label = try #require(style.view.firstDefaultSubview(of: UILabel.self))
        let light = UITraitCollection(userInterfaceStyle: .light)
        let dark = UITraitCollection(userInterfaceStyle: .dark)

        #expect(label.textColor.resolvedColor(with: light) == UIColor.secondaryLabel.resolvedColor(with: light))
        #expect(label.textColor.resolvedColor(with: dark) == UIColor.secondaryLabel.resolvedColor(with: dark))
        #expect(
            label.textColor.resolvedColor(with: light)
                != label.textColor.resolvedColor(with: dark)
        )
    }
}

private extension UIView {
    func firstDefaultSubview<T: UIView>(of type: T.Type) -> T? {
        if let view = self as? T {
            return view
        }

        for subview in subviews {
            if let match = subview.firstDefaultSubview(of: type) {
                return match
            }
        }

        return nil
    }
}
