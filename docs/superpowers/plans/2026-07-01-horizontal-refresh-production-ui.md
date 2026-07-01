# Horizontal Refresh Production UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the approved production-grade horizontal refresh UI and document the refresh control design, animation, and interaction details.

**Architecture:** Keep the public Refreshable API unchanged. Update `DefaultEdgeStyle` with an internal horizontal render model and circular-progress UIKit layers, then upgrade the demo controller to a production content screen that uses the existing refresh/load-more hooks.

**Tech Stack:** Swift 6, UIKit, Swift Testing, Core Animation (`CAShapeLayer`), Swift Package Manager, Xcode project demo.

**Verification Note:** `swift test` is not currently executable for this workspace because the package declares iOS as its platform and the tests import UIKit while SwiftPM resolves the test run for macOS. The existing `Demo` and `Refreshable` Xcode schemes are also not configured with a Test action. The behavior tests are still kept as executable specs for a future iOS test-host scheme; the current runnable verification is the iOS Simulator Demo build.

---

## File Structure

- Create: `docs/superpowers/specs/2026-07-01-horizontal-refresh-production-ui-design.md`
  - Stores the approved UI, interaction, animation, accessibility, and acceptance criteria.
- Create: `docs/superpowers/specs/assets/horizontal-refresh-production-ui.png`
  - Stores the final generated design reference image.
- Create: `docs/superpowers/plans/2026-07-01-horizontal-refresh-production-ui.md`
  - Stores this implementation plan.
- Modify: `Sources/Refreshable/DefaultEdgeStyle.swift`
  - Replace horizontal edge spinner UI with circular progress, directional arrow, and label.
  - Add deterministic render-state helpers for tests.
- Modify: `Tests/RefreshableTests/DefaultStyleTests.swift`
  - Add tests for horizontal edge label, arrow direction, circular progress, and spinner removal.
- Modify: `Demo/Demo/HorizontalEdgeDemoController.swift`
  - Replace placeholder cards with production-style content cards, page header, segmented control, filter action, and status rows.

---

### Task 1: Persist Design Assets And Documents

**Files:**
- Create: `docs/superpowers/specs/assets/horizontal-refresh-production-ui.png`
- Create: `docs/superpowers/specs/2026-07-01-horizontal-refresh-production-ui-design.md`
- Create: `docs/superpowers/plans/2026-07-01-horizontal-refresh-production-ui.md`

- [x] **Step 1: Copy final design image**

Run:

```bash
cp /Users/chenchen/.codex/generated_images/019f1dee-be2c-7451-b26a-91801674eed6/ig_0056e64417c929c2016a452226f5548191889c7330425990eb.png docs/superpowers/specs/assets/horizontal-refresh-production-ui.png
```

Expected: image exists at `docs/superpowers/specs/assets/horizontal-refresh-production-ui.png`.

- [x] **Step 2: Write the design spec**

Create `docs/superpowers/specs/2026-07-01-horizontal-refresh-production-ui-design.md` with:

```markdown
# Horizontal Refresh Production UI Design
```

Expected: the document includes UI anatomy, animation details, page UI, accessibility, and acceptance criteria.

- [x] **Step 3: Write this implementation plan**

Create `docs/superpowers/plans/2026-07-01-horizontal-refresh-production-ui.md` with:

```markdown
# Horizontal Refresh Production UI Implementation Plan
```

Expected: the document includes files, TDD tasks, commands, and verification steps.

---

### Task 2: Test Horizontal Edge Render State

**Files:**
- Modify: `Tests/RefreshableTests/DefaultStyleTests.swift`
- Modify later: `Sources/Refreshable/DefaultEdgeStyle.swift`

- [x] **Step 1: Write failing tests for horizontal edge style**

Append these tests after `DefaultFooterStyleTests`:

```swift
@Suite("DefaultEdgeStyle", .tags(.ui))
@MainActor
struct DefaultEdgeStyleTests {

    @Test("horizontal edge style uses circular progress and no activity indicator")
    func horizontalEdgeStyleUsesCircularProgressWithoutSpinner() throws {
        let style = DefaultEdgeStyle(edge: .leading, role: .refresh)

        #expect(style.view.firstSubview(ofType: UIActivityIndicatorView.self) == nil)
        #expect(style.view.allSubviews(ofType: CAShapeLayerHostView.self).isEmpty == false)
    }

    @Test("horizontal edge pulling text stays generic")
    func horizontalEdgePullingTextStaysGeneric() throws {
        let leading = DefaultEdgeStyle(edge: .leading, role: .refresh)
        let trailing = DefaultEdgeStyle(edge: .trailing, role: .refresh)
        let leadingLabel = try #require(leading.view.firstSubview(ofType: UILabel.self))
        let trailingLabel = try #require(trailing.view.firstSubview(ofType: UILabel.self))

        leading.update(state: .pulling(0.4), progress: 0.4)
        trailing.update(state: .pulling(0.4), progress: 0.4)

        #expect(leadingLabel.text == "拖动刷新")
        #expect(trailingLabel.text == "拖动刷新")
    }

    @Test("horizontal edge label follows refresh state")
    func horizontalEdgeLabelFollowsRefreshState() throws {
        let style = DefaultEdgeStyle(edge: .leading, role: .refresh)
        let label = try #require(style.view.firstSubview(ofType: UILabel.self))

        style.update(state: .triggered, progress: 1)
        #expect(label.text == "释放刷新")

        style.update(state: .refreshing, progress: 1)
        #expect(label.text == "正在刷新...")

        style.update(state: .ending, progress: 0)
        #expect(label.text == "刷新完成")
    }

    @Test("horizontal edge render state resolves physical arrow directions")
    func horizontalEdgeRenderStateResolvesPhysicalArrowDirections() {
        let ltrContainer = UIView()
        ltrContainer.semanticContentAttribute = .forceLeftToRight
        let rtlContainer = UIView()
        rtlContainer.semanticContentAttribute = .forceRightToLeft

        #expect(DefaultEdgeStyle.RenderState(edge: .leading, role: .refresh, state: .pulling(0.5), progress: 0.5, in: ltrContainer).arrowSystemName == "arrow.right")
        #expect(DefaultEdgeStyle.RenderState(edge: .trailing, role: .refresh, state: .pulling(0.5), progress: 0.5, in: ltrContainer).arrowSystemName == "arrow.left")
        #expect(DefaultEdgeStyle.RenderState(edge: .leading, role: .refresh, state: .pulling(0.5), progress: 0.5, in: rtlContainer).arrowSystemName == "arrow.left")
        #expect(DefaultEdgeStyle.RenderState(edge: .trailing, role: .refresh, state: .pulling(0.5), progress: 0.5, in: rtlContainer).arrowSystemName == "arrow.right")
    }

    @Test("horizontal progress clamps to zero and one")
    func horizontalProgressClamps() {
        let container = UIView()

        let negative = DefaultEdgeStyle.RenderState(edge: .leading, role: .refresh, state: .pulling(-0.5), progress: -0.5, in: container)
        let overflow = DefaultEdgeStyle.RenderState(edge: .leading, role: .refresh, state: .pulling(1.4), progress: 1.4, in: container)

        #expect(negative.progress == 0)
        #expect(overflow.progress == 1)
    }
}
```

- [x] **Step 2: Add test helper for layer host lookup**

Append this helper after the existing `UIView` test helper:

```swift
private extension UIView {
    func allSubviews<T: UIView>(ofType type: T.Type) -> [T] {
        var results: [T] = []
        if let view = self as? T {
            results.append(view)
        }
        for subview in subviews {
            results.append(contentsOf: subview.allSubviews(ofType: type))
        }
        return results
    }
}
```

- [x] **Step 3: Record test-runner limitation**

Run:

```bash
swift test --filter DefaultEdgeStyleTests
```

Observed: not runnable in the current workspace because SwiftPM resolves tests for macOS while the package and tests depend on UIKit/iOS.

---

