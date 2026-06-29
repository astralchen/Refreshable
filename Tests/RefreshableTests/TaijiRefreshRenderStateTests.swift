import Testing
@testable import Refreshable
import UIKit

@Suite("TaijiRefreshRenderState")
@MainActor
struct TaijiRefreshRenderStateTests {

    @Test("pulling progress clamps to zero and one")
    func pullingProgressClamps() {
        let low = TaijiRefreshRenderState.make(
            state: .pulling(-0.4),
            progress: -0.4,
            reduceMotion: false,
            reduceTransparency: false
        )
        let zero = TaijiRefreshRenderState.make(
            state: .pulling(0),
            progress: 0,
            reduceMotion: false,
            reduceTransparency: false
        )
        let high = TaijiRefreshRenderState.make(
            state: .pulling(2),
            progress: 2,
            reduceMotion: false,
            reduceTransparency: false
        )
        let one = TaijiRefreshRenderState.make(
            state: .pulling(1),
            progress: 1,
            reduceMotion: false,
            reduceTransparency: false
        )

        #expect(low == zero)
        #expect(high == one)
    }

    @Test("pulling increases alpha scale glow arc and particles")
    func pullingIsMonotonic() {
        let p0 = TaijiRefreshRenderState.make(state: .pulling(0), progress: 0, reduceMotion: false, reduceTransparency: false)
        let p50 = TaijiRefreshRenderState.make(state: .pulling(0.5), progress: 0.5, reduceMotion: false, reduceTransparency: false)
        let p100 = TaijiRefreshRenderState.make(state: .pulling(1), progress: 1, reduceMotion: false, reduceTransparency: false)

        #expect(p0.bodyAlpha < p50.bodyAlpha)
        #expect(p50.bodyAlpha < p100.bodyAlpha)
        #expect(p0.bodyScale < p50.bodyScale)
        #expect(p50.bodyScale < p100.bodyScale)
        #expect(p0.glowIntensity < p50.glowIntensity)
        #expect(p50.glowIntensity < p100.glowIntensity)
        #expect(p0.arcSweep < p50.arcSweep)
        #expect(p50.arcSweep < p100.arcSweep)
        #expect(p0.particleCount < p50.particleCount)
        #expect(p50.particleCount < p100.particleCount)
    }

    @Test("triggered is stronger than fully pulled")
    func triggeredIsStrongerThanPulling() {
        let pulled = TaijiRefreshRenderState.make(state: .pulling(1), progress: 1, reduceMotion: false, reduceTransparency: false)
        let triggered = TaijiRefreshRenderState.make(state: .triggered, progress: 1, reduceMotion: false, reduceTransparency: false)

        #expect(triggered.bodyScale > pulled.bodyScale)
        #expect(triggered.glowIntensity > pulled.glowIntensity)
        #expect(triggered.particleCount > pulled.particleCount)
        #expect(triggered.arcSweep > pulled.arcSweep)
    }

    @Test("pulling and triggered arcs stay partial instead of becoming ceremonial rings")
    func arcsStayPartial() {
        let pulled = TaijiRefreshRenderState.make(state: .pulling(1), progress: 1, reduceMotion: false, reduceTransparency: false)
        let triggered = TaijiRefreshRenderState.make(state: .triggered, progress: 1, reduceMotion: false, reduceTransparency: false)

        #expect(pulled.arcSweep <= Self.degrees(180))
        #expect(triggered.arcSweep <= Self.degrees(210))
        #expect(triggered.arcSweep > pulled.arcSweep)
    }

    @Test("fully pulled state has legible local cosmic charge")
    func fullyPulledStateHasLocalCharge() {
        let pulled = TaijiRefreshRenderState.make(state: .pulling(1), progress: 1, reduceMotion: false, reduceTransparency: false)

        #expect(pulled.glowIntensity >= 0.82)
        #expect(pulled.mistAlpha >= 0.62)
        #expect(pulled.particleIntensity >= 0.90)
    }

    @Test("particle counts fit the pooled particle layer budget")
    func particleCountsFitPoolBudget() {
        let triggered = TaijiRefreshRenderState.make(state: .triggered, progress: 1, reduceMotion: false, reduceTransparency: false)
        let refreshing = TaijiRefreshRenderState.make(state: .refreshing, progress: 0, reduceMotion: false, reduceTransparency: false)

        #expect(triggered.particleCount <= 18)
        #expect(refreshing.particleCount <= 18)
    }

    @Test("refreshing enables continuous rotation unless reduce motion is enabled")
    func refreshingAnimationModes() {
        let fullMotion = TaijiRefreshRenderState.make(state: .refreshing, progress: 0, reduceMotion: false, reduceTransparency: false)
        let reducedMotion = TaijiRefreshRenderState.make(state: .refreshing, progress: 0, reduceMotion: true, reduceTransparency: false)

        #expect(fullMotion.continuousRotationSpeed > 0)
        #expect(fullMotion.usesGlowPulse == false)
        #expect(reducedMotion.continuousRotationSpeed == 0)
        #expect(reducedMotion.usesGlowPulse == true)
    }

    @Test("ending enables ripple and fade")
    func endingEnablesRipple() {
        let ending = TaijiRefreshRenderState.make(state: .ending, progress: 0, reduceMotion: false, reduceTransparency: false)

        #expect(ending.rippleProgress == 1)
        #expect(ending.bodyScale < 1)
        #expect(ending.mistAlpha == 0)
        #expect(ending.particleCount < 8)
    }

    @Test("reduce transparency makes glass more solid")
    func reduceTransparencyMakesGlassSolid() {
        let normal = TaijiRefreshRenderState.make(state: .pulling(1), progress: 1, reduceMotion: false, reduceTransparency: false)
        let reduced = TaijiRefreshRenderState.make(state: .pulling(1), progress: 1, reduceMotion: false, reduceTransparency: true)

        #expect(normal.glassOpacity < reduced.glassOpacity)
        #expect(normal.usesTransparentGlass == true)
        #expect(reduced.usesTransparentGlass == false)
    }

    private static func degrees(_ value: CGFloat) -> CGFloat {
        value * .pi / 180
    }
}
