import Testing
@testable import Refreshable
import UIKit

@Suite("Classic style renderers", .tags(.ui))
@MainActor
struct ClassicStyleTests {
    @Test("top renderer 保留状态文案和 VoiceOver 值")
    func topRendererStateText() throws {
        let renderer = ClassicTopRefreshStyle().makeRenderer()
        let label = try #require(renderer.view.firstSubview(of: UILabel.self))

        renderer.render(context(.idle))
        #expect(label.text == "下拉刷新")
        renderer.render(context(.triggered, progress: 1))
        #expect(label.text == "释放刷新")
        renderer.render(context(.active))
        #expect(label.text == "正在刷新...")
        #expect(renderer.view.accessibilityValue == "正在刷新")
    }

    @Test("bottom renderer 保留状态文案和 VoiceOver 值")
    func bottomRendererStateText() throws {
        let renderer = ClassicBottomLoadMoreStyle().makeRenderer()
        let label = try #require(renderer.view.firstSubview(of: UILabel.self))

        renderer.render(context(.pulling(0.4), progress: 0.4))
        #expect(label.text == "上拉加载更多")
        renderer.render(context(.noMoreData))
        #expect(label.text == "没有更多数据")
        #expect(renderer.view.accessibilityValue == "没有更多数据")
    }

    @Test("factory 每次创建独立 top renderer 和 view")
    func topRenderersAreIndependent() {
        let style = ClassicTopRefreshStyle()
        let first = style.makeRenderer()
        let second = style.makeRenderer()

        first.render(context(.active, progress: 1))

        #expect(first !== second)
        #expect(first.view !== second.view)
        #expect(first.view.accessibilityValue == "正在刷新")
        #expect(second.view.accessibilityValue == nil)
    }

    @Test("top renderer 保持 Dynamic Type 与 Reduce Motion 配置")
    func topRendererAccessibilityConfiguration() throws {
        let style = ClassicTopRefreshStyle(
            configuration: RefreshLabelStyleConfiguration(
                font: .systemFont(ofSize: 17, weight: .semibold),
                fontTextStyle: .headline,
                adjustsFontForContentSizeCategory: true
            ),
            accessibilityEnvironment: RefreshStyleAccessibilityEnvironment(
                isReduceMotionEnabled: true,
                isReduceTransparencyEnabled: false
            )
        )
        let renderer = style.makeRenderer()
        let label = try #require(renderer.view.firstSubview(of: UILabel.self))
        let arrow = try #require(renderer.view.firstSubview(of: UIImageView.self))

        renderer.render(context(.pulling(0.5), progress: 0.5))

        #expect(label.adjustsFontForContentSizeCategory)
        #expect(arrow.transform == .identity)
    }
}

private func context(_ state: RefreshState, progress: CGFloat = 0) -> RefreshableStyleContext {
    RefreshableStyleContext(state: state, pullProgress: progress)
}

extension Tag {
    @Tag static var ui: Self
}

private extension UIView {
    func firstSubview<T: UIView>(of type: T.Type) -> T? {
        if let view = self as? T { return view }
        for subview in subviews {
            if let found = subview.firstSubview(of: type) { return found }
        }
        return nil
    }
}
