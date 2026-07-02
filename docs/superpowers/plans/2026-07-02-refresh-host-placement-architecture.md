# Refresh Host Placement Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the hidden `layoutMargins` coupling in refresh component layout with an explicit placement model, so vertical and horizontal refresh controls can reserve space, add axis spacing, and add cross-axis insets without styles depending on container internals.

**Architecture:** `EdgeRefreshComponent` owns an internal host view that represents scroll-view geometry and reserved space. `RefreshableStyle.view` becomes the visual content view inside that host. Public spacing is expressed by `RefreshablePlacement`, not by mutating `style.view.layoutMargins`. `triggerOffset` remains the gesture threshold only; the refreshing reservation is `placement.outerSpacing + style.extent + placement.contentSpacing`.

**Tech Stack:** Swift 6, UIKit, Swift Testing, XCTest UI tests, Xcode iOS Simulator.

---

## Current Problem

`EdgeRefreshComponent.updateRefreshViewLayoutMargins` currently uses `style.view.layoutMargins` to make horizontal refresh styles appear in a narrow visual lane while the view frame spans the horizontal viewport. That creates a hidden contract:

- Component layout writes into `style.view.layoutMargins`.
- `DefaultEdgeStyle` reads `view.layoutMarginsGuide`.
- Custom styles cannot know whether `view.bounds` is the visual size or the host geometry.
- Future needs such as left/right spacing for horizontal controls or top/bottom spacing for vertical controls have no explicit API.

The new contract must be:

- `style.view.bounds` is the visual control area.
- `EdgeRefreshComponent` may install `style.view` inside a private host view.
- The host view handles scroll geometry, safe-area compensation, content inset reservation, and overlay positioning.
- Public spacing lives in `RefreshableOptions.placement`.
- `layoutMargins` remains a normal UIKit property owned by the style author.

## Target API

Modify [RefreshableOptions.swift](/Users/sondra/Documents/GitHub/Refreshable/Sources/Refreshable/RefreshableOptions.swift):

```swift
public struct RefreshablePlacement: Equatable {
    public var contentSpacing: CGFloat
    public var outerSpacing: CGFloat
    public var crossAxisInset: CGFloat

    public init(contentSpacing: CGFloat = 0, outerSpacing: CGFloat = 0, crossAxisInset: CGFloat = 0) {
        self.contentSpacing = contentSpacing
        self.outerSpacing = outerSpacing
        self.crossAxisInset = crossAxisInset
    }
}

public struct RefreshableOptions {
    public var triggerOffset: CGFloat?
    public var animationDuration: TimeInterval
    public var automaticallyEndRefreshing: Bool
    public var allowsLoadMoreWhenContentFits: Bool
    public var placement: RefreshablePlacement
    public var presentation: RefreshablePresentation
    public var onStateChange: (@MainActor (RefreshState) -> Void)?
}
```

Semantics:

- `contentSpacing`: distance along the refresh axis between the visual control and the content edge.
- `outerSpacing`: distance along the refresh axis between the visual control and the visible outer edge.
- `crossAxisInset`: symmetric inset perpendicular to the refresh axis.
- Top edge: `outerSpacing` is the gap above the visual control; `contentSpacing` is the gap below the visual control, before content begins.
- Bottom edge: `outerSpacing` is the gap below the visual control; `contentSpacing` is the gap above the visual control, after content ends.
- Left edge: `outerSpacing` is the gap to the left of the visual control; `contentSpacing` is the gap to the right of the visual control, before content begins.
- Right edge: `outerSpacing` is the gap to the right of the visual control; `contentSpacing` is the gap to the left of the visual control, after content ends.
- `reservedExtent = max(placement.outerSpacing, 0) + style.extent + max(placement.contentSpacing, 0)`.
- `crossAxisInset` is clamped to `0...(crossAxisLength / 2)`.

## File Changes

