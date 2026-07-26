import Testing
@testable import Refreshable
import UIKit

@Suite("DefaultRefreshControlStyle renderer", .tags(.ui))
@MainActor
struct DefaultRefreshControlStyleTests {
    @Test("无文案时四个方向均保持 54pt spinner-only 布局", arguments: RefreshableEdge.allCases)
    func hiddenDefaultUI(edge: RefreshableEdge) throws {
        let style = DefaultRefreshControlStyle(
            edge: edge,
            role: .refresh,
            textConfiguration: nil
        )
        let renderer = style.makeRenderer()
        let label = try #require(renderer.view.firstDefaultSubview(of: UILabel.self))
        let spinner = try #require(
            renderer.view.firstDefaultSubview(of: SegmentedRefreshSpinnerView.self)
        )

        renderer.view.frame = edge.axis == .vertical
            ? CGRect(x: 0, y: 0, width: 320, height: style.extent)
            : CGRect(x: 0, y: 0, width: style.extent, height: 320)
        renderer.view.layoutIfNeeded()
        let spinnerFrame = spinner.convert(spinner.bounds, to: renderer.view)

        #expect(style.extent == 54)
        #expect(label.isHidden)
        #expect(renderer.view.firstDefaultSubview(of: UIImageView.self) == nil)
        #expect(abs(spinnerFrame.midX - renderer.view.bounds.midX) < 0.5)
        #expect(abs(spinnerFrame.midY - renderer.view.bounds.midY) < 0.5)
        #expect(renderer.view.accessibilityIdentifier == "Refreshable.DefaultIndicator")
        #expect(renderer.view.isAccessibilityElement)
    }

    @Test("横向样式保留 54 触发距离和外侧间距")
    func horizontalDefaults() {
        let style = DefaultRefreshControlStyle(
            edge: .leading,
            role: .refresh,
            textConfiguration: RefreshableTextConfiguration()
        )

        #expect(style.extent == 72)
        #expect(style.defaultTriggerOffset == 54)
        #expect(style.defaultPlacement == RefreshablePlacement(outerSpacing: 8))

        let verticalStyle = DefaultRefreshControlStyle(
            edge: .top,
            role: .refresh,
            textConfiguration: RefreshableTextConfiguration()
        )
        #expect(verticalStyle.defaultPlacement == RefreshablePlacement())
    }

    @Test(
        "内置文案覆盖全部 edge 与 role",
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
        let renderer = DefaultRefreshControlStyle(
            edge: edge,
            role: role,
            textConfiguration: RefreshableTextConfiguration()
        ).makeRenderer()
        let label = try #require(renderer.view.firstDefaultSubview(of: UILabel.self))

        renderer.render(defaultContext(.idle))
        #expect(label.text == idle)
        renderer.render(defaultContext(.pulling(0.5), progress: 0.5))
        #expect(label.text == idle)
        renderer.render(defaultContext(.triggered, progress: 1))
        #expect(label.text == triggered)
        renderer.render(defaultContext(.refreshing, progress: 1))
        #expect(label.text == refreshing)
        renderer.render(defaultContext(.ending, progress: 1))
        #expect(label.text == ending)
        renderer.render(defaultContext(.noMoreData))
        #expect(label.text == noMoreData)
    }

    @Test("renderer 保留状态文案、spinner 和 accessibility")
    func rendererStateRendering() throws {
        let renderer = DefaultRefreshControlStyle(
            edge: .bottom,
            role: .loadMore,
            textConfiguration: RefreshableTextConfiguration(),
            accessibilityEnvironment: DefaultRefreshStyleAccessibilityEnvironment(
                isReduceMotionEnabled: false,
                isReduceTransparencyEnabled: false
            )
        ).makeRenderer()
        let label = try #require(renderer.view.firstDefaultSubview(of: UILabel.self))
        let spinner = try #require(renderer.view.firstDefaultSubview(of: SegmentedRefreshSpinnerView.self))

        renderer.render(defaultContext(.triggered, progress: 1))
        #expect(label.text == "释放加载")
        #expect(renderer.view.accessibilityValue == "释放加载")

        renderer.render(defaultContext(.refreshing))
        #expect(label.text == "正在加载...")
        #expect(spinner.isSpinAnimationActive)
    }

    @Test("spinner 映射全部状态并遵守 Reduce Motion")
    func spinnerStateMapping() throws {
        let renderer = DefaultRefreshControlStyle(
            edge: .top,
            role: .refresh,
            textConfiguration: nil,
            accessibilityEnvironment: DefaultRefreshStyleAccessibilityEnvironment(
                isReduceMotionEnabled: false,
                isReduceTransparencyEnabled: false
            )
        ).makeRenderer()
        let spinner = try #require(
            renderer.view.firstDefaultSubview(of: SegmentedRefreshSpinnerView.self)
        )

        renderer.render(defaultContext(.idle))
        #expect(spinner.currentProgress == 0)
        #expect(spinner.isSpinAnimationActive == false)

        renderer.render(defaultContext(.pulling(0.25), progress: 0.6))
        #expect(spinner.currentProgress == 0.6)
        #expect(spinner.isSpinAnimationActive == false)

        renderer.render(defaultContext(.triggered, progress: 1.8))
        #expect(spinner.currentProgress == 1)
        #expect(spinner.isSpinAnimationActive == false)

        renderer.render(defaultContext(.refreshing, progress: 1))
        #expect(spinner.currentProgress == 1)
        #expect(spinner.isSpinAnimationActive)

        renderer.render(defaultContext(.ending, progress: 1))
        #expect(spinner.currentProgress == 1)
        #expect(spinner.isSpinAnimationActive == false)

        renderer.render(defaultContext(.noMoreData))
        #expect(spinner.currentProgress == 0)
        #expect(spinner.isSpinAnimationActive == false)

        let reducedRenderer = DefaultRefreshControlStyle(
            edge: .top,
            role: .refresh,
            textConfiguration: nil,
            accessibilityEnvironment: DefaultRefreshStyleAccessibilityEnvironment(
                isReduceMotionEnabled: true,
                isReduceTransparencyEnabled: false
            )
        ).makeRenderer()
        let reducedSpinner = try #require(
            reducedRenderer.view.firstDefaultSubview(of: SegmentedRefreshSpinnerView.self)
        )
        reducedRenderer.render(defaultContext(.refreshing, progress: 1))
        #expect(reducedSpinner.currentProgress == 1)
        #expect(reducedSpinner.isSpinAnimationActive == false)
    }

    @Test("Reduce Motion 实时变化会更新正在刷新的 spinner")
    func liveReduceMotionChanges() throws {
        let environment = DefaultAccessibilityEnvironmentBox(
            DefaultRefreshStyleAccessibilityEnvironment(
                isReduceMotionEnabled: false,
                isReduceTransparencyEnabled: false
            )
        )
        let notificationCenter = NotificationCenter()
        let renderer = DefaultRefreshControlStyle(
            edge: .top,
            role: .refresh,
            textConfiguration: nil,
            accessibilityEnvironmentProvider: { environment.value },
            accessibilityNotificationCenter: notificationCenter
        ).makeRenderer()
        let spinner = try #require(
            renderer.view.firstDefaultSubview(of: SegmentedRefreshSpinnerView.self)
        )

        renderer.render(defaultContext(.refreshing, progress: 1))
        #expect(spinner.isSpinAnimationActive)

        environment.value.isReduceMotionEnabled = true
        notificationCenter.post(
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
        #expect(spinner.isSpinAnimationActive == false)

        environment.value.isReduceMotionEnabled = false
        notificationCenter.post(
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
        #expect(spinner.isSpinAnimationActive)
    }

    @Test("单状态覆盖生效且空字符串只隐藏可见文案")
    func textOverrideResolution() throws {
        let renderer = DefaultRefreshControlStyle(
            edge: .bottom,
            role: .loadMore,
            textConfiguration: RefreshableTextConfiguration(
                pulling: "继续拖动",
                triggered: "",
                refreshing: "载入中"
            )
        ).makeRenderer()
        let label = try #require(renderer.view.firstDefaultSubview(of: UILabel.self))

        renderer.render(defaultContext(.idle))
        #expect(label.text == "上拉加载更多")
        #expect(label.isHidden == false)

        renderer.render(defaultContext(.pulling(0.4), progress: 0.4))
        #expect(label.text == "继续拖动")
        #expect(renderer.view.accessibilityValue == "继续拖动")

        renderer.render(defaultContext(.triggered, progress: 1))
        #expect(label.text == "")
        #expect(label.isHidden)
        #expect(renderer.view.accessibilityValue == "释放加载")

        renderer.render(defaultContext(.refreshing, progress: 1))
        #expect(label.text == "载入中")
        #expect(label.isHidden == false)
        #expect(renderer.view.accessibilityValue == "载入中")
    }

    @Test("无可见文案时仍保留 VoiceOver，且支持自定义标签和值")
    func accessibilityValues() throws {
        let hiddenRenderer = DefaultRefreshControlStyle(
            edge: .leading,
            role: .refresh,
            textConfiguration: nil
        ).makeRenderer()
        hiddenRenderer.render(defaultContext(.refreshing, progress: 1))

        #expect(hiddenRenderer.view.accessibilityLabel == "刷新")
        #expect(hiddenRenderer.view.accessibilityValue == "正在刷新")
        #expect(
            try #require(hiddenRenderer.view.firstDefaultSubview(of: UILabel.self)).isHidden
        )

        let configuredRenderer = DefaultRefreshControlStyle(
            edge: .trailing,
            role: .loadMore,
            textConfiguration: RefreshableTextConfiguration(
                ending: "完成",
                accessibilityLabel: "下一页"
            )
        ).makeRenderer()
        configuredRenderer.render(defaultContext(.ending, progress: 1))

        #expect(configuredRenderer.view.accessibilityLabel == "下一页")
        #expect(configuredRenderer.view.accessibilityValue == "完成")
    }

    @Test("默认文字和 spinner 使用可随明暗模式解析的动态颜色")
    func dynamicSystemColors() throws {
        let renderer = DefaultRefreshControlStyle(
            edge: .top,
            role: .refresh,
            textConfiguration: RefreshableTextConfiguration()
        ).makeRenderer()
        let label = try #require(renderer.view.firstDefaultSubview(of: UILabel.self))
        let light = UITraitCollection(userInterfaceStyle: .light)
        let dark = UITraitCollection(userInterfaceStyle: .dark)

        #expect(
            label.textColor.resolvedColor(with: light)
                == UIColor.secondaryLabel.resolvedColor(with: light)
        )
        #expect(
            label.textColor.resolvedColor(with: dark)
                == UIColor.secondaryLabel.resolvedColor(with: dark)
        )
        #expect(
            label.textColor.resolvedColor(with: light)
                != label.textColor.resolvedColor(with: dark)
        )
    }

    @Test("两个 renderer 不共享视图或状态")
    func renderersAreIndependent() {
        let style = DefaultRefreshControlStyle(edge: .top, role: .refresh, textConfiguration: nil)
        let first = style.makeRenderer()
        let second = style.makeRenderer()

        first.render(defaultContext(.refreshing))

        #expect(first !== second)
        #expect(first.view !== second.view)
        #expect(first.view.accessibilityValue == "正在刷新")
        #expect(second.view.accessibilityValue == "下拉刷新")
    }
}

@MainActor
private final class DefaultAccessibilityEnvironmentBox {
    var value: DefaultRefreshStyleAccessibilityEnvironment

    init(_ value: DefaultRefreshStyleAccessibilityEnvironment) {
        self.value = value
    }
}

private func defaultContext(_ state: RefreshState, progress: CGFloat = 0) -> RefreshableStyleContext {
    RefreshableStyleContext(state: state, pullProgress: progress)
}

private extension UIView {
    func firstDefaultSubview<T: UIView>(of type: T.Type) -> T? {
        if let typed = self as? T { return typed }
        for subview in subviews {
            if let found = subview.firstDefaultSubview(of: type) { return found }
        }
        return nil
    }
}
