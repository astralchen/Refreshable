import Testing
@testable import Refreshable
import UIKit

@Suite("TaijiRefreshStyle")
@MainActor
struct TaijiRefreshStyleTests {

    @Test("default extent is within compact header range")
    func defaultExtent() {
        let style = TaijiRefreshStyle()

        #expect(style.extent >= 80)
        #expect(style.extent <= 100)
        #expect(style.extent == 92)
    }

    @Test("style uses a stable view and no visible text subviews")
    func stableViewWithoutVisibleText() {
        let style = TaijiRefreshStyle()
        let originalView = style.view

        style.update(state: .pulling(0.5), progress: 0.5)
        style.setTheme(.dark, animated: true)

        #expect(style.view === originalView)
        #expect(findLabels(in: style.view).isEmpty)
    }

    @Test("accessibility label and values map state without visible labels")
    func accessibilityValues() {
        let style = TaijiRefreshStyle(accessibilityLabel: "刷新")

        style.update(state: .idle, progress: 0)
        #expect(style.view.isAccessibilityElement == true)
        #expect(style.view.accessibilityLabel == "刷新")
        #expect(style.view.accessibilityValue == "未刷新")

        style.update(state: .pulling(0.4), progress: 0.4)
        #expect(style.view.accessibilityValue == "下拉中")

        style.update(state: .triggered, progress: 1)
        #expect(style.view.accessibilityValue == "释放刷新")

        style.update(state: .refreshing, progress: 0)
        #expect(style.view.accessibilityValue == "正在刷新")

        style.update(state: .ending, progress: 0)
        #expect(style.view.accessibilityValue == "刷新完成")
    }

    @Test("setTheme updates theme without replacing the view")
    func themeSwitchKeepsView() {
        let style = TaijiRefreshStyle(theme: .light)
        let view = style.view

        style.setTheme(.dark, animated: true)

        #expect(style.theme == .dark)
        #expect(style.view === view)
    }

    @Test("view creates expected visual layers after layout")
    func viewCreatesVisualLayers() throws {
        let style = TaijiRefreshStyle()
        style.view.frame = CGRect(x: 0, y: 0, width: 390, height: 92)
        style.view.layoutIfNeeded()

        let taijiView = try #require(style.view as? TaijiRefreshView)

        #expect(taijiView.debugLayerNames.contains("mist"))
        #expect(taijiView.debugLayerNames.contains("backArc"))
        #expect(taijiView.debugLayerNames.contains("frontArc"))
        #expect(taijiView.debugLayerNames.contains("body"))
        #expect(taijiView.debugLayerNames.contains("coreImageRefraction"))
        #expect(taijiView.debugLayerNames.contains("particleEmitter"))
        #expect(taijiView.debugLayerNames.contains("ripple"))
        #expect(taijiView.debugParticleCount <= 3)
    }

    @Test("taiji visual diameter stays compact inside refresh header")
    func visualDiameterIsCompact() throws {
        let style = TaijiRefreshStyle()
        style.view.frame = CGRect(x: 0, y: 0, width: 390, height: 92)
        style.view.layoutIfNeeded()

        let taijiView = try #require(style.view as? TaijiRefreshView)

        #expect(taijiView.debugBodyFrame.width >= 44)
        #expect(taijiView.debugBodyFrame.width <= 56)
        #expect(taijiView.debugBodyFrame.height == taijiView.debugBodyFrame.width)
    }

    @Test("demo header keeps taiji clear of top chrome while pulling")
    func demoHeaderKeepsTaijiClearOfTopChrome() throws {
        let style = TaijiRefreshStyle(extent: 88)
        style.view.frame = CGRect(x: 0, y: 0, width: 390, height: 88)
        style.view.layoutIfNeeded()
        style.update(state: .pulling(1), progress: 1)

        let taijiView = try #require(style.view as? TaijiRefreshView)
        let bodyBounds = taijiView.debugBodyBounds
        let orbitFrame = taijiView.debugOrbitFrame

        #expect(bodyBounds.width <= 49)
        #expect(bodyBounds.height == bodyBounds.width)
        #expect(orbitFrame.width <= bodyBounds.width * 1.36)
        #expect(orbitFrame.height >= bodyBounds.height * 0.74)
    }