- [RefreshableOptions.swift](/Users/sondra/Documents/GitHub/Refreshable/Sources/Refreshable/RefreshableOptions.swift): add `RefreshablePlacement` and `RefreshableOptions.placement`.
- [RefreshComponent.swift](/Users/sondra/Documents/GitHub/Refreshable/Sources/Refreshable/RefreshComponent.swift): add small install/removal hooks so subclasses can own a host view.
- [EdgeRefreshComponent.swift](/Users/sondra/Documents/GitHub/Refreshable/Sources/Refreshable/EdgeRefreshComponent.swift): introduce `refreshHostView`, compute host frames and visual frames, remove layout-margin mutation.
- [DefaultEdgeStyle.swift](/Users/sondra/Documents/GitHub/Refreshable/Sources/Refreshable/DefaultEdgeStyle.swift): remove `layoutMarginsGuide` dependency.
- [RefreshableStyle.swift](/Users/sondra/Documents/GitHub/Refreshable/Sources/Refreshable/RefreshableStyle.swift): document that `view` is the visual style view.
- [RefreshableOptionsTests.swift](/Users/sondra/Documents/GitHub/Refreshable/Tests/RefreshableTests/RefreshableOptionsTests.swift): cover `placement`.
- [EdgeRefreshComponentTests.swift](/Users/sondra/Documents/GitHub/Refreshable/Tests/RefreshableTests/EdgeRefreshComponentTests.swift): cover host view, preserved margins, spacing, and cross-axis inset.
- [DefaultStyleTests.swift](/Users/sondra/Documents/GitHub/Refreshable/Tests/RefreshableTests/DefaultStyleTests.swift): update default horizontal style tests to visual-bounds semantics.
- [README.md](/Users/sondra/Documents/GitHub/Refreshable/README.md): document placement once implementation is verified.

---

## Task 1: Add Failing Contract Tests

- [ ] Edit [RefreshableOptionsTests.swift](/Users/sondra/Documents/GitHub/Refreshable/Tests/RefreshableTests/RefreshableOptionsTests.swift) and add default/custom placement coverage:

```swift
@Test
func placementDefaultsToNoExtraSpacing() {
    let options = RefreshableOptions()

    #expect(options.placement == RefreshablePlacement())
    #expect(options.placement.contentSpacing == 0)
    #expect(options.placement.crossAxisInset == 0)
}

@Test
func placementStoresContentSpacingAndCrossAxisInset() {
    let options = RefreshableOptions(
        placement: RefreshablePlacement(contentSpacing: 12, crossAxisInset: 20)
    )

    #expect(options.placement.contentSpacing == 12)
    #expect(options.placement.crossAxisInset == 20)
}
```

- [ ] Edit [EdgeRefreshComponentTests.swift](/Users/sondra/Documents/GitHub/Refreshable/Tests/RefreshableTests/EdgeRefreshComponentTests.swift) and add host/visual contract tests:

```swift
@Test
func leadingRefreshUsesHostViewAndPreservesStyleMargins() throws {
    let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 844, height: 390))
    scrollView.contentSize = CGSize(width: 1_600, height: 390)
    let style = MockStyle(extent: 54)
    let preservedMargins = UIEdgeInsets(top: 1, left: 2, bottom: 3, right: 4)
    style.view.layoutMargins = preservedMargins

    scrollView.refreshable(edge: .leading, style: style) { }

    let hostView = try #require(style.view.superview)
    #expect(hostView !== scrollView)
    #expect(hostView.superview === scrollView)
    #expect(hostView.frame == CGRect(x: -54, y: 0, width: 844, height: 390))
    #expect(style.view.frame == CGRect(x: 0, y: 0, width: 54, height: 390))
    #expect(style.view.layoutMargins == preservedMargins)
}

@Test
func leadingPlacementContentSpacingReservesGapBeforeContent() throws {
    let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 844, height: 390))
    scrollView.contentSize = CGSize(width: 1_600, height: 390)
    let style = MockStyle(extent: 54)
    let options = RefreshableOptions(
        animationDuration: 0,
        automaticallyEndRefreshing: false,
        placement: RefreshablePlacement(contentSpacing: 12)
    )

    scrollView.refreshable(edge: .leading, style: style, options: options) { }
    let hostView = try #require(style.view.superview)

    #expect(hostView.frame == CGRect(x: -66, y: 0, width: 844, height: 390))
    #expect(style.view.frame == CGRect(x: 0, y: 0, width: 54, height: 390))

    scrollView.beginRefreshing(edge: .leading)

    #expect(scrollView.contentInset.left == 66)
    #expect(scrollView.contentOffset.x == -66)
}

@Test
func topPlacementCrossAxisInsetShrinksVisualWidthOnly() throws {
    let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
    scrollView.contentSize = CGSize(width: 320, height: 1_200)
    let style = MockStyle(extent: 44)
    let options = RefreshableOptions(
        animationDuration: 0,
        automaticallyEndRefreshing: false,
        placement: RefreshablePlacement(contentSpacing: 12, crossAxisInset: 20)
    )

    scrollView.refreshable(edge: .top, style: style, options: options) { }
    let hostView = try #require(style.view.superview)

    #expect(hostView.frame == CGRect(x: 0, y: -56, width: 320, height: 56))
    #expect(style.view.frame == CGRect(x: 20, y: 0, width: 280, height: 44))

    scrollView.beginRefreshing(edge: .top)

    #expect(scrollView.contentInset.top == 56)
    #expect(scrollView.contentOffset.y == -56)
}
```

