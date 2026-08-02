import Testing
import UIKit
@testable import Refreshable
@testable import RefreshableStyles

@Suite("RefreshableStyles renderers")
@MainActor
struct RefreshableStylesTests {
    @Test("video top renderer 保留文案、玻璃视图和 spinner")
    func videoTopRenderer() throws {
        let renderer = VideoTopRefreshStyle().makeRenderer()
        let label = try #require(renderer.view.firstSubview(of: UILabel.self))

        renderer.render(context(.active))

        #expect(renderer.view.isAccessibilityElement)
        #expect(renderer.view.firstSubview(of: UIVisualEffectView.self) != nil)
        #expect(label.text == "正在刷新视频")
        #expect(renderer.view.accessibilityValue == "正在刷新")
        #expect(try #require(renderer.view.firstSubview(of: UIActivityIndicatorView.self)).isAnimating)
    }

    @Test("video bottom renderer 保留 no-more-data 文案")
    func videoBottomRenderer() throws {
        let renderer = VideoBottomLoadMoreStyle(extent: 76).makeRenderer()
        let label = try #require(renderer.view.firstSubview(of: UILabel.self))

        renderer.render(context(.noMoreData))

        #expect(renderer.view.frame.height == 76)
        #expect(label.text == "没有更多视频")
        #expect(renderer.view.accessibilityValue == "没有更多视频")
    }

    @Test("kinetic renderer 保留状态文案和独立视图")
    func kineticRenderer() {
        let style = KineticRefreshStyle()
        let first = style.makeRenderer()
        let second = style.makeRenderer()

        first.render(context(.triggered, progress: 1))

        #expect(first !== second)
        #expect(first.view !== second.view)
        #expect(first.view.accessibilityValue == "释放刷新")
        #expect(second.view.accessibilityValue == "未刷新")
    }

    @Test("Kinetic renderer 在 Reduce Motion 下不启动连续变换动画")
    func kineticRendererHonorsReduceMotion() {
        let reducedRenderer = KineticRefreshStyle(
            reduceMotionProvider: { true }
        ).makeRenderer()
        reducedRenderer.view.frame = CGRect(x: 0, y: 0, width: 390, height: 82)
        reducedRenderer.view.layoutIfNeeded()
        reducedRenderer.render(context(.active, progress: 1))

        let reducedAnimationKeys = reducedRenderer.view.layer
            .allSublayers()
            .flatMap { $0.animationKeys() ?? [] }
        #expect(reducedAnimationKeys.contains("kineticSpin") == false)
        #expect(reducedAnimationKeys.contains("kineticPulse") == false)
        #expect(reducedAnimationKeys.contains("kineticTick") == false)

        let animatedRenderer = KineticRefreshStyle(
            reduceMotionProvider: { false }
        ).makeRenderer()
        animatedRenderer.view.frame = CGRect(x: 0, y: 0, width: 390, height: 82)
        animatedRenderer.view.layoutIfNeeded()
        animatedRenderer.render(context(.active, progress: 1))

        let animatedKeys = animatedRenderer.view.layer
            .allSublayers()
            .flatMap { $0.animationKeys() ?? [] }
        #expect(animatedKeys.contains("kineticSpin"))
        #expect(animatedKeys.contains("kineticTick"))
    }

}

private func context(_ state: RefreshState, progress: CGFloat = 0) -> RefreshableStyleContext {
    RefreshableStyleContext(state: state, pullProgress: progress)
}

private extension UIView {
    func firstSubview<T: UIView>(of type: T.Type) -> T? {
        if let typed = self as? T { return typed }
        for subview in subviews {
            if let found = subview.firstSubview(of: type) { return found }
        }
        return nil
    }
}

private extension CALayer {
    func allSublayers() -> [CALayer] {
        [self] + (sublayers ?? []).flatMap { $0.allSublayers() }
    }
}
