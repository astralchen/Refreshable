# Refresh Control UI Audit

Date: 2026-07-01
Device: iPhone 17 Simulator
Scope: Compare the three new refresh styles against `docs/superpowers/plans/assets/custom-refresh-*.png`.

## Evidence

- Design reference: `docs/superpowers/plans/assets/custom-refresh-system-native.png`
- Design reference: `docs/superpowers/plans/assets/custom-refresh-taiji-glass.png`
- Design reference: `docs/superpowers/plans/assets/custom-refresh-kinetic-ribbon.png`
- Actual system, refreshing: `08-user-system-native-refreshing.png`
- Actual system, triggered: `09-user-system-native-triggered.png`
- Actual system, latest triggered: `18-user-system-native-triggered-latest.png`
- Actual taiji, refreshing: `10-user-taiji-glass-refreshing.png`
- Actual kinetic, triggered/ready: `11-user-kinetic-ribbon-refreshing.png`

## Step Results

1. System Native Stack: mostly aligned with the native compact direction, but visibly simpler than the reference.
2. Cosmic Glass Taiji: functional and compact, but does not match the dark glass target in light-mode demo.
3. Kinetic Ribbon: refined to match the reference direction more closely, with a faded multi-color ribbon, layered center glyph, and full particle set.

## Findings

### 1. System Native Stack

Health: Medium-high after refinement.

The latest provided screenshot shows the triggered/release state (`释放刷新`), while the design reference shows the refreshing state (`正在刷新...`). These are different states: `pulling` should show `下拉刷新`, `triggered` should show `释放刷新`, and only `refreshing` should show `正在刷新...` with the last-updated subtitle.

Differences:

- The screenshot is already past `pulling`, so it is expected not to show `下拉刷新`.
- The Demo system trigger threshold is larger than the 64pt visual extent, so the `pulling` state has a more usable distance before changing to `释放刷新`; the `refreshing` hold position still uses the 64pt style extent instead of stopping at the larger trigger distance.
- The spinner no longer has a black arrow overlaid inside it in `pulling` / `triggered` / `refreshing`; the separate gray arrow/dot hint above the spinner remains as the release affordance.
- The last-updated subtitle is shown in `refreshing` / `ending`, not in `triggered`.
- The separate gray arrow/dot hint above the spinner is present and generally aligned with the reference.

Code anchor:

- `Sources/Refreshable/SystemNativeRefreshStyle.swift`: maps visible text by state and shows the subtitle only in `.refreshing` / `.ending`.
- `Demo/Demo/CustomStylesDemoController.swift`: raises the system style trigger threshold for visual QA, while keeping the 64pt control extent.

Recommendation:

- Capture separate `pulling`, `triggered`, and `refreshing` screenshots when comparing state language.
- Continue using `16-fixed-render-system-native-custom-spinner.png` for the refreshing-state reference.

### 2. Cosmic Glass Taiji

Health: Low against the provided design, medium as a standalone light-mode control.

The actual control is compact and shows taiji, arc, particles, and glow feedback. It does not reproduce the reference's dark glass surface.

Differences:

- The design target is dark-mode glass/cosmic. The demo installs `.system`, which resolves to the light palette in the current simulator, so the actual result is a light cyan/purple illustration on a white feed.
- The reference taiji reads as a translucent glass orb with rim highlights and depth. The actual symbol reads flatter and more illustrative.
- The reference includes a deeper localized glow and orbit feel. The actual glow is a wide pale haze and the orbit/particles are simpler.

Code anchor:

- `Demo/Demo/CustomStylesDemoController.swift`: Taiji is installed with `.system` unless the whole trait collection is dark.
- `Sources/Refreshable/TaijiRefreshStyle.swift`: the visible taiji symbol diameter is fixed at 52pt, with light and dark palettes available.

Recommendation:

- For the demo/design target, force `TaijiRefreshStyle(theme: .dark)` and give the demo surface a matching dark background for the taiji segment, or update the design target to include a light variant.
- Increase glass depth with stronger rim highlights, inner gloss, and tighter localized glow.

### 3. Kinetic Ribbon

Health: Medium-high after refinement.

The refined control now uses the reference ingredients more directly: a faded multi-color ribbon, center refresh glyph above the line, colored vertical ticks, small particles, and a soft compact pill.

Differences:

- The control-level render is more compact than the full design reference because the reference includes surrounding navigation and feed chrome.
- The final visual still uses SF Symbols for the center refresh glyph, so its exact arrow shape depends on the platform symbol rendering.

Code anchor:

- `Sources/Refreshable/KineticRefreshStyle.swift`: renders the gradient ribbon, center glyph, status pill, and 11-particle layout.
- `Tests/RefreshableTests/CustomRefreshStyleTests.swift`: verifies the faded ribbon endpoints and full particle set.

Recommendation:

- Capture/verify the `.refreshing` state specifically for visual QA.
- If pixel-level fidelity is required, replace the SF Symbol glyph with a custom vector path matching the design artwork exactly.

## Accessibility Risks

- Screenshots cannot verify VoiceOver order or announcements. Code exposes accessibility values for the styles, but this still needs runtime VoiceOver verification.
- System style's gray status text may be low contrast against the white background depending on the configured `DefaultRefreshStyleConfiguration`.
- Kinetic status text is small in a compact pill; Dynamic Type behavior should be checked because the screenshot does not show large-content-size layout.

## Limits

- The surrounding feed in the design references is illustrative; this audit compares only the refresh control UI, state language, scale, and material direction.
- The final kinetic screenshot is the ready/triggered state, not the exact refreshing state shown in the reference.

## Fix Verification

- Fixed render, system native: `13-fixed-render-system-native.png`
- Fixed render, system native custom spinner: `16-fixed-render-system-native-custom-spinner.png`
- Fixed render, system native triggered design structure: `19-fixed-render-system-native-triggered-design-structure.png`
- Fixed render, system native pull progress 0.2: `20-fixed-render-system-native-progress-020.png`
- Fixed render, system native pull progress 0.9: `21-fixed-render-system-native-progress-090.png`
- Fixed render, system native triggered continued pull progress 1.7: `22-fixed-render-system-native-triggered-progress-170.png`
- Fixed render, taiji glass: `14-fixed-render-taiji-glass.png`
- Fixed render, kinetic ribbon: `15-fixed-render-kinetic-ribbon.png`
- Fixed render, kinetic ribbon refined: `17-fixed-render-kinetic-ribbon-refined.png`
- `12-fixed-kinetic-ribbon.png` was an attempted live capture and should not be used as the final visual reference.

## 2026-07-01 Progress Response Update

`SystemNativeSpinnerView` now responds to pull progress with visible geometry changes. At low progress (`20-fixed-render-system-native-progress-020.png`) the spinner is nearly absent. At high progress (`21-fixed-render-system-native-progress-090.png`) the spinner expands into a fuller native-style blue radial indicator with per-segment alpha falloff. After the threshold is crossed, continued pull progress is still forwarded to the style, so the triggered state can expand further (`22-fixed-render-system-native-triggered-progress-170.png`) instead of freezing at the first triggered frame.