- [ ] Update old horizontal safe-area tests in [EdgeRefreshComponentTests.swift](/Users/sondra/Documents/GitHub/Refreshable/Tests/RefreshableTests/EdgeRefreshComponentTests.swift):
  - Assert `hostView.frame.width` is the horizontal viewport width.
  - Assert `style.view.frame.width == style.extent`.
  - Assert `style.view.layoutMargins == .zero` unless the test set custom margins.
  - Remove assertions that require `style.view.frame.width == horizontalViewportWidth`.

- [ ] Update removal tests in [EdgeRefreshComponentTests.swift](/Users/sondra/Documents/GitHub/Refreshable/Tests/RefreshableTests/EdgeRefreshComponentTests.swift):

```swift
@Test
func removingLeadingRefreshDetachesStyleAndHostViews() throws {
    let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
    scrollView.contentSize = CGSize(width: 800, height: 480)
    let style = MockStyle(extent: 54)

    scrollView.refreshable(edge: .leading, style: style) { }
    let hostView = try #require(style.view.superview)

    scrollView.removeRefreshControl(edge: .leading)

    #expect(style.view.superview == nil)
    #expect(hostView.superview == nil)
}
```

- [ ] Update [DefaultStyleTests.swift](/Users/sondra/Documents/GitHub/Refreshable/Tests/RefreshableTests/DefaultStyleTests.swift) so horizontal default style tests use a narrow visual `view.frame`, not `layoutMargins`:

```swift
@Test @MainActor
func horizontalEdgeVisualContentUsesVisualBoundsWithoutMarginContract() throws {
    let style = DefaultLeadingRefreshStyle()
    style.view.frame = CGRect(x: 0, y: 0, width: 130, height: 390)
    style.update(state: .pulling, progress: 0.65)
    style.view.layoutIfNeeded()

    let host = try #require(style.view.subviews.first)
    #expect(abs(host.center.x - 65) < 0.5)
}
```

- [ ] Run the full library tests and confirm the tests fail for the expected reasons: missing `RefreshablePlacement`, direct `style.view` installation, and layout-margin assertions.

```bash
xcodebuild test -scheme Refreshable -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected result: `TEST FAILED` with compile errors for `RefreshablePlacement` and failing assertions that identify the old direct-view layout behavior.

---

## Task 2: Add `RefreshablePlacement`

- [ ] Edit [RefreshableOptions.swift](/Users/sondra/Documents/GitHub/Refreshable/Sources/Refreshable/RefreshableOptions.swift) and insert `RefreshablePlacement` before `RefreshableOptions`:

```swift
/// Controls where the refresh style's visual view is placed within the
/// component-managed layout area.
public struct RefreshablePlacement: Equatable {
    /// Spacing along the refresh axis between the visual control and content.
    public var contentSpacing: CGFloat

    /// Symmetric inset on the axis perpendicular to the refresh direction.
    public var crossAxisInset: CGFloat

    public init(contentSpacing: CGFloat = 0, crossAxisInset: CGFloat = 0) {
        self.contentSpacing = contentSpacing
        self.crossAxisInset = crossAxisInset
    }
}
```

- [ ] Add `placement` to `RefreshableOptions`:

```swift
/// Placement applied by the component host around the style's visual view.
public var placement: RefreshablePlacement
```

- [ ] Update the memberwise initializer to include:

```swift
placement: RefreshablePlacement = RefreshablePlacement(),
```

and assign:

```swift
self.placement = placement
```

- [ ] Run:

```bash
xcodebuild test -scheme Refreshable -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected result: option tests pass, host/visual contract tests still fail because `EdgeRefreshComponent` has not been changed.

---

## Task 3: Add Install/Removal Hooks To `RefreshComponent`

- [ ] Edit [RefreshComponent.swift](/Users/sondra/Documents/GitHub/Refreshable/Sources/Refreshable/RefreshComponent.swift) and add overridable hooks:

```swift
var installedView: UIView {
    style.view
}

var visibilityView: UIView {
    style.view
}

func removeInstalledView() {
    installedView.removeFromSuperview()
}
```

- [ ] Update `prepareForRemoval()` to call the hook:

```swift
func prepareForRemoval() {
    stopMonitoring()
    endRefreshing(animated: false)
    removeInstalledView()
    options.onStateChange?(state)
}
```

- [ ] Update the private visibility method to use the hook:

```swift
private func updateViewVisibility(for state: RefreshState) {
    switch state {
    case .idle:
        visibilityView.alpha = 0
    case .pulling, .triggered, .refreshing, .finishing:
        visibilityView.alpha = 1
    }
}
```

- [ ] Run:

```bash
xcodebuild test -scheme Refreshable -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected result: existing non-edge tests stay green; host contract tests still fail until `EdgeRefreshComponent` owns the host view.

---

## Task 4: Move Edge Layout Into A Component Host View

- [ ] Edit [EdgeRefreshComponent.swift](/Users/sondra/Documents/GitHub/Refreshable/Sources/Refreshable/EdgeRefreshComponent.swift) and add a private host:

```swift
private let refreshHostView = UIView()

override var installedView: UIView {
    refreshHostView
}
```

- [ ] Override removal so the style view is detached from the host as well:

```swift
override func removeInstalledView() {
    style.view.removeFromSuperview()
    refreshHostView.removeFromSuperview()
}
```

- [ ] Replace direct `style.view` installation with host installation:

```swift
override func installView(in scrollView: UIScrollView) {
    refreshHostView.clipsToBounds = false
    refreshHostView.isUserInteractionEnabled = false

    style.view.isUserInteractionEnabled = false
    style.view.alpha = 0

    if style.view.superview !== refreshHostView {
        refreshHostView.addSubview(style.view)
    }

    updateRefreshViewFrame(in: scrollView)

    if refreshHostView.superview !== scrollView {
        scrollView.addSubview(refreshHostView)
    }

    style.update(state: state, progress: progress)
}
```

- [ ] Add placement helpers:

```swift
private var sanitizedContentSpacing: CGFloat {
    max(options.placement.contentSpacing, 0)
}

private var sanitizedOuterSpacing: CGFloat {
    max(options.placement.outerSpacing, 0)
}

private var sanitizedCrossAxisInset: CGFloat {
    max(options.placement.crossAxisInset, 0)
}

private var reservedExtent: CGFloat {
    sanitizedOuterSpacing + displayExtent + sanitizedContentSpacing
}
```

- [ ] Replace `refreshingInsetExtent(in:)` so refreshing reservation uses `reservedExtent` for every edge:

```swift
private func refreshingInsetExtent(in scrollView: UIScrollView) -> CGFloat {
    reservedExtent
}
```

- [ ] Replace `updateRefreshViewFrame(in:)` with host and visual frames:

```swift
private func updateRefreshViewFrame(in scrollView: UIScrollView) {
    let physicalEdge = resolvedPhysicalEdge(for: scrollView)
    refreshHostView.frame = hostFrame(in: scrollView, physicalEdge: physicalEdge)
    refreshHostView.autoresizingMask = autoresizingMask(in: scrollView)
    style.view.frame = visualFrame(in: refreshHostView.bounds, physicalEdge: physicalEdge)
}
```

- [ ] Rename the old `contentInsetFrame(in:physicalEdge:)` implementation to `hostFrame(in:physicalEdge:)` and change each edge to reserve `reservedExtent`:

```swift
private func hostFrame(in scrollView: UIScrollView, physicalEdge: Edge) -> CGRect {
    let bounds = scrollView.bounds
    let contentSize = scrollView.contentSize
    let originalInset = originalContentInset ?? scrollView.contentInset
    let adjustedInset = scrollView.adjustedContentInset
    let extent = reservedExtent

    switch physicalEdge {
    case .top:
        return CGRect(x: 0, y: -extent, width: bounds.width, height: extent)
    case .bottom:
        let y = max(contentSize.height, bounds.height - originalInset.top - originalInset.bottom)
        return CGRect(x: 0, y: y, width: bounds.width, height: extent)
    case .left:
        return CGRect(
            x: -originalInset.left - extent,
            y: contentInsetRefreshViewY(in: scrollView),
            width: horizontalViewportWidth(in: scrollView),
            height: contentInsetRefreshViewHeight(in: scrollView)
        )
    case .right:
        let x = max(
            contentSize.width - bounds.width + originalInset.right + adjustedInset.left + adjustedInset.right + extent,
            adjustedInset.left + extent
        )
        return CGRect(
            x: x,
            y: contentInsetRefreshViewY(in: scrollView),
            width: horizontalViewportWidth(in: scrollView),
            height: contentInsetRefreshViewHeight(in: scrollView)
        )
    }
}
```

- [ ] Add `visualFrame(in:physicalEdge:)`:

```swift
private func visualFrame(in bounds: CGRect, physicalEdge: Edge) -> CGRect {
    switch physicalEdge {
    case .top:
        let inset = clampedCrossAxisInset(for: bounds.width)
        return CGRect(
            x: inset,
            y: 0,
            width: max(bounds.width - inset * 2, 0),
            height: displayExtent
        )
    case .bottom:
        let inset = clampedCrossAxisInset(for: bounds.width)
        return CGRect(
            x: inset,
            y: sanitizedContentSpacing,
            width: max(bounds.width - inset * 2, 0),
            height: displayExtent
        )
    case .left:
        let inset = clampedCrossAxisInset(for: bounds.height)
        return CGRect(
            x: 0,
            y: inset,
            width: displayExtent,
            height: max(bounds.height - inset * 2, 0)
        )
    case .right:
        let inset = clampedCrossAxisInset(for: bounds.height)
        return CGRect(
            x: max(bounds.width - displayExtent, 0),
            y: inset,
            width: displayExtent,
            height: max(bounds.height - inset * 2, 0)
        )
    }
}

