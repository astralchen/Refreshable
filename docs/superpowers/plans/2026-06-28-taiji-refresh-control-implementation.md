# Taiji Refresh Control Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a compact, theme-aware, no-visible-text Taiji refresh style for `Refreshable` that fits an 80-100pt real `UIScrollView` refresh header.

**Architecture:** Keep the existing `RefreshableStyle` API and add the feature as a new style plus a dedicated view. Split pure render-state calculation from Core Animation side effects so progress, theme, accessibility, and state mapping can be unit tested without snapshot infrastructure.

**Tech Stack:** Swift 6.0, UIKit integration, QuartzCore/Core Animation layers and animations, Core Graphics drawing, Swift Testing, iOS 13+, no third-party dependencies.

---

## Source Inputs

- Design spec: `docs/superpowers/specs/2026-06-28-taiji-refresh-control-design.md`
- Reference image: `docs/superpowers/specs/assets/taiji-refresh-header-reference.png`
- Current style API: `Sources/Refreshable/RefreshableStyle.swift`
- Current state model: `Sources/Refreshable/RefreshState.swift`
- Existing default styles: `Sources/Refreshable/DefaultHeaderStyle.swift`, `Sources/Refreshable/DefaultFooterStyle.swift`
- Current Demo tab wiring: `Demo/Demo/DemoTabBarController.swift`

## Apple Framework Technical Analysis

The implementation should use more than UIKit, but UIKit remains the integration shell because the package is built around `UIScrollView` and `UIView`.

- **UIKit:** Required for `RefreshableStyle.view`, `UIScrollView` installation, trait collection resolution, accessibility state, `UIAccessibility.isReduceMotionEnabled`, and `UIAccessibility.isReduceTransparencyEnabled`.
- **QuartzCore / Core Animation:** Primary visual engine. Use `CALayer`, `CAShapeLayer`, `CAGradientLayer`, `CABasicAnimation`, `CAKeyframeAnimation`, and `CATransaction` for mist, arcs, glow, particles, ripple, theme crossfade, and refreshing loops.
- **Core Graphics:** Primary taiji body renderer. Use a custom `CALayer.draw(in:)` implementation to draw the glass taiji body, edge rim, yin-yang lobes, small cores, and glossy highlight at 44-56pt.
- **Core Image:** Do not use in the first implementation. The mist is small and can be rendered with gradient layers; Core Image would add filter/rendering complexity without solving a current requirement.
- **Accelerate / vImage:** Do not use in the first implementation. Blur and glow are layer-driven and low resolution; CPU image processing is unnecessary.
- **Metal:** Do not use in the first implementation. A refresh header needs low overhead, package simplicity, and deterministic UIKit composition, not a GPU render pipeline.
- **SceneKit / RealityKit:** Do not use in the first implementation. The 3D feel comes from perspective transforms, depth ordering, rim highlights, and alpha variation; a full 3D scene would be heavy for a reusable refresh control.
- **SpriteKit:** Do not use in the first implementation. Particle behavior is limited to 18 close-orbiting points and can be handled with pooled `CALayer`s.
- **SwiftUI:** Do not use in the package implementation. A SwiftUI wrapper can be a later add-on, but this package's API and Demo are UIKit-first.

## File Structure

- Create `Sources/Refreshable/TaijiRefreshTheme.swift`: public theme and palette types, palette resolution from trait collections, and color equality.
- Create `Sources/Refreshable/TaijiRefreshRenderState.swift`: internal pure render model and deterministic state/progress mapping.
- Create `Sources/Refreshable/TaijiRefreshStyle.swift`: public `RefreshableStyle` implementation, accessibility mapping, theme switching, and update orchestration.
- Create `Sources/Refreshable/TaijiRefreshView.swift`: internal layer tree, Core Graphics taiji body drawing, Core Animation visual application, and animation lifecycle.
- Create `Tests/RefreshableTests/TaijiRefreshThemeTests.swift`: palette resolution and custom palette behavior.
- Create `Tests/RefreshableTests/TaijiRefreshRenderStateTests.swift`: progress clamping, monotonic pulling values, state distinction, reduce-motion mapping, and reduce-transparency mapping.
- Create `Tests/RefreshableTests/TaijiRefreshStyleTests.swift`: public style defaults, accessibility values, no visible text subviews, view continuity during theme changes, and animation flags.
- Create `Demo/Demo/TaijiRefreshDemoController.swift`: realistic table demo with theme segmented control and top refresh using `TaijiRefreshStyle`.
- Modify `Demo/Demo/DemoTabBarController.swift`: add a Taiji demo tab.
- Modify `README.md`: document the new style and theme switching usage.

---

### Task 1: Add Theme And Palette Model

**Files:**
- Create: `Sources/Refreshable/TaijiRefreshTheme.swift`
- Create: `Tests/RefreshableTests/TaijiRefreshThemeTests.swift`

- [ ] **Step 1: Write failing theme tests**

Create `Tests/RefreshableTests/TaijiRefreshThemeTests.swift`:

```swift
import Testing
@testable import Refreshable
import UIKit

@Suite("TaijiRefreshTheme")
@MainActor
struct TaijiRefreshThemeTests {

    @Test("system theme resolves different light and dark palettes")
    func systemThemeResolvesTraits() {
        let light = TaijiRefreshTheme.system.resolvedPalette(
            for: UITraitCollection(userInterfaceStyle: .light)
        )
        let dark = TaijiRefreshTheme.system.resolvedPalette(
            for: UITraitCollection(userInterfaceStyle: .dark)
        )

        #expect(light != dark)
        #expect(!light.backgroundTint.isEqual(dark.backgroundTint))
        #expect(!light.shadowCore.isEqual(dark.shadowCore))
    }

    @Test("explicit themes ignore current trait style")
    func explicitThemesIgnoreTraits() {
        let lightInDarkTraits = TaijiRefreshTheme.light.resolvedPalette(
            for: UITraitCollection(userInterfaceStyle: .dark)
        )
        let darkInLightTraits = TaijiRefreshTheme.dark.resolvedPalette(
            for: UITraitCollection(userInterfaceStyle: .light)
        )

        #expect(lightInDarkTraits == .light)
        #expect(darkInLightTraits == .dark)
    }

    @Test("custom theme returns the supplied palette")
    func customThemeReturnsPalette() {
        let palette = TaijiRefreshPalette(
            backgroundTint: .red,
            primaryGlow: .green,
            secondaryGlow: .blue,
            glassHighlight: .white,
            shadowCore: .black,
            particle: .yellow
        )

        let resolved = TaijiRefreshTheme.custom(palette).resolvedPalette(
            for: UITraitCollection(userInterfaceStyle: .dark)
        )

        #expect(resolved == palette)
    }
}
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
xcodebuild test -scheme Refreshable -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation -only-testing:RefreshableTests/TaijiRefreshThemeTests
```

