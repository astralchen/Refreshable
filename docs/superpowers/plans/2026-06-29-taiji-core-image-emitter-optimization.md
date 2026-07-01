# Taiji Core Image And Emitter Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve the Taiji refresh control's visual depth by adding a Core Image refraction layer and replacing manually positioned particle layers with a CAEmitterLayer particle field.

**Architecture:** Keep the existing `TaijiRefreshStyle` public API and `TaijiRefreshRenderState` state model. Extend `TaijiRefreshView` internally with one Core Image-backed overlay layer inside the Taiji body container and one CAEmitterLayer around the body for particles. Existing pull, refresh, ending, reduce-motion, reduce-transparency, theme, and UI screenshot paths remain intact.

**Tech Stack:** UIKit, QuartzCore/CALayer, Core Image (`CIContext`, `CIFilter`), CAEmitterLayer, Swift Testing, Xcode UI tests.

---

### Task 1: Lock The New Rendering Technologies With Tests

**Files:**
- Modify: `Tests/RefreshableTests/TaijiRefreshStyleTests.swift`
- Verify: `Sources/Refreshable/TaijiRefreshView.swift`

- [x] **Step 1: Update layer composition test before production code**

Replace the layer assertions in `viewCreatesVisualLayers()` with:

```swift
#expect(taijiView.debugLayerNames.contains("mist"))
#expect(taijiView.debugLayerNames.contains("backArc"))
#expect(taijiView.debugLayerNames.contains("frontArc"))
#expect(taijiView.debugLayerNames.contains("body"))
#expect(taijiView.debugLayerNames.contains("coreImageRefraction"))
#expect(taijiView.debugLayerNames.contains("particleEmitter"))
#expect(taijiView.debugLayerNames.contains("ripple"))
#expect(taijiView.debugParticleCount <= 3)
```

Expected behavior before implementation: the test fails because `coreImageRefraction` and `particleEmitter` are not present and `debugParticleCount` is still `18`.

- [x] **Step 2: Update ambient motion expectations before production code**

In `pullingStartsAmbientMotion()`, keep the pull-orbit assertion and replace the manual particle twinkle assertion with:

```swift
#expect(taijiView.debugAnimationKeys.contains("taiji.pullOrbit"))
#expect(!taijiView.debugAnimationKeys.contains("taiji.pullTwinkle"))
```

After returning to idle, keep the `pullOrbit` cleanup assertion and remove the old `pullTwinkle` cleanup assertion. Expected behavior before implementation: this test fails because manual particles still add `taiji.pullTwinkle`.

- [x] **Step 3: Run focused tests and verify red**

Run:

```bash
xcodebuild test -scheme Refreshable -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation -only-testing:RefreshableTests/TaijiRefreshStyleTests
```

Expected: FAIL in `viewCreatesVisualLayers()` and `pullingStartsAmbientMotion()` for the reasons above.

### Task 2: Add A Core Image Refraction Overlay

**Files:**
- Modify: `Sources/Refreshable/TaijiRefreshView.swift`
- Test: `Tests/RefreshableTests/TaijiRefreshStyleTests.swift`

- [x] **Step 1: Import Core Image**

At the top of `TaijiRefreshView.swift`, add:

```swift
import CoreImage
```

- [x] **Step 2: Add a refraction layer**

Add a private layer property near `bodyLayer`:

```swift
private let refractionLayer = TaijiRefractionLayer()
```

Include it in `debugLayerNames`:

```swift
[mistLayer, backArcLayer, frontArcLayer, bodyLayer, refractionLayer, particleEmitterLayer, rippleLayer].compactMap(\.name)
```

In `layoutSubviews()`, set:

```swift
refractionLayer.frame = bodyContainerLayer.bounds
```

In `configureLayers()`, set:

```swift
refractionLayer.name = "coreImageRefraction"
refractionLayer.contentsScale = UIScreen.main.scale
refractionLayer.needsDisplayOnBoundsChange = true
```

Then add it after `bodyLayer` and before `highlightLayer`.

- [x] **Step 3: Feed palette and intensity during apply**

Inside `apply(renderState:palette:animated:reduceTransparency:)`, update:

```swift
refractionLayer.palette = palette
refractionLayer.intensity = renderState.usesTransparentGlass
    ? min(1.0, max(0.24, renderState.glowIntensity))
    : 0.32
refractionLayer.glassOpacity = renderState.glassOpacity
refractionLayer.setNeedsDisplay()
```

- [x] **Step 4: Add `TaijiRefractionLayer`**

Create a private `CALayer` subclass in the same file after `TaijiRefreshView`. It should:

- Hold `palette`, `intensity`, and `glassOpacity`.
- Use a shared `CIContext`.
- Build a cropped `CIRadialGradient`.
- Pass it through `CIBumpDistortion`.
- Render the output to a `CGImage`.
- Clip to the body circle and draw the image.

- [x] **Step 5: Run focused test and verify partial green**

Run the focused style tests. Expected: layer composition moves closer to green; particle-related assertions still fail until Task 3.

### Task 3: Replace Manual Particle Layers With CAEmitterLayer

**Files:**
- Modify: `Sources/Refreshable/TaijiRefreshView.swift`
- Test: `Tests/RefreshableTests/TaijiRefreshStyleTests.swift`

- [x] **Step 1: Replace particle layer storage**

Remove:

```swift
private let particleLayers: [CALayer] = (0..<18).map { _ in CALayer() }
```

Add:

```swift
private let particleEmitterLayer = CAEmitterLayer()
```

Change `debugParticleCount` to return emitter cell count:

```swift
var debugParticleCount: Int {
    particleEmitterLayer.emitterCells?.count ?? 0
}
```

- [x] **Step 2: Add emitter to layer hierarchy**

In `configureLayers()`:

```swift
particleEmitterLayer.name = "particleEmitter"
particleEmitterLayer.emitterShape = .circle
particleEmitterLayer.emitterMode = .outline
particleEmitterLayer.renderMode = .additive
particleEmitterLayer.birthRate = 0
layer.addSublayer(particleEmitterLayer)
```

Remove the loop that creates and adds manual particle layers.

- [x] **Step 3: Layout the emitter**

Replace `updateParticleFrames()` with:

```swift
private func updateParticleEmitterFrame() {
    particleEmitterLayer.emitterPosition = CGPoint(
        x: bodyContainerLayer.frame.midX,
        y: bodyContainerLayer.frame.midY
    )
    particleEmitterLayer.emitterSize = CGSize(
        width: max(bodyContainerLayer.bounds.width * 1.35, 1),
        height: max(bodyContainerLayer.bounds.height * 0.82, 1)
    )
}
```

Call `updateParticleEmitterFrame()` from `layoutSubviews()`.

- [x] **Step 4: Configure emitter cells from render state**

Replace `updateParticles(renderState:palette:)` with `updateParticleEmitter(renderState:palette:)`. It should set `particleEmitterLayer.birthRate` to zero when `particleCount == 0` or `particleIntensity <= 0`, otherwise install two cells:

- `spark`: faster, brighter, shorter lived.
- `dust`: slower, softer, longer lived.

Use a cached white radial particle image as `contents` and tint each cell with `palette.particle` and `palette.primaryGlow`.

- [x] **Step 5: Remove manual particle animation code**

In `debugAnimationKeys`, remove particle layer animation collection.

In `updatePullMotion(isActive:particleCount:)`, keep only the orbit container rocking animation and stop/remove `taiji.pullTwinkle` logic.

- [x] **Step 6: Run focused tests and verify green**

Run:

```bash
xcodebuild test -scheme Refreshable -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation -only-testing:RefreshableTests/TaijiRefreshStyleTests
```

Expected: PASS.

### Task 4: Full Verification And Screenshot Evidence

**Files:**
- Existing package tests
- Existing Demo UI tests

- [x] **Step 1: Run package tests**

Run:

```bash
xcodebuild test -scheme Refreshable -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation
```

Expected: PASS with all package tests.

- [x] **Step 2: Run Demo UI screenshot test**

Run:

```bash
xcodebuild test -project Demo/Demo.xcodeproj -scheme Demo -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation -only-testing:DemoUITests/DemoUITests/testTaijiRefreshScreenshots -resultBundlePath /private/tmp/taiji-ui-screenshots-coreimage-emitter-20260629-1138.xcresult
```

Expected: PASS and keep two screenshots.

- [x] **Step 3: Export screenshot attachments**

Run:

```bash
xcrun xcresulttool export attachments --path /private/tmp/taiji-ui-screenshots-coreimage-emitter-20260629-1138.xcresult --output-path /private/tmp/taiji-ui-screenshots-coreimage-emitter-20260629-1138-attachments
```

Expected: two PNG files, one idle and one refreshing.

- [x] **Step 4: Inspect screenshots**

Open the exported PNGs and verify:

- Idle state remains visually stable.
- Refreshing state shows a brighter, more volumetric Taiji body.
- Particle field reads as natural ambient flow rather than evenly placed dots.
- Layout remains aligned with the earlier mobile screenshot reference.

- [ ] **Step 5: Run whitespace check**

Run:

```bash
git diff --check
```

Expected: no output and exit code 0.
