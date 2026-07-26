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

        renderer.render(context(.refreshing))

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
        reducedRenderer.render(context(.refreshing, progress: 1))

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
        animatedRenderer.render(context(.refreshing, progress: 1))

        let animatedKeys = animatedRenderer.view.layer
            .allSublayers()
            .flatMap { $0.animationKeys() ?? [] }
        #expect(animatedKeys.contains("kineticSpin"))
        #expect(animatedKeys.contains("kineticTick"))
    }

    @Test("Taiji style 将主题变化同步至其所有存活 renderer")
    func taijiThemeSynchronizesRenderers() throws {
        let style = TaijiRefreshStyle(theme: .dark)
        let first = style.makeRenderer()
        let second = style.makeRenderer()
        let firstGradient = try #require(first.view.layer.firstSublayer(of: CAGradientLayer.self))
        let secondGradient = try #require(second.view.layer.firstSublayer(of: CAGradientLayer.self))
        let darkFirstColor = UIColor(cgColor: firstGradient.colors!.first! as! CGColor)
        let darkSecondColor = UIColor(cgColor: secondGradient.colors!.first! as! CGColor)

        style.setTheme(.light, animated: false)

        let lightFirstColor = UIColor(cgColor: firstGradient.colors!.first! as! CGColor)
        let lightSecondColor = UIColor(cgColor: secondGradient.colors!.first! as! CGColor)
        #expect(style.theme == .light)
        #expect(darkFirstColor != lightFirstColor)
        #expect(darkSecondColor != lightSecondColor)
        #expect(lightFirstColor == lightSecondColor)
    }

    @Test("Taiji system theme 实时响应 renderer 的明暗外观变化")
    func taijiSystemThemeRespondsToLiveAppearanceChanges() throws {
        let style = TaijiRefreshStyle(theme: .system)
        let renderer = try #require(
            style.makeRenderer() as? any TaijiRefreshSystemAppearanceRendering
        )
        renderer.view.frame = CGRect(x: 0, y: 0, width: 390, height: style.extent)

        let gradient = try #require(
            renderer.view.layer.firstSublayer(of: CAGradientLayer.self)
        )

        renderer.applySystemAppearance(
            traitCollection: UITraitCollection(userInterfaceStyle: .light)
        )
        renderer.render(context(.refreshing, progress: 1))
        let lightColorValue = try #require(gradient.colors?.first)
        let lightColor = lightColorValue as! CGColor

        renderer.applySystemAppearance(
            traitCollection: UITraitCollection(userInterfaceStyle: .dark)
        )
        let darkColorValue = try #require(gradient.colors?.first)
        let darkColor = darkColorValue as! CGColor

        #expect(UIColor(cgColor: lightColor) != UIColor(cgColor: darkColor))
        #expect(renderer.view.accessibilityValue == "正在刷新")
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
    func firstSublayer<T: CALayer>(of type: T.Type) -> T? {
        if let typed = self as? T { return typed }
        for sublayer in sublayers ?? [] {
            if let found = sublayer.firstSublayer(of: type) { return found }
        }
        return nil
    }

    func allSublayers() -> [CALayer] {
        [self] + (sublayers ?? []).flatMap { $0.allSublayers() }
    }
}