Expected: build fails with `cannot find 'TaijiRefreshTheme' in scope`.

- [ ] **Step 3: Implement theme and palette types**

Create `Sources/Refreshable/TaijiRefreshTheme.swift`:

```swift
import UIKit

/// Theme selection for the Taiji refresh control.
public enum TaijiRefreshTheme: Equatable, Sendable {
    case system
    case light
    case dark
    case custom(TaijiRefreshPalette)
}

extension TaijiRefreshTheme {
    func resolvedPalette(for traitCollection: UITraitCollection) -> TaijiRefreshPalette {
        switch self {
        case .system:
            return traitCollection.userInterfaceStyle == .dark ? .dark : .light
        case .light:
            return .light
        case .dark:
            return .dark
        case .custom(let palette):
            return palette
        }
    }
}

/// Color palette for the Taiji refresh control.
public struct TaijiRefreshPalette: Equatable, @unchecked Sendable {
    public var backgroundTint: UIColor
    public var primaryGlow: UIColor
    public var secondaryGlow: UIColor
    public var glassHighlight: UIColor
    public var shadowCore: UIColor
    public var particle: UIColor

    public init(
        backgroundTint: UIColor,
        primaryGlow: UIColor,
        secondaryGlow: UIColor,
        glassHighlight: UIColor,
        shadowCore: UIColor,
        particle: UIColor
    ) {
        self.backgroundTint = backgroundTint
        self.primaryGlow = primaryGlow
        self.secondaryGlow = secondaryGlow
        self.glassHighlight = glassHighlight
        self.shadowCore = shadowCore
        self.particle = particle
    }

    public static let dark = TaijiRefreshPalette(
        backgroundTint: UIColor(red: 0.02, green: 0.03, blue: 0.09, alpha: 0.18),
        primaryGlow: UIColor(red: 0.35, green: 0.82, blue: 1.0, alpha: 1.0),
        secondaryGlow: UIColor(red: 0.62, green: 0.36, blue: 1.0, alpha: 1.0),
        glassHighlight: UIColor(white: 1.0, alpha: 0.92),
        shadowCore: UIColor(red: 0.04, green: 0.03, blue: 0.18, alpha: 0.96),
        particle: UIColor(red: 0.82, green: 0.92, blue: 1.0, alpha: 1.0)
    )

    public static let light = TaijiRefreshPalette(
        backgroundTint: UIColor(red: 0.94, green: 0.96, blue: 1.0, alpha: 0.14),
        primaryGlow: UIColor(red: 0.0, green: 0.62, blue: 0.95, alpha: 1.0),
        secondaryGlow: UIColor(red: 0.52, green: 0.34, blue: 0.92, alpha: 1.0),
        glassHighlight: UIColor(white: 1.0, alpha: 0.96),
        shadowCore: UIColor(red: 0.20, green: 0.20, blue: 0.48, alpha: 0.88),
        particle: UIColor(red: 0.28, green: 0.42, blue: 0.78, alpha: 1.0)
    )

    public static func == (lhs: TaijiRefreshPalette, rhs: TaijiRefreshPalette) -> Bool {
        lhs.backgroundTint.isEqual(rhs.backgroundTint)
            && lhs.primaryGlow.isEqual(rhs.primaryGlow)
            && lhs.secondaryGlow.isEqual(rhs.secondaryGlow)
            && lhs.glassHighlight.isEqual(rhs.glassHighlight)
            && lhs.shadowCore.isEqual(rhs.shadowCore)
            && lhs.particle.isEqual(rhs.particle)
    }
}
```

- [ ] **Step 4: Run tests and verify pass**

Run:

```bash
xcodebuild test -scheme Refreshable -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation -only-testing:RefreshableTests/TaijiRefreshThemeTests
```

Expected: `TaijiRefreshThemeTests` passes.

- [ ] **Step 5: Commit**

```bash
git add Sources/Refreshable/TaijiRefreshTheme.swift Tests/RefreshableTests/TaijiRefreshThemeTests.swift
git commit -m "feat: add taiji refresh theme model"
```

---

### Task 2: Add Pure Render-State Mapping

**Files:**
- Create: `Sources/Refreshable/TaijiRefreshRenderState.swift`
- Create: `Tests/RefreshableTests/TaijiRefreshRenderStateTests.swift`

- [ ] **Step 1: Write failing render-state tests**

Create `Tests/RefreshableTests/TaijiRefreshRenderStateTests.swift`:

```swift
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
}
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
xcodebuild test -scheme Refreshable -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation -only-testing:RefreshableTests/TaijiRefreshRenderStateTests
```

Expected: build fails with `cannot find 'TaijiRefreshRenderState' in scope`.

- [ ] **Step 3: Implement deterministic render-state mapping**

Create `Sources/Refreshable/TaijiRefreshRenderState.swift`:

```swift
import UIKit

struct TaijiRefreshRenderState: Equatable {
    var bodyAlpha: CGFloat
    var bodyScale: CGFloat
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
                rotation: degrees(140) * eased,
                preservesCurrentRotation: false,
                glowIntensity: lerp(0.20, 0.75, p),
                mistAlpha: lerp(0.0, 0.55, p),
                arcAlpha: lerp(0.25, 1.0, p),
                arcSweep: degrees(lerp(15, 260, p)),
                arcTilt: degrees(62),
                particleIntensity: lerp(0.15, 0.80, p),
                particleCount: Int((lerp(2, 18, p)).rounded()),
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
                rotation: degrees(158),
                preservesCurrentRotation: false,
                glowIntensity: 0.90,
                mistAlpha: 0.58,
                arcAlpha: 1,
                arcSweep: degrees(286),
                arcTilt: degrees(62),
                particleIntensity: 0.92,
                particleCount: 22,
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
                rotation: 0,
                preservesCurrentRotation: true,
                glowIntensity: 0.86,
                mistAlpha: 0.52,
                arcAlpha: 1,
                arcSweep: degrees(224),
                arcTilt: degrees(62),
                particleIntensity: 0.86,
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
```

- [ ] **Step 4: Run tests and verify pass**

Run:

```bash
xcodebuild test -scheme Refreshable -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation -only-testing:RefreshableTests/TaijiRefreshRenderStateTests
```

Expected: `TaijiRefreshRenderStateTests` passes.

- [ ] **Step 5: Commit**

```bash
git add Sources/Refreshable/TaijiRefreshRenderState.swift Tests/RefreshableTests/TaijiRefreshRenderStateTests.swift
git commit -m "feat: add taiji refresh render state"
```

---

### Task 3: Add Public Style Shell And Accessibility

**Files:**
- Create: `Sources/Refreshable/TaijiRefreshStyle.swift`
- Create: `Sources/Refreshable/TaijiRefreshView.swift`
- Create: `Tests/RefreshableTests/TaijiRefreshStyleTests.swift`

- [ ] **Step 1: Write failing style tests**

Create `Tests/RefreshableTests/TaijiRefreshStyleTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
xcodebuild test -scheme Refreshable -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation -only-testing:RefreshableTests/TaijiRefreshStyleTests
```

Expected: build fails with `cannot find 'TaijiRefreshStyle' in scope`.

- [ ] **Step 3: Add a minimal TaijiRefreshView shell**

Create `Sources/Refreshable/TaijiRefreshView.swift`:

```swift
import UIKit
import QuartzCore

final class TaijiRefreshView: UIView {
    var onTraitCollectionChange: ((UITraitCollection) -> Void)?
    private(set) var lastRenderState: TaijiRefreshRenderState?
    private(set) var lastPalette: TaijiRefreshPalette?
    private(set) var isContinuousAnimationActive = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        clipsToBounds = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle else { return }
        onTraitCollectionChange?(traitCollection)
    }

    func apply(
        renderState: TaijiRefreshRenderState,
        palette: TaijiRefreshPalette,
        animated: Bool,
        reduceTransparency: Bool
    ) {
        lastRenderState = renderState
        lastPalette = palette
        isContinuousAnimationActive = renderState.continuousRotationSpeed > 0
    }
}
```

- [ ] **Step 4: Add public TaijiRefreshStyle**

Create `Sources/Refreshable/TaijiRefreshStyle.swift`:

```swift
import UIKit

/// Compact cosmic glass Taiji refresh style.
@MainActor
public final class TaijiRefreshStyle: RefreshableStyle {
    public let view: UIView
    public let extent: CGFloat
    public private(set) var theme: TaijiRefreshTheme

    private let taijiView: TaijiRefreshView
    private var currentState: RefreshState = .idle
    private var currentProgress: CGFloat = 0

    public init(
        extent: CGFloat = 92,
        theme: TaijiRefreshTheme = .system,
        accessibilityLabel: String = "刷新"
    ) {
        self.extent = extent
        self.theme = theme

        let taijiView = TaijiRefreshView(frame: CGRect(x: 0, y: 0, width: 0, height: extent))
        taijiView.isAccessibilityElement = true
        taijiView.accessibilityLabel = accessibilityLabel
        taijiView.accessibilityTraits = [.updatesFrequently]
        self.taijiView = taijiView
        self.view = taijiView

        taijiView.onTraitCollectionChange = { [weak self] _ in
            guard let self else { return }
            self.applyCurrentState(animated: true)
        }
    }

    public func setTheme(_ theme: TaijiRefreshTheme, animated: Bool = true) {
        guard self.theme != theme else { return }
        self.theme = theme
        applyCurrentState(animated: animated)
    }

    public func update(state: RefreshState, progress: CGFloat) {
        currentState = state
        currentProgress = progress
        view.accessibilityValue = Self.accessibilityValue(for: state)
        applyCurrentState(animated: false)
    }

    private func applyCurrentState(animated: Bool) {
        let renderState = TaijiRefreshRenderState.make(
            state: currentState,
            progress: currentProgress,
            reduceMotion: UIAccessibility.isReduceMotionEnabled,
            reduceTransparency: UIAccessibility.isReduceTransparencyEnabled
        )
        let palette = theme.resolvedPalette(for: view.traitCollection)
        taijiView.apply(
            renderState: renderState,
            palette: palette,
            animated: animated,
            reduceTransparency: UIAccessibility.isReduceTransparencyEnabled
        )
    }

    private static func accessibilityValue(for state: RefreshState) -> String {
        switch state {
        case .idle:
            return "未刷新"
        case .pulling(_):
            return "下拉中"
        case .triggered:
            return "释放刷新"
        case .refreshing:
            return "正在刷新"
        case .ending:
            return "刷新完成"
        case .noMoreData:
            return "没有更多数据"
        }
    }
}
```

- [ ] **Step 5: Run tests and verify pass**

Run:

```bash
xcodebuild test -scheme Refreshable -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation -only-testing:RefreshableTests/TaijiRefreshStyleTests
```

Expected: `TaijiRefreshStyleTests` passes.