    @Test("pulling ambient mist stays local and clipped to an oval")
    func pullingAmbientMistAvoidsRectangularPlate() throws {
        let style = TaijiRefreshStyle(extent: 88, theme: .dark)
        style.view.frame = CGRect(x: 0, y: 0, width: 390, height: 88)
        style.view.layoutIfNeeded()
        style.update(state: .pulling(1), progress: 1)

        let taijiView = try #require(style.view as? TaijiRefreshView)
        let mistLayer = try #require(taijiView.layer.sublayers?.first { $0.name == "mist" })

        #expect(mistLayer.frame.width <= taijiView.debugBodyFrame.width * 1.82)
        #expect(mistLayer.frame.height <= taijiView.debugBodyFrame.height * 1.50)
        #expect(mistLayer.mask != nil)
    }

    @Test("pulling and triggered keep body silhouette stable")
    func pullingAndTriggeredKeepBodyRotationReadable() {
        let pullingState = TaijiRefreshRenderState.make(
            state: .pulling(1),
            progress: 1,
            reduceMotion: false,
            reduceTransparency: false
        )
        let triggeredState = TaijiRefreshRenderState.make(
            state: .triggered,
            progress: 1,
            reduceMotion: false,
            reduceTransparency: false
        )
        let readableLimit = degrees(8)

        #expect(abs(pullingState.rotation) <= readableLimit)
        #expect(abs(triggeredState.rotation) <= readableLimit)
    }

    @Test("ending ripple remains local to taiji body")
    func endingRippleRemainsLocalToBody() throws {
        let style = TaijiRefreshStyle(extent: 88, theme: .dark)
        style.view.frame = CGRect(x: 0, y: 0, width: 390, height: 88)
        style.view.layoutIfNeeded()
        let taijiView = try #require(style.view as? TaijiRefreshView)

        style.update(state: RefreshState.ending, progress: 0)

        #expect(taijiView.debugRippleFrame.width <= taijiView.debugBodyBounds.width * 1.70)
        #expect(taijiView.debugRippleFrame.height <= style.view.bounds.height * 0.96)
    }

    @Test("refreshing starts and ending stops continuous animation")
    func refreshingAnimationLifecycle() throws {
        let style = TaijiRefreshStyle()
        let taijiView = try #require(style.view as? TaijiRefreshView)

        style.update(state: .refreshing, progress: 0)
        #expect(taijiView.isContinuousAnimationActive == true)

        style.update(state: .ending, progress: 0)
        #expect(taijiView.isContinuousAnimationActive == false)
    }

    @Test("refreshing rotates taiji body while pulling keeps body stable")
    func refreshingRotatesBodyWhilePullingKeepsBodyStable() throws {
        let style = TaijiRefreshStyle(theme: .dark)
        style.view.frame = CGRect(x: 0, y: 0, width: 390, height: 88)
        style.view.layoutIfNeeded()
        let taijiView = try #require(style.view as? TaijiRefreshView)

        style.update(state: .pulling(1), progress: 1)

        #expect(!taijiView.debugAnimationKeys.contains("taiji.rotation"))

        style.update(state: .refreshing, progress: 0)

        #expect(taijiView.isContinuousAnimationActive == true)
        #expect(taijiView.debugAnimationKeys.contains("taiji.refreshOrbit"))
        #expect(taijiView.debugAnimationKeys.contains("taiji.rotation"))

        style.update(state: .ending, progress: 0)

        #expect(!taijiView.debugAnimationKeys.contains("taiji.refreshOrbit"))
        #expect(!taijiView.debugAnimationKeys.contains("taiji.rotation"))
    }

    @Test("released refresh keeps taiji below top chrome in compact header")
    func releasedRefreshKeepsTaijiBelowTopChromeInCompactHeader() throws {
        let style = TaijiRefreshStyle(extent: 88, theme: .dark)
        style.view.frame = CGRect(x: 0, y: 0, width: 390, height: 88)
        style.view.layoutIfNeeded()
        let taijiView = try #require(style.view as? TaijiRefreshView)

        style.update(state: .pulling(1), progress: 1)
        #expect(taijiView.debugBodyFrame.midY <= 48)

        style.update(state: .refreshing, progress: 0)
        #expect(taijiView.debugBodyFrame.midY >= 58)
        #expect(taijiView.debugBodyFrame.maxY <= style.view.bounds.maxY - 2)

        style.update(state: .ending, progress: 0)
        #expect(taijiView.debugBodyFrame.midY >= 56)
        #expect(taijiView.debugBodyFrame.maxY <= style.view.bounds.maxY - 2)
    }