private func clampedCrossAxisInset(for length: CGFloat) -> CGFloat {
    min(sanitizedCrossAxisInset, max(length, 0) / 2)
}
```

- [ ] Delete `updateRefreshViewLayoutMargins(_:in:)` and every call to it from [EdgeRefreshComponent.swift](/Users/sondra/Documents/GitHub/Refreshable/Sources/Refreshable/EdgeRefreshComponent.swift).

- [ ] Update `adjustContentOffsetForStartEdgeIfNeeded` so it uses `reservedExtent` instead of `displayExtent` for left/right and instead of `triggerThreshold` for top/bottom.

- [ ] Update overlay frame calculation so the host frame reserves `reservedExtent`, while `style.view.frame` is still assigned through `visualFrame(in:physicalEdge:)`.

- [ ] Run:

```bash
xcodebuild test -scheme Refreshable -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected result: host/placement tests pass or fail only on exact frame values. If exact frame tests fail, inspect the printed actual `CGRect` values and update implementation, not the contract.

---

## Task 5: Remove Default Style Dependency On Layout Margins

- [ ] Edit [DefaultEdgeStyle.swift](/Users/sondra/Documents/GitHub/Refreshable/Sources/Refreshable/DefaultEdgeStyle.swift).

- [ ] Replace constraints that use `view.layoutMarginsGuide`:

```swift
progressHost.centerXAnchor.constraint(equalTo: view.layoutMarginsGuide.centerXAnchor)
label.centerXAnchor.constraint(equalTo: view.layoutMarginsGuide.centerXAnchor)
label.widthAnchor.constraint(lessThanOrEqualTo: view.layoutMarginsGuide.widthAnchor, constant: -4)
```

with visual-bounds constraints:

```swift
progressHost.centerXAnchor.constraint(equalTo: view.centerXAnchor)
label.centerXAnchor.constraint(equalTo: view.centerXAnchor)
label.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -4)
```

- [ ] Run:

```bash
xcodebuild test -scheme Refreshable -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected result: default style layout tests pass using the style view's visual bounds.

---

## Task 6: Update Documentation And Naming Semantics

- [ ] Edit [RefreshableStyle.swift](/Users/sondra/Documents/GitHub/Refreshable/Sources/Refreshable/RefreshableStyle.swift) and document the new visual-view contract:

```swift
/// View that renders the refresh control's visual content.
///
/// The component may install this view inside an internal host view. The
/// style should lay out its UI against this view's bounds and should not
/// depend on the view's superview or layout margins for component geometry.
var view: UIView { get }
```

- [ ] Edit [README.md](/Users/sondra/Documents/GitHub/Refreshable/README.md) and add a placement example near the options section:

```swift
let options = RefreshableOptions(
    placement: RefreshablePlacement(contentSpacing: 12, crossAxisInset: 20)
)
```

- [ ] Add the semantic explanation:

```md
`contentSpacing` adds space between the visual refresh control and content
along the refresh direction. `crossAxisInset` shrinks the visual control on
the perpendicular axis. Styles receive a visual-sized `view.bounds`; the
component owns scroll-view host geometry internally.
```

- [ ] Search for remaining hidden contract usage:

```bash
rg -n "updateRefreshViewLayoutMargins|layoutMarginsGuide|layoutMargins" Sources Tests
```

Expected result: no `updateRefreshViewLayoutMargins`; no `layoutMarginsGuide` in `Sources/Refreshable/DefaultEdgeStyle.swift`; any remaining `layoutMargins` references are tests for preserved UIKit margins or unrelated UIKit defaults.

---

## Task 7: Demo UI Regression Coverage

- [ ] Run the existing demo UI tests the user called out:

```bash
xcodebuild test -project Demo/Demo.xcodeproj -scheme Demo -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DemoUITests/DemoUITests
```

Expected result: `TEST SUCCEEDED`.

- [ ] If the demo UI test target does not contain assertions for all three custom styles, add a focused UI test in [Demo/DemoUITests/DemoUITests.swift](/Users/sondra/Documents/GitHub/Refreshable/Demo/DemoUITests/DemoUITests.swift):
  - Open the refresh style tab.
  - Select `系统`, pull below threshold, assert `下拉刷新`.
  - Pull beyond threshold, assert `释放刷新`.
  - Release, assert `正在刷新`.
  - Select `太极`, pull and assert the taiji view remains centered and not clipped.
  - Select `动感`, pull and assert the kinetic control is visible only while the pull state is active or refreshing.

- [ ] Re-run:

```bash
xcodebuild test -project Demo/Demo.xcodeproj -scheme Demo -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DemoUITests/DemoUITests
```

Expected result: `TEST SUCCEEDED`.

---

## Task 8: Final Verification

- [ ] Run library tests:

```bash
xcodebuild test -scheme Refreshable -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected result: `TEST SUCCEEDED`.

- [ ] Run demo UI tests:

```bash
xcodebuild test -project Demo/Demo.xcodeproj -scheme Demo -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DemoUITests/DemoUITests
```

Expected result: `TEST SUCCEEDED`.

- [ ] Run Swift package tests if the package target is configured for this workspace:

```bash
swift test
```

Expected result: `Build complete!` followed by all tests passing, or a clear platform limitation if UIKit tests require an iOS simulator.

- [ ] Run whitespace and patch validation:

```bash
git diff --check
```

Expected result: no output.

- [ ] Inspect the final source diff:

```bash
git diff -- Sources/Refreshable Tests/RefreshableTests Demo/DemoUITests README.md
```

Expected result:

- `RefreshablePlacement` is the only new public layout API.
- `EdgeRefreshComponent` owns a private host view.
- `DefaultEdgeStyle` no longer uses `layoutMarginsGuide`.
- Tests cover host geometry, visual bounds, margin preservation, `outerSpacing`, `contentSpacing`, and `crossAxisInset`.
- No style relies on component-written layout margins.

---

## Implementation Notes

- Keep `layoutMargins` unmodified by `EdgeRefreshComponent`. A style may still use its own margins internally, but component geometry must not write into them.
- Keep `triggerOffset` independent from `reservedExtent`. Pull state transitions use `triggerOffset ?? style.extent`; refreshing content inset uses `placement.outerSpacing + style.extent + placement.contentSpacing`.
- Do not expose the host view. It is an implementation detail of `EdgeRefreshComponent`.
- Do not rename existing `DefaultTopRefreshStyle`, `DefaultBottomLoadMoreStyle`, or footer/header aliases in this plan. The placement architecture is independent from naming cleanup.
- Preserve public initializer source compatibility by placing `placement` after `allowsLoadMoreWhenContentFits` with a default value.

## Commit Plan

- [ ] Commit the test contract first if the team wants a visible red step:

```bash
git add Tests/RefreshableTests
git commit -m "Add refresh placement layout contract tests"
```

- [ ] Commit the implementation and docs after verification:

```bash
git add Sources/Refreshable Tests/RefreshableTests Demo/DemoUITests README.md
git commit -m "Introduce refresh host placement architecture"
```

- [ ] If working on a feature branch, merge and push only after all verification commands pass:

```bash
git switch main
git merge <feature-branch>
git push origin main
```