- [ ] **Step 6: Commit**

```bash
git add Sources/Refreshable/TaijiRefreshStyle.swift Sources/Refreshable/TaijiRefreshView.swift Tests/RefreshableTests/TaijiRefreshStyleTests.swift
git commit -m "feat: add taiji refresh style shell"
```

---

### Task 4: Build Core Animation Layer Tree

**Files:**
- Modify: `Sources/Refreshable/TaijiRefreshView.swift`
- Modify: `Tests/RefreshableTests/TaijiRefreshStyleTests.swift`

- [ ] **Step 1: Add layer-composition tests**

Append to `TaijiRefreshStyleTests`:

```swift
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
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
xcodebuild test -scheme Refreshable -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation -only-testing:RefreshableTests/TaijiRefreshStyleTests/viewCreatesVisualLayers -only-testing:RefreshableTests/TaijiRefreshStyleTests/visualDiameterIsCompact
```

Expected: build fails because `debugLayerNames`, `debugParticleCount`, and `debugBodyFrame` do not exist.

- [ ] **Step 3: Replace TaijiRefreshView with the layer tree**

Replace `Sources/Refreshable/TaijiRefreshView.swift` with:

```swift
import UIKit
import QuartzCore

final class TaijiRefreshView: UIView {
    var onTraitCollectionChange: ((UITraitCollection) -> Void)?
    private(set) var lastRenderState: TaijiRefreshRenderState?
    private(set) var lastPalette: TaijiRefreshPalette?
    private(set) var isContinuousAnimationActive = false

    private let mistLayer = CAGradientLayer()
    private let orbitContainerLayer = CALayer()
    private let backArcLayer = CAShapeLayer()
    private let frontArcLayer = CAShapeLayer()
    private let bodyContainerLayer = CALayer()
    private let glowLayer = CAGradientLayer()
    private let bodyLayer = TaijiBodyLayer()
    private let highlightLayer = CAShapeLayer()
    private let rippleLayer = CAShapeLayer()
    private let particleLayers: [CALayer] = (0..<18).map { _ in CALayer() }

    var debugLayerNames: [String] {
        [mistLayer, backArcLayer, frontArcLayer, bodyLayer, rippleLayer].compactMap(\.name)
    }

    var debugParticleCount: Int {
        particleLayers.count
    }

    var debugBodyFrame: CGRect {
        bodyContainerLayer.frame
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        clipsToBounds = true
        configureLayers()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle else { return }
        onTraitCollectionChange?(traitCollection)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let diameter = min(56, max(44, bounds.height * 0.58))
        let bodyFrame = CGRect(
            x: bounds.midX - diameter / 2,
            y: bounds.midY - diameter / 2,
            width: diameter,
            height: diameter
        ).integral
        let mistInset = -diameter * 0.92
        let mistFrame = bodyFrame.insetBy(dx: mistInset, dy: mistInset * 0.62)

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        mistLayer.frame = mistFrame
        orbitContainerLayer.frame = bounds
        bodyContainerLayer.frame = bodyFrame
        glowLayer.frame = bodyContainerLayer.bounds.insetBy(dx: -diameter * 0.32, dy: -diameter * 0.32)
        glowLayer.position = CGPoint(x: bodyContainerLayer.bounds.midX, y: bodyContainerLayer.bounds.midY)
        bodyLayer.frame = bodyContainerLayer.bounds
        highlightLayer.frame = bodyContainerLayer.bounds
        rippleLayer.frame = bounds

        updateArcPaths(in: bodyFrame)
        updateHighlightPath()
        updateRipplePath(progress: lastRenderState?.rippleProgress ?? 0)
        updateParticleFrames(around: bodyFrame)

        CATransaction.commit()
    }

    func apply(
        renderState: TaijiRefreshRenderState,
        palette: TaijiRefreshPalette,
        animated: Bool,
        reduceTransparency: Bool
    ) {
        lastRenderState = renderState
        lastPalette = palette
        bodyLayer.palette = palette
        bodyLayer.glassOpacity = renderState.glassOpacity
        bodyLayer.setNeedsDisplay()

        let updates = {
            self.mistLayer.opacity = Float(renderState.mistAlpha)
            self.backArcLayer.opacity = Float(renderState.arcAlpha * 0.42)
            self.frontArcLayer.opacity = Float(renderState.arcAlpha)
            self.bodyContainerLayer.opacity = Float(renderState.bodyAlpha)
            self.bodyContainerLayer.transform = self.bodyTransform(for: renderState)
            self.glowLayer.opacity = Float(renderState.glowIntensity)
            self.rippleLayer.opacity = Float(1 - renderState.rippleProgress)
            self.updateArcStroke(renderState: renderState, palette: palette)
            self.updateRipplePath(progress: renderState.rippleProgress)
            self.updateParticles(renderState: renderState, palette: palette)
        }

        if animated {
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.22)
            updates()
            CATransaction.commit()
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            updates()
            CATransaction.commit()
        }

        updateRefreshingAnimations(for: renderState)
    }

    private func configureLayers() {
        mistLayer.name = "mist"
        mistLayer.type = .radial
        mistLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        mistLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        mistLayer.locations = [0, 0.38, 1]

        orbitContainerLayer.sublayerTransform = {
            var transform = CATransform3DIdentity
            transform.m34 = -1 / 460
            return transform
        }()

        backArcLayer.name = "backArc"
        backArcLayer.fillColor = UIColor.clear.cgColor
        backArcLayer.lineCap = .round
        backArcLayer.lineWidth = 1.2

        frontArcLayer.name = "frontArc"
        frontArcLayer.fillColor = UIColor.clear.cgColor
        frontArcLayer.lineCap = .round
        frontArcLayer.lineWidth = 1.4

        bodyLayer.name = "body"
        bodyLayer.contentsScale = UIScreen.main.scale
        bodyLayer.needsDisplayOnBoundsChange = true

        glowLayer.type = .radial
        glowLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        glowLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        glowLayer.locations = [0, 0.48, 1]

        highlightLayer.fillColor = UIColor.clear.cgColor
        highlightLayer.strokeColor = UIColor.white.withAlphaComponent(0.72).cgColor
        highlightLayer.lineWidth = 1

        rippleLayer.name = "ripple"
        rippleLayer.fillColor = UIColor.clear.cgColor
        rippleLayer.lineWidth = 1

        layer.addSublayer(mistLayer)
        layer.addSublayer(orbitContainerLayer)
        orbitContainerLayer.addSublayer(backArcLayer)
        orbitContainerLayer.addSublayer(frontArcLayer)
        layer.addSublayer(bodyContainerLayer)
        bodyContainerLayer.addSublayer(glowLayer)
        bodyContainerLayer.addSublayer(bodyLayer)
        bodyContainerLayer.addSublayer(highlightLayer)
        layer.addSublayer(rippleLayer)

        particleLayers.enumerated().forEach { index, particle in
            particle.name = "particle-\(index)"
            particle.bounds = CGRect(x: 0, y: 0, width: 2, height: 2)
            particle.cornerRadius = 1
            particle.opacity = 0
            layer.addSublayer(particle)
        }
    }

    private func bodyTransform(for state: TaijiRefreshRenderState) -> CATransform3D {
        var transform = CATransform3DMakeScale(state.bodyScale, state.bodyScale, 1)
        if !state.preservesCurrentRotation {
            transform = CATransform3DRotate(transform, state.rotation, 0, 0, 1)
        }
        return transform
    }

    private func updateArcPaths(in bodyFrame: CGRect) {
        let radius = bodyFrame.width * 0.74
        let center = CGPoint(x: bodyFrame.midX, y: bodyFrame.midY)
        let backRect = CGRect(x: center.x - radius, y: center.y - radius * 0.46, width: radius * 2, height: radius * 0.92)
        let frontRect = CGRect(x: center.x - radius * 0.86, y: center.y - radius * 0.40, width: radius * 1.72, height: radius * 0.80)

        backArcLayer.path = UIBezierPath(ovalIn: backRect).cgPath
        frontArcLayer.path = UIBezierPath(ovalIn: frontRect).cgPath
        backArcLayer.transform = CATransform3DMakeRotation(.pi * 0.34, 1, 0, 0)
        frontArcLayer.transform = CATransform3DMakeRotation(.pi * -0.20, 1, 0, 0)
    }

    private func updateArcStroke(renderState: TaijiRefreshRenderState, palette: TaijiRefreshPalette) {
        backArcLayer.strokeColor = palette.secondaryGlow.withAlphaComponent(0.58).cgColor
        frontArcLayer.strokeColor = palette.primaryGlow.withAlphaComponent(0.86).cgColor
        backArcLayer.strokeStart = 0.08
        backArcLayer.strokeEnd = min(0.08 + renderState.arcSweep / (2 * .pi), 0.86)
        frontArcLayer.strokeStart = 0.52
        frontArcLayer.strokeEnd = min(0.52 + renderState.arcSweep / (2 * .pi) * 0.72, 0.98)

        mistLayer.colors = [
            palette.primaryGlow.withAlphaComponent(0.30).cgColor,
            palette.secondaryGlow.withAlphaComponent(0.22).cgColor,
            palette.backgroundTint.withAlphaComponent(0.0).cgColor,
        ]
        glowLayer.colors = [
            palette.primaryGlow.withAlphaComponent(0.46).cgColor,
            palette.secondaryGlow.withAlphaComponent(0.20).cgColor,
            UIColor.clear.cgColor,
        ]
        rippleLayer.strokeColor = palette.primaryGlow.withAlphaComponent(0.38).cgColor
    }

    private func updateHighlightPath() {
        let rect = bodyLayer.bounds.insetBy(dx: bodyLayer.bounds.width * 0.18, dy: bodyLayer.bounds.height * 0.14)
        highlightLayer.path = UIBezierPath(arcCenter: CGPoint(x: rect.midX, y: rect.midY), radius: rect.width * 0.42, startAngle: .pi * 1.06, endAngle: .pi * 1.74, clockwise: true).cgPath
    }

    private func updateRipplePath(progress: CGFloat) {
        let diameter = bodyContainerLayer.bounds.width
        let radius = diameter * (0.52 + progress * 0.90)
        let rect = CGRect(x: bodyContainerLayer.frame.midX - radius, y: bodyContainerLayer.frame.midY - radius, width: radius * 2, height: radius * 2)
        rippleLayer.path = UIBezierPath(ovalIn: rect).cgPath
    }

    private func updateParticleFrames(around bodyFrame: CGRect) {
        particleLayers.forEach { particle in
            particle.bounds = CGRect(x: 0, y: 0, width: 2, height: 2)
            particle.cornerRadius = 1
        }
        if let state = lastRenderState, let palette = lastPalette {
            updateParticles(renderState: state, palette: palette)
        }
    }

    private func updateParticles(renderState: TaijiRefreshRenderState, palette: TaijiRefreshPalette) {
        let center = CGPoint(x: bodyContainerLayer.frame.midX, y: bodyContainerLayer.frame.midY)
        let baseRadius = max(bodyContainerLayer.bounds.width * 0.62, 1)
        let visibleCount = min(renderState.particleCount, particleLayers.count)

        for (index, particle) in particleLayers.enumerated() {
            let isVisible = index < visibleCount
            let phase = CGFloat(index) / CGFloat(max(particleLayers.count, 1)) * 2 * .pi
            let radius = baseRadius + CGFloat(index % 5) * 2.1
            particle.position = CGPoint(
                x: center.x + cos(phase + renderState.rotation * 0.28) * radius,
                y: center.y + sin(phase + renderState.rotation * 0.28) * radius * 0.52
            )
            particle.backgroundColor = palette.particle.cgColor
            particle.opacity = isVisible ? Float(renderState.particleIntensity) : 0
        }
    }

    private func updateRefreshingAnimations(for state: TaijiRefreshRenderState) {
        if state.continuousRotationSpeed > 0 {
            isContinuousAnimationActive = true
            if bodyContainerLayer.animation(forKey: "taiji.rotation") == nil {
                let animation = CABasicAnimation(keyPath: "transform.rotation.z")
                animation.fromValue = 0
                animation.toValue = 2 * CGFloat.pi
                animation.duration = 1 / TimeInterval(state.continuousRotationSpeed)
                animation.repeatCount = .infinity
                animation.timingFunction = CAMediaTimingFunction(name: .linear)
                bodyContainerLayer.add(animation, forKey: "taiji.rotation")
            }
        } else {
            isContinuousAnimationActive = false
            bodyContainerLayer.removeAnimation(forKey: "taiji.rotation")
        }
    }
}

private final class TaijiBodyLayer: CALayer {
    var palette: TaijiRefreshPalette = .dark
    var glassOpacity: CGFloat = 0.62

    override func draw(in context: CGContext) {
        let rect = bounds.insetBy(dx: 1, dy: 1)
        guard rect.width > 1, rect.height > 1 else { return }

        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: 2), blur: 8, color: palette.primaryGlow.withAlphaComponent(0.35).cgColor)

        let circlePath = UIBezierPath(ovalIn: rect)
        context.addPath(circlePath.cgPath)
        context.clip()

        context.setFillColor(palette.glassHighlight.withAlphaComponent(glassOpacity).cgColor)
        context.fill(rect)

        let lowerPath = UIBezierPath()
        lowerPath.move(to: CGPoint(x: rect.midX, y: rect.minY))
        lowerPath.addArc(withCenter: CGPoint(x: rect.midX, y: rect.midY - rect.height * 0.25), radius: rect.width * 0.25, startAngle: -.pi / 2, endAngle: .pi / 2, clockwise: true)
        lowerPath.addArc(withCenter: CGPoint(x: rect.midX, y: rect.midY + rect.height * 0.25), radius: rect.width * 0.25, startAngle: -.pi / 2, endAngle: .pi / 2, clockwise: false)
        lowerPath.addArc(withCenter: CGPoint(x: rect.midX, y: rect.midY), radius: rect.width * 0.5, startAngle: .pi / 2, endAngle: -.pi / 2, clockwise: false)
        lowerPath.close()

        context.addPath(lowerPath.cgPath)
        context.setFillColor(palette.shadowCore.withAlphaComponent(0.88).cgColor)
        context.fillPath()

        let topCore = CGRect(x: rect.midX - rect.width * 0.10, y: rect.minY + rect.height * 0.24, width: rect.width * 0.20, height: rect.height * 0.20)
        let bottomCore = CGRect(x: rect.midX - rect.width * 0.10, y: rect.maxY - rect.height * 0.44, width: rect.width * 0.20, height: rect.height * 0.20)
        context.setFillColor(palette.shadowCore.withAlphaComponent(0.88).cgColor)
        context.fillEllipse(in: topCore)
        context.setFillColor(palette.glassHighlight.withAlphaComponent(0.82).cgColor)
        context.fillEllipse(in: bottomCore)

        context.restoreGState()

        context.setStrokeColor(palette.glassHighlight.withAlphaComponent(0.86).cgColor)
        context.setLineWidth(1.2)
        context.strokeEllipse(in: rect)
    }
}
```