    @Test("pulling starts visible ambient motion")
    func pullingStartsAmbientMotion() throws {
        let style = TaijiRefreshStyle()
        style.view.frame = CGRect(x: 0, y: 0, width: 390, height: 92)
        style.view.layoutIfNeeded()
        let taijiView = try #require(style.view as? TaijiRefreshView)

        style.update(state: .pulling(0.62), progress: 0.62)

        #expect(taijiView.debugAnimationKeys.contains("taiji.pullOrbit"))
        #expect(!taijiView.debugAnimationKeys.contains("taiji.pullTwinkle"))

        style.update(state: .idle, progress: 0)

        #expect(!taijiView.debugAnimationKeys.contains("taiji.pullOrbit"))
    }

    @Test("theme switch records palette without resetting render state")
    func themeSwitchKeepsRenderState() throws {
        let style = TaijiRefreshStyle(theme: .light)
        let taijiView = try #require(style.view as? TaijiRefreshView)

        style.update(state: .pulling(0.7), progress: 0.7)
        let before = try #require(taijiView.lastRenderState)

        style.setTheme(.dark, animated: true)
        let after = try #require(taijiView.lastRenderState)

        #expect(before == after)
        #expect(taijiView.lastPalette == .dark)
        #expect(taijiView.debugAnimationKeys.contains { $0.hasPrefix("taiji.palette.") })
    }

    @Test("reduce motion uses glow pulse and ending uses ripple animation")
    func reducedMotionGlowPulseAndEndingRipple() throws {
        let style = TaijiRefreshStyle()
        style.view.frame = CGRect(x: 0, y: 0, width: 390, height: 92)
        style.view.layoutIfNeeded()
        let taijiView = try #require(style.view as? TaijiRefreshView)

        let reducedMotionState = TaijiRefreshRenderState.make(
            state: .refreshing,
            progress: 0,
            reduceMotion: true,
            reduceTransparency: false
        )
        taijiView.apply(
            renderState: reducedMotionState,
            palette: .dark,
            animated: false,
            reduceTransparency: false
        )

        #expect(taijiView.isContinuousAnimationActive == false)
        #expect(taijiView.debugAnimationKeys.contains("taiji.glowPulse"))

        let endingState = TaijiRefreshRenderState.make(
            state: .ending,
            progress: 0,
            reduceMotion: false,
            reduceTransparency: false
        )
        taijiView.apply(
            renderState: endingState,
            palette: .dark,
            animated: false,
            reduceTransparency: false
        )

        #expect(!taijiView.debugAnimationKeys.contains("taiji.glowPulse"))
        #expect(taijiView.debugAnimationKeys.contains("taiji.ripple"))
    }

    @Test("ending lifts and dissolves the taiji body")
    func endingUsesVanishAnimation() throws {
        let style = TaijiRefreshStyle()
        style.view.frame = CGRect(x: 0, y: 0, width: 390, height: 92)
        style.view.layoutIfNeeded()
        let taijiView = try #require(style.view as? TaijiRefreshView)

        let endingState = TaijiRefreshRenderState.make(
            state: .ending,
            progress: 0,
            reduceMotion: false,
            reduceTransparency: false
        )
        taijiView.apply(
            renderState: endingState,
            palette: .dark,
            animated: false,
            reduceTransparency: false
        )

        #expect(taijiView.debugAnimationKeys.contains("taiji.ripple"))
        #expect(taijiView.debugAnimationKeys.contains("taiji.vanish"))

        let pullingState = TaijiRefreshRenderState.make(
            state: .pulling(0.25),
            progress: 0.25,
            reduceMotion: false,
            reduceTransparency: false
        )
        taijiView.apply(
            renderState: pullingState,
            palette: .dark,
            animated: false,
            reduceTransparency: false
        )

        #expect(!taijiView.debugAnimationKeys.contains("taiji.vanish"))
    }

    private func findLabels(in view: UIView) -> [UILabel] {
        var labels: [UILabel] = []
        if let label = view as? UILabel {
            labels.append(label)
        }
        for subview in view.subviews {
            labels.append(contentsOf: findLabels(in: subview))
        }
        return labels
    }

    private func degrees(_ value: CGFloat) -> CGFloat {
        value * .pi / 180
    }
}