### Task 3: Implement Circular Progress Edge Style

**Files:**
- Modify: `Sources/Refreshable/DefaultEdgeStyle.swift`
- Test: `Tests/RefreshableTests/DefaultStyleTests.swift`

- [x] **Step 1: Replace horizontal setup with circular progress UI**

Implement:

```swift
final class CAShapeLayerHostView: UIView {}
```

inside `DefaultEdgeStyle.swift`, and add:

```swift
struct RenderState: Equatable {
    var progress: CGFloat
    var labelText: String
    var arrowSystemName: String
    var trackColor: UIColor
    var progressColor: UIColor
}
```

Expected: tests can reference both symbols through `@testable import`.

- [x] **Step 2: Implement render-state calculation**

Use `edge.physicalEdge(in:)` to map:

```swift
case .left: "arrow.right"
case .right: "arrow.left"
case .top: "arrow.down"
case .bottom: "arrow.up"
```

Clamp pulling progress to `0...1`; use `1` for triggered/refreshing and `0` for idle.

- [x] **Step 3: Apply render state to layers**

Use `CAShapeLayer` for track/progress, `UIImageView` for arrow, and `UILabel` for copy. Do not add `UIActivityIndicatorView` for horizontal edges.

- [x] **Step 4: Record current test action constraint**

Run:

```bash
xcodebuild test -project Demo/Demo.xcodeproj -scheme Demo -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:RefreshableTests/DefaultEdgeStyleTests
```

Observed: the existing Xcode schemes are not configured for Test action. Keep the tests in `Tests/RefreshableTests/DefaultStyleTests.swift` and use the Demo build for current verification until a test-host scheme is added.

---

### Task 4: Upgrade Horizontal Demo Page

**Files:**
- Modify: `Demo/Demo/HorizontalEdgeDemoController.swift`

- [x] **Step 1: Replace navigation LTR text**

Use an icon-only `UIBarButtonItem`:

```swift
UIBarButtonItem(
    image: UIImage(systemName: "slider.horizontal.3"),
    menu: makeLayoutDirectionMenu()
)
```

Expected: no visible `LTR` or `RTL` text in navigation.

- [x] **Step 2: Add production page header**

Add a vertical root stack containing:

- title `今日更新`
- subtitle `横向拖动刷新内容`
- segmented control `精选` / `最近`
- chip `双向`

- [x] **Step 3: Replace placeholder carousel cards**

Update `HorizontalDemoItem` to hold:

```swift
let eyebrow: String
let title: String
let summary: String
let metadata: String
let status: String
let tintColor: UIColor
```

Update `HorizontalDemoCell` to render production-style cards with cover area, title, summary, metadata, status chip, and action icon.

- [x] **Step 4: Add status section below carousel**

Add a compact `UIStackView` with title `同步状态` and rows:

- `刚刚刷新`
- `缓存 24 项`
- `网络良好`

- [x] **Step 5: Build demo**

Run:

```bash
xcodebuild -project Demo/Demo.xcodeproj -scheme Demo -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Observed: build succeeds.

---

### Task 5: Final Verification

**Files:**
- All modified files.

- [x] **Step 1: Record package test limitation**

Run:

```bash
swift test
```

Observed: not runnable in the current workspace for the UIKit/iOS package and test target. Add an iOS test-host scheme before using this as the final automated verification command.

- [x] **Step 2: Run demo build**

Run:

```bash
xcodebuild -project Demo/Demo.xcodeproj -scheme Demo -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: build succeeds.

- [x] **Step 3: Review changed files**

Run:

```bash
git status --short
git diff --stat
```

Expected: only docs, tests, `DefaultEdgeStyle.swift`, and `HorizontalEdgeDemoController.swift` changed.

---

## Self-Review

- Spec coverage: Design asset, refresh control UI, animation, accessibility, production page, tests, and verification are covered.
- Placeholder scan: No TBD/TODO placeholders remain.
- Type consistency: `RenderState`, `CAShapeLayerHostView`, and test helper names are used consistently.