- [ ] **Step 4: Run tests and verify pass**

Run:

```bash
xcodebuild test -scheme Refreshable -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation -only-testing:RefreshableTests/TaijiRefreshStyleTests
```

Expected: `TaijiRefreshStyleTests` passes.

- [ ] **Step 5: Commit**

```bash
git add Sources/Refreshable/TaijiRefreshView.swift Tests/RefreshableTests/TaijiRefreshStyleTests.swift
git commit -m "feat: render taiji refresh layer tree"
```

---

### Task 5: Add Motion Rules, Theme Crossfade, And Ending Ripple

**Files:**
- Modify: `Sources/Refreshable/TaijiRefreshView.swift`
- Modify: `Tests/RefreshableTests/TaijiRefreshStyleTests.swift`

- [ ] **Step 1: Add animation lifecycle tests**

Append to `TaijiRefreshStyleTests`:

```swift
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
}
```

- [ ] **Step 2: Run tests and verify current gap**

Run:

```bash
xcodebuild test -scheme Refreshable -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation -only-testing:RefreshableTests/TaijiRefreshStyleTests/refreshingAnimationLifecycle -only-testing:RefreshableTests/TaijiRefreshStyleTests/themeSwitchKeepsRenderState
```

Expected: the second test may pass from Task 3 shell behavior; the first test proves the lifecycle after layer work and must pass after this task.

