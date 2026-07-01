import UIKit

struct TaijiRefreshRenderState: Equatable {
    var bodyAlpha: CGFloat
    var bodyScale: CGFloat
    var bodyVerticalOffsetRatio: CGFloat
    var rotation: CGFloat
    var preservesCurrentRotation: Bool
    var glowIntensity: CGFloat
    var mistAlpha: CGFloat
    var arcAlpha: CGFloat
    var arcSweep: CGFloat
    var arcTilt: CGFloat
    var particleIntensity: CGFloat
    var particleCount: Int
    var rippleProgress: CGFloat
    var continuousRotationSpeed: CGFloat
    var usesGlowPulse: Bool
    var glassOpacity: CGFloat
    var usesTransparentGlass: Bool

    static func make(
        state: RefreshState,
        progress: CGFloat,
        reduceMotion: Bool,
        reduceTransparency: Bool
    ) -> TaijiRefreshRenderState {
        let p = clampedProgress(from: state, fallback: progress)
        let transparentGlass = !reduceTransparency
        let glassOpacity: CGFloat = reduceTransparency ? 0.92 : 0.62

        switch state {
        case .idle:
            return TaijiRefreshRenderState(
                bodyAlpha: 0,
                bodyScale: 0.86,
                bodyVerticalOffsetRatio: 0,
                rotation: 0,
                preservesCurrentRotation: true,
                glowIntensity: 0,
                mistAlpha: 0,
                arcAlpha: 0,
                arcSweep: degrees(15),
                arcTilt: degrees(62),
                particleIntensity: 0,
                particleCount: 0,
                rippleProgress: 0,
                continuousRotationSpeed: 0,
                usesGlowPulse: false,
                glassOpacity: glassOpacity,
                usesTransparentGlass: transparentGlass
            )

        case .pulling(_):
            let eased = easeOutCubic(p)
            return TaijiRefreshRenderState(
                bodyAlpha: lerp(0.15, 1.0, p),
                bodyScale: lerp(0.86, 1.0, eased),
                bodyVerticalOffsetRatio: 0,
                rotation: 0,
                preservesCurrentRotation: false,
                glowIntensity: lerp(0.20, 0.86, p),
                mistAlpha: lerp(0.0, 0.66, p),
                arcAlpha: lerp(0.25, 1.0, p),
                arcSweep: degrees(lerp(15, 176, p)),
                arcTilt: degrees(62),
                particleIntensity: lerp(0.15, 0.94, p),
                particleCount: Int(lerp(2, 16, p).rounded()),
                rippleProgress: 0,
                continuousRotationSpeed: 0,
                usesGlowPulse: false,
                glassOpacity: glassOpacity,
                usesTransparentGlass: transparentGlass
            )

        case .triggered:
            return TaijiRefreshRenderState(
                bodyAlpha: 1,
                bodyScale: 1.04,
                bodyVerticalOffsetRatio: 0,
                rotation: 0,
                preservesCurrentRotation: false,
                glowIntensity: 0.98,
                mistAlpha: 0.70,
                arcAlpha: 1,
                arcSweep: degrees(204),
                arcTilt: degrees(62),
                particleIntensity: 1.0,
                particleCount: 18,
                rippleProgress: 0,
                continuousRotationSpeed: 0,
                usesGlowPulse: false,
                glassOpacity: glassOpacity,
                usesTransparentGlass: transparentGlass
            )

        case .refreshing:
            return TaijiRefreshRenderState(
                bodyAlpha: 1,
                bodyScale: 1,
                bodyVerticalOffsetRatio: 0.18,
                rotation: 0,
                preservesCurrentRotation: true,
                glowIntensity: 0.86,
                mistAlpha: 0.60,
                arcAlpha: 1,
                arcSweep: degrees(188),
                arcTilt: degrees(62),
                particleIntensity: 0.92,
                particleCount: 18,
                rippleProgress: 0,
                continuousRotationSpeed: reduceMotion ? 0 : 1.0,
                usesGlowPulse: reduceMotion,
                glassOpacity: glassOpacity,
                usesTransparentGlass: transparentGlass
            )

        case .ending:
            return TaijiRefreshRenderState(
                bodyAlpha: 0.64,
                bodyScale: 0.92,
                bodyVerticalOffsetRatio: 0.16,
                rotation: 0,
                preservesCurrentRotation: true,
                glowIntensity: 0.30,
                mistAlpha: 0,
                arcAlpha: 0.22,
                arcSweep: degrees(92),
                arcTilt: degrees(62),
                particleIntensity: 0.18,
                particleCount: 4,
                rippleProgress: 1,
                continuousRotationSpeed: 0,
                usesGlowPulse: false,
                glassOpacity: glassOpacity,
                usesTransparentGlass: transparentGlass
            )

        case .noMoreData:
            return TaijiRefreshRenderState(
                bodyAlpha: 0.55,
                bodyScale: 0.96,
                bodyVerticalOffsetRatio: 0,
                rotation: 0,
                preservesCurrentRotation: true,
                glowIntensity: 0.24,
                mistAlpha: 0.10,
                arcAlpha: 0.18,
                arcSweep: degrees(68),
                arcTilt: degrees(62),
                particleIntensity: 0,
                particleCount: 0,
                rippleProgress: 0,
                continuousRotationSpeed: 0,
                usesGlowPulse: false,
                glassOpacity: glassOpacity,
                usesTransparentGlass: transparentGlass
            )
        }
    }

    private static func clampedProgress(from state: RefreshState, fallback: CGFloat) -> CGFloat {
        let raw: CGFloat
        if case .pulling(let stateProgress) = state {
            raw = stateProgress
        } else {
            raw = fallback
        }

        guard raw.isFinite else { return 0 }
        return min(max(raw, 0), 1)
    }

    private static func lerp(_ start: CGFloat, _ end: CGFloat, _ t: CGFloat) -> CGFloat {
        start + (end - start) * t
    }

    private static func easeOutCubic(_ t: CGFloat) -> CGFloat {
        1 - pow(1 - t, 3)
    }

    private static func degrees(_ value: CGFloat) -> CGFloat {
        value * .pi / 180
    }
}
