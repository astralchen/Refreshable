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
        #expect(taijiView.debugLayerNames.contains("ripple"))
        #expect(taijiView.debugParticleCount == 18)
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

    @Test("refreshing starts and ending stops continuous animation")
    func refreshingAnimationLifecycle() throws {
        let style = TaijiRefreshStyle()
        let taijiView = try #require(style.view as? TaijiRefreshView)

        style.update(state: .refreshing, progress: 0)
        #expect(taijiView.isContinuousAnimationActive == true)

        style.update(state: .ending, progress: 0)
        #expect(taijiView.isContinuousAnimationActive == false)
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
}