- [ ] **Step 3: Add glow pulse and palette crossfade**

In `TaijiRefreshView.apply(...)`, replace the animation block with named helpers:

```swift
let previousPalette = lastPalette
lastRenderState = renderState
lastPalette = palette
bodyLayer.palette = palette
bodyLayer.glassOpacity = renderState.glassOpacity
bodyLayer.setNeedsDisplay()

applyLayerState(renderState: renderState, palette: palette, animated: animated)
if animated, let previousPalette {
    animatePalette(from: previousPalette, to: palette)
}
updateRefreshingAnimations(for: renderState)
```

Add these helpers inside `TaijiRefreshView`:

```swift
private func applyLayerState(
    renderState: TaijiRefreshRenderState,
    palette: TaijiRefreshPalette,
    animated: Bool
) {
    let updates = {
        self.mistLayer.opacity = Float(renderState.mistAlpha)
        self.backArcLayer.opacity = Float(renderState.arcAlpha * 0.42)
        self.frontArcLayer.opacity = Float(renderState.arcAlpha)
        self.bodyContainerLayer.opacity = Float(renderState.bodyAlpha)
        self.bodyContainerLayer.transform = self.bodyTransform(for: renderState)
        self.glowLayer.opacity = Float(renderState.glowIntensity)
        self.rippleLayer.opacity = Float(1 - renderState.rippleProgress)
        self.updateArcStroke(renderState: renderState, palette: palette)
        self.updateRipplePath(progress: renderState.rippleProgress)
        self.updateParticles(renderState: renderState, palette: palette)
    }

    CATransaction.begin()
    if animated {
        CATransaction.setAnimationDuration(0.22)
    } else {
        CATransaction.setDisableActions(true)
    }
    updates()
    CATransaction.commit()
}

private func animatePalette(from oldPalette: TaijiRefreshPalette, to newPalette: TaijiRefreshPalette) {
    addColorAnimation(to: frontArcLayer, keyPath: "strokeColor", from: oldPalette.primaryGlow.cgColor, to: newPalette.primaryGlow.cgColor)
    addColorAnimation(to: backArcLayer, keyPath: "strokeColor", from: oldPalette.secondaryGlow.cgColor, to: newPalette.secondaryGlow.cgColor)
    addColorAnimation(to: rippleLayer, keyPath: "strokeColor", from: oldPalette.primaryGlow.cgColor, to: newPalette.primaryGlow.cgColor)
}

private func addColorAnimation(to layer: CALayer, keyPath: String, from oldColor: CGColor, to newColor: CGColor) {
    let animation = CABasicAnimation(keyPath: keyPath)
    animation.fromValue = oldColor
    animation.toValue = newColor
    animation.duration = 0.22
    animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    layer.add(animation, forKey: "taiji.palette.\(keyPath)")
}
```

Replace `updateRefreshingAnimations(for:)` with:

```swift
private func updateRefreshingAnimations(for state: TaijiRefreshRenderState) {
    if state.continuousRotationSpeed > 0 {
        isContinuousAnimationActive = true
        glowLayer.removeAnimation(forKey: "taiji.glowPulse")
        if bodyContainerLayer.animation(forKey: "taiji.rotation") == nil {
            let animation = CABasicAnimation(keyPath: "transform.rotation.z")
            animation.fromValue = 0
            animation.toValue = 2 * CGFloat.pi
            animation.duration = 1 / TimeInterval(state.continuousRotationSpeed)
            animation.repeatCount = .infinity
            animation.timingFunction = CAMediaTimingFunction(name: .linear)
            bodyContainerLayer.add(animation, forKey: "taiji.rotation")
        }
    } else {
        isContinuousAnimationActive = false
        if let presentation = bodyContainerLayer.presentation() {
            bodyContainerLayer.transform = presentation.transform
        }
        bodyContainerLayer.removeAnimation(forKey: "taiji.rotation")
    }

    if state.usesGlowPulse {
        if glowLayer.animation(forKey: "taiji.glowPulse") == nil {
            let pulse = CABasicAnimation(keyPath: "opacity")
            pulse.fromValue = max(0.35, state.glowIntensity * 0.65)
            pulse.toValue = min(1.0, state.glowIntensity)
            pulse.duration = 1.1
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            glowLayer.add(pulse, forKey: "taiji.glowPulse")
        }
    } else {
        glowLayer.removeAnimation(forKey: "taiji.glowPulse")
    }

    if state.rippleProgress > 0 {
        let ripple = CABasicAnimation(keyPath: "opacity")
        ripple.fromValue = 0.7
        ripple.toValue = 0
        ripple.duration = 0.26
        ripple.timingFunction = CAMediaTimingFunction(name: .easeOut)
        rippleLayer.add(ripple, forKey: "taiji.ripple")
    } else {
        rippleLayer.removeAnimation(forKey: "taiji.ripple")
    }
}
```

- [ ] **Step 4: Run tests and verify pass**

Run:

```bash
xcodebuild test -scheme Refreshable -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation -only-testing:RefreshableTests/TaijiRefreshStyleTests
```

Expected: `TaijiRefreshStyleTests` passes.

- [ ] **Step 5: Commit**

```bash
git add Sources/Refreshable/TaijiRefreshView.swift Tests/RefreshableTests/TaijiRefreshStyleTests.swift
git commit -m "feat: animate taiji refresh states"
```

---

### Task 6: Add Realistic Demo With Theme Switching

**Files:**
- Create: `Demo/Demo/TaijiRefreshDemoController.swift`
- Modify: `Demo/Demo/DemoTabBarController.swift`

- [ ] **Step 1: Create Demo controller**

Create `Demo/Demo/TaijiRefreshDemoController.swift`:

```swift
import UIKit
import Refreshable

final class TaijiRefreshDemoController: UIViewController, UITableViewDataSource {
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let taijiStyle = TaijiRefreshStyle(extent: 92, theme: .system)
    private var items: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "太极刷新"
        view.backgroundColor = .systemBackground
        navigationItem.titleView = makeThemeControl()
        setupTableView()
        reloadItems(prefix: "星历", count: 24)
    }

    private func setupTableView() {
        tableView.frame = view.bounds
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.backgroundColor = .systemBackground
        tableView.rowHeight = 64
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        tableView.dataSource = self
        view.addSubview(tableView)

        tableView.refreshable(
            style: taijiStyle,
            options: RefreshableOptions(triggerOffset: 92, presentation: .contentInset)
        ) { [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            await MainActor.run {
                self?.reloadItems(prefix: "新星历", count: 24)
            }
        }
    }

    private func makeThemeControl() -> UISegmentedControl {
        let control = UISegmentedControl(items: ["系统", "浅色", "深色"])
        control.selectedSegmentIndex = 0
        control.addTarget(self, action: #selector(themeChanged(_:)), for: .valueChanged)
        return control
    }

    @objc private func themeChanged(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 1:
            taijiStyle.setTheme(.light, animated: true)
        case 2:
            taijiStyle.setTheme(.dark, animated: true)
        default:
            taijiStyle.setTheme(.system, animated: true)
        }
    }

    private func reloadItems(prefix: String, count: Int) {
        items = (1...count).map { "\(prefix) \($0)" }
        tableView.reloadData()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TaijiCell")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "TaijiCell")
        cell.textLabel?.text = items[indexPath.row]
        cell.textLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        cell.detailTextLabel?.text = indexPath.row.isMultiple(of: 3) ? "下拉观察进度、触发和收尾动画" : "主题切换不会重装刷新控件"
        cell.detailTextLabel?.textColor = .secondaryLabel
        cell.backgroundColor = .systemBackground
        return cell
    }
}
```

- [ ] **Step 2: Add the Demo tab**

Modify `Demo/Demo/DemoTabBarController.swift` so `viewControllers` includes Taiji after the list demo:

```swift
viewControllers = [
    makeNavigationController(
        rootViewController: TableViewDemoController(),
        title: "列表",
        imageName: "list.bullet.rectangle"
    ),
    makeNavigationController(
        rootViewController: TaijiRefreshDemoController(),
        title: "太极",
        imageName: "sparkles"
    ),
    makeNavigationController(
        rootViewController: CollectionViewDemoController(),
        title: "网格",
        imageName: "square.grid.2x2.fill"
    ),
    makeNavigationController(
        rootViewController: HorizontalEdgeDemoController(),
        title: "横向",
        imageName: "arrow.left.and.right.square"
    ),
    makeNavigationController(
        rootViewController: VideoFeedDemoController(),
        title: "视频",
        imageName: "play.rectangle.fill"
    ),
]
```

- [ ] **Step 3: Build Demo**

Run:

```bash
xcodebuild build -project Demo/Demo.xcodeproj -scheme Demo -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation
```

Expected: build succeeds and the Demo app contains a `太极` tab.

- [ ] **Step 4: Manual visual QA**

Open the Demo on an iOS Simulator and verify:

- The refresh header height reads as compact 80-100pt.
- The Taiji body is 44-56pt and centered in the header.
- Pulling to about 30%, 70%, and 100% changes scale, glow, arc sweep, and particles.
- The refresh control itself contains no visible text.
- Arcs appear as short tilted glass orbits instead of flat full rings.
- Theme segmented control changes system, light, and dark palettes without reinstalling the refresh component.
- Reduce Motion switches continuous rotation to glow pulse.
- Reduce Transparency makes the body more solid and readable.

- [ ] **Step 5: Commit**

```bash
git add Demo/Demo/TaijiRefreshDemoController.swift Demo/Demo/DemoTabBarController.swift
git commit -m "feat: add taiji refresh demo"
```

---

### Task 7: Document Usage And Run Full Verification

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add README usage section**

Insert this section after the existing custom style example in `README.md`:

````markdown
## 太极玻璃刷新样式

`TaijiRefreshStyle` 提供一个 80-100pt 的紧凑太极刷新 header。控件本身不显示文字，通过进度弧、旋转、发光、粒子和收尾涟漪表达状态。

```swift
let style = TaijiRefreshStyle(extent: 92, theme: .system)

tableView.refreshable(
    style: style,
    options: RefreshableOptions(triggerOffset: 92)
) {
    await viewModel.fetch()
}

style.setTheme(.dark, animated: true)
```

支持的主题：

```swift
style.setTheme(.system, animated: true)
style.setTheme(.light, animated: true)
style.setTheme(.dark, animated: true)
style.setTheme(.custom(TaijiRefreshPalette(
    backgroundTint: .clear,
    primaryGlow: .systemCyan,
    secondaryGlow: .systemPurple,
    glassHighlight: .white,
    shadowCore: .black,
    particle: .white
)), animated: true)
```

该样式会响应 VoiceOver、Reduce Motion 和 Reduce Transparency。无障碍状态文本只暴露给辅助功能，不会在刷新控件中显示。
````

- [ ] **Step 2: Run focused tests**

Run:

```bash
xcodebuild test -scheme Refreshable -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation -only-testing:RefreshableTests/TaijiRefreshThemeTests -only-testing:RefreshableTests/TaijiRefreshRenderStateTests -only-testing:RefreshableTests/TaijiRefreshStyleTests
```

Expected: all Taiji-specific tests pass.

- [ ] **Step 3: Run full package tests**

Run:

```bash
xcodebuild test -scheme Refreshable -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation
```

Expected: all existing and new `RefreshableTests` pass.

- [ ] **Step 4: Build Demo**

Run:

```bash
xcodebuild build -project Demo/Demo.xcodeproj -scheme Demo -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation
```

Expected: Demo builds successfully.

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs: document taiji refresh style"
```

---

## Acceptance Mapping

- `TaijiRefreshStyle` installs through existing `scrollView.refreshable(style:options:)`: Tasks 3 and 6.
- Header defaults to 92pt and supports custom trigger offset: Tasks 3 and 6.
- Refresh control displays no visible status text: Tasks 3 and 6.
- Pull progress affects scale, arc sweep, glow, and particles: Tasks 2 and 4.
- Triggered, refreshing, and ending states have distinct animations: Tasks 2, 4, and 5.
- Theme switching supports system, light, dark, and custom palettes: Tasks 1, 3, 5, and 6.
- Reduce Motion and Reduce Transparency have explicit fallbacks: Tasks 2, 3, and 5.
- Demo shows a realistic list instead of a poster scene: Task 6.

## Execution Notes

- The Demo project uses a file-system-synchronized `Demo` root group. Creating `Demo/Demo/TaijiRefreshDemoController.swift` should be enough for Xcode to compile it; avoid editing `Demo/Demo.xcodeproj/project.pbxproj` unless the build proves the file is excluded.
- Keep `RefreshState` unchanged for this phase.
- Keep `RefreshableStyle` unchanged for this phase.
- Keep `DefaultHeaderStyle` and `DefaultFooterStyle` unchanged for this phase.
- The package target remains iOS 13+. Do not introduce APIs that require iOS 14+ without availability guards.
