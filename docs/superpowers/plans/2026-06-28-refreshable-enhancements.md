# Refreshable Enhancements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add safer runtime control, configurable behavior, state visibility, task cancellation, and UI polish to the Refreshable package without breaking the current one-line API.

**Architecture:** Keep the existing `UIScrollView` associated-object architecture. Add a small `RefreshableOptions` value type, thread it through `RefreshComponent`, and expose read-only state plus control methods from `UIScrollView+Refreshable`. Preserve the current default `refreshable {}` and `loadMoreable {}` APIs as compatibility wrappers.

**Tech Stack:** Swift 6.0, UIKit, Swift Testing, iOS 13+, no third-party dependencies.

---

## Scope And Phasing

This plan covers the first implementation phase in executable detail:

- `RefreshableOptions`
- configurable trigger distance and animation duration
- external state query and state-change callback
- task cancellation and manual auto-end control
- robust inset capture at refresh start
- enable, disable, and remove APIs
- tests and README updates

The follow-up roadmap after this phase:

- Phase 2: default style customization, Dynamic Type, accessibility announcements, and richer Demo screens.
- Phase 3: throwing action overloads, failure state, footer retry UI, and retry Demo.

Phase 3 changes the public state model and should be designed separately after Phase 1 lands.

## File Structure

- Create `Sources/Refreshable/RefreshableOptions.swift`: public behavior options used by header and footer components.
- Modify `Sources/Refreshable/RefreshComponent.swift`: store options, emit state callbacks, capture insets at start, manage current `Task`, support cancellation and enabled state.
- Modify `Sources/Refreshable/HeaderRefreshComponent.swift`: use option-driven threshold and animation duration, respect enabled state, recapture inset for manual starts.
- Modify `Sources/Refreshable/FooterRefreshComponent.swift`: use option-driven threshold and animation duration, respect enabled state, support content-fit load-more option.
- Modify `Sources/Refreshable/UIScrollView+Refreshable.swift`: add option overloads, public state query, enable/disable APIs, and remove APIs.
- Create `Tests/RefreshableTests/RefreshableOptionsTests.swift`: unit tests for option defaults and custom values.
- Modify component and extension tests under `Tests/RefreshableTests/`: cover the new behavior.
- Modify `README.md`: document new overloads and runtime-control APIs.

---

### Task 1: Add RefreshableOptions

**Files:**
- Create: `Sources/Refreshable/RefreshableOptions.swift`
- Create: `Tests/RefreshableTests/RefreshableOptionsTests.swift`

- [ ] **Step 1: Write failing tests**

Add `Tests/RefreshableTests/RefreshableOptionsTests.swift`:

```swift
import Testing
@testable import Refreshable
import UIKit

@Suite("RefreshableOptions")
struct RefreshableOptionsTests {

    @Test("默认值保持现有行为")
    func defaults() {
        let options = RefreshableOptions()

        #expect(options.triggerOffset == nil)
        #expect(options.animationDuration == 0.25)
        #expect(options.automaticallyEndRefreshing == true)
        #expect(options.allowsLoadMoreWhenContentFits == false)
    }

    @Test("可配置触发距离、动画时长、自动结束和内容不足一屏加载")
    func customValues() {
        let options = RefreshableOptions(
            triggerOffset: 80,
            animationDuration: 0.4,
            automaticallyEndRefreshing: false,
            allowsLoadMoreWhenContentFits: true
        )

        #expect(options.triggerOffset == 80)
        #expect(options.animationDuration == 0.4)
        #expect(options.automaticallyEndRefreshing == false)
        #expect(options.allowsLoadMoreWhenContentFits == true)
    }
}
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
xcodebuild test -scheme Refreshable -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation -only-testing:RefreshableTests/RefreshableOptionsTests
```

Expected: build fails with `cannot find 'RefreshableOptions' in scope`.

- [ ] **Step 3: Implement RefreshableOptions**

Create `Sources/Refreshable/RefreshableOptions.swift`:

```swift
import UIKit

/// 行为配置，传入 header 或 footer 组件。
@MainActor
public struct RefreshableOptions {
    /// 触发距离。nil 表示使用 style.height，保持现有行为。
    public var triggerOffset: CGFloat?

    /// inset 展开和收起动画时长。
    public var animationDuration: TimeInterval

    /// action 完成后是否自动调用 endRefreshing/endLoadingMore。
    public var automaticallyEndRefreshing: Bool

    /// 内容不足一屏时，是否仍允许上拉加载。
    public var allowsLoadMoreWhenContentFits: Bool

    /// 状态变化回调，不包含安装时对 style 的 idle 初始化调用。
    public var onStateChange: (@MainActor (RefreshState) -> Void)?

    public init(
        triggerOffset: CGFloat? = nil,
        animationDuration: TimeInterval = 0.25,
        automaticallyEndRefreshing: Bool = true,
        allowsLoadMoreWhenContentFits: Bool = false,
        onStateChange: (@MainActor (RefreshState) -> Void)? = nil
    ) {
        self.triggerOffset = triggerOffset
        self.animationDuration = animationDuration
        self.automaticallyEndRefreshing = automaticallyEndRefreshing
        self.allowsLoadMoreWhenContentFits = allowsLoadMoreWhenContentFits
        self.onStateChange = onStateChange
    }
}
```

- [ ] **Step 4: Run tests and verify pass**

Run the same command from Step 2.

Expected: `RefreshableOptionsTests` passes.

- [ ] **Step 5: Commit**

```bash
git add Sources/Refreshable/RefreshableOptions.swift Tests/RefreshableTests/RefreshableOptionsTests.swift
git commit -m "feat: add refreshable options"
```

---

### Task 2: Thread Options Through Components

**Files:**
- Modify: `Sources/Refreshable/RefreshComponent.swift`
- Modify: `Sources/Refreshable/HeaderRefreshComponent.swift`
- Modify: `Sources/Refreshable/FooterRefreshComponent.swift`
- Modify: `Sources/Refreshable/UIScrollView+Refreshable.swift`
- Modify: `Tests/RefreshableTests/HeaderRefreshComponentTests.swift`
- Modify: `Tests/RefreshableTests/FooterRefreshComponentTests.swift`

- [ ] **Step 1: Write failing tests for trigger offset and animation duration**

Append to `HeaderRefreshComponentTests`:

```swift
@Test("自定义 triggerOffset 用于 header inset")
func customHeaderTriggerOffset() {
    let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
    scrollView.contentInset.top = 12
    let style = MockStyle()
    let component = HeaderRefreshComponent(
        style: style,
        options: RefreshableOptions(triggerOffset: 80, automaticallyEndRefreshing: false)
    ) {}
    component.scrollView = scrollView

    component.beginRefreshing()

    #expect(scrollView.contentInset.top == 92)
}
```

Append to `FooterRefreshComponentTests`:

```swift
@Test("自定义 triggerOffset 用于 footer inset")
func customFooterTriggerOffset() {
    let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
    scrollView.contentSize = CGSize(width: 375, height: 2000)
    scrollView.contentInset.bottom = 16
    let style = MockStyle()
    let component = FooterRefreshComponent(
        style: style,
        options: RefreshableOptions(triggerOffset: 90, automaticallyEndRefreshing: false)
    ) {}
    component.scrollView = scrollView

    component.beginLoadingMore()

    #expect(scrollView.contentInset.bottom == 106)
}
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
xcodebuild test -scheme Refreshable -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation -only-testing:RefreshableTests/HeaderRefreshComponentTests/customHeaderTriggerOffset -only-testing:RefreshableTests/FooterRefreshComponentTests/customFooterTriggerOffset
```

Expected: build fails because component initializers do not accept `options`.

- [ ] **Step 3: Update component initialization and threshold usage**

In `RefreshComponent.swift`, change stored properties and initializer:

```swift
let style: any RefreshableStyle
let options: RefreshableOptions
var action: (@MainActor () async -> Void)?

init(
    style: some RefreshableStyle,
    options: RefreshableOptions = RefreshableOptions(),
    action: @MainActor @escaping () async -> Void
) {
    self.style = style
    self.options = options
    self.action = action
    super.init()
}
```

In `HeaderRefreshComponent.swift`:

```swift
private var threshold: CGFloat {
    options.triggerOffset ?? style.height
}
```

Use `options.animationDuration` in both animation calls:

```swift
UIView.animate(withDuration: options.animationDuration) {
    scrollView.contentInset.top = self.originalInset.top + self.threshold
}
```

In `FooterRefreshComponent.swift`:

```swift
private var threshold: CGFloat {
    options.triggerOffset ?? style.height
}
```

Use `options.animationDuration` in footer animations:

```swift
UIView.animate(withDuration: options.animationDuration) {
    scrollView.contentInset.bottom = self.originalInset.bottom + self.threshold
}
```

In `UIScrollView+Refreshable.swift`, add option overloads and keep existing calls:

```swift
@MainActor
public func refreshable(options: RefreshableOptions, action: @MainActor @escaping () async -> Void) {
    refreshable(style: DefaultHeaderStyle(), options: options, action: action)
}

@MainActor
public func refreshable(
    style: some RefreshableStyle,
    options: RefreshableOptions,
    action: @MainActor @escaping () async -> Void
) {
    let component = HeaderRefreshComponent(style: style, options: options, action: action)
    self.headerComponent = component
    component.scrollView = self
}
```

Update the existing header overloads to forward:

```swift
@MainActor
public func refreshable(action: @MainActor @escaping () async -> Void) {
    refreshable(style: DefaultHeaderStyle(), options: RefreshableOptions(), action: action)
}

@MainActor
public func refreshable(style: some RefreshableStyle, action: @MainActor @escaping () async -> Void) {
    refreshable(style: style, options: RefreshableOptions(), action: action)
}
```

Add matching footer overloads:

```swift
@MainActor
public func loadMoreable(options: RefreshableOptions, action: @MainActor @escaping () async -> Void) {
    loadMoreable(style: DefaultFooterStyle(), options: options, action: action)
}

@MainActor
public func loadMoreable(
    style: some RefreshableStyle,
    options: RefreshableOptions,
    action: @MainActor @escaping () async -> Void
) {
    let component = FooterRefreshComponent(style: style, options: options, action: action)
    self.footerComponent = component
    component.scrollView = self
}

@MainActor
public func loadMoreable(action: @MainActor @escaping () async -> Void) {
    loadMoreable(style: DefaultFooterStyle(), options: RefreshableOptions(), action: action)
}

@MainActor
public func loadMoreable(style: some RefreshableStyle, action: @MainActor @escaping () async -> Void) {
    loadMoreable(style: style, options: RefreshableOptions(), action: action)
}
```

- [ ] **Step 4: Run targeted tests**

Run the command from Step 2.

Expected: both tests pass.

- [ ] **Step 5: Run full tests**

Run:

```bash
xcodebuild test -scheme Refreshable -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation
```

Expected: all existing and new tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/Refreshable Tests/RefreshableTests
git commit -m "feat: configure refresh behavior with options"
```

---

### Task 3: Expose State Query And State Callback

**Files:**
- Modify: `Sources/Refreshable/RefreshComponent.swift`
- Modify: `Sources/Refreshable/UIScrollView+Refreshable.swift`
- Modify: `Tests/RefreshableTests/RefreshComponentTests.swift`
- Modify: `Tests/RefreshableTests/UIScrollViewExtensionTests.swift`

- [ ] **Step 1: Write failing tests**

Append to `RefreshComponentTests`:

```swift
@Test("状态变化时调用 onStateChange")
func stateChangeCallback() {
    var states: [RefreshState] = []
    let style = MockStyle()
    let component = TestRefreshComponent(
        style: style,
        options: RefreshableOptions(onStateChange: { state in
            states.append(state)
        })
    ) {}
    component.scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))

    component.setState(.pulling(0.5))
    component.setState(.triggered)

    #expect(states == [.pulling(0.5), .triggered])
}
```

Append to `UIScrollViewExtensionTests`:

```swift
@Test("公开查询 header 和 footer 状态")
func publicStateQuery() {
    let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
    scrollView.contentSize = CGSize(width: 375, height: 2000)

    scrollView.refreshable(options: RefreshableOptions(automaticallyEndRefreshing: false)) {}
    scrollView.loadMoreable(options: RefreshableOptions(automaticallyEndRefreshing: false)) {}

    #expect(scrollView.refreshState == .idle)
    #expect(scrollView.loadMoreState == .idle)

    scrollView.beginRefreshing()
    scrollView.beginLoadingMore()

    #expect(scrollView.refreshState == .refreshing)
    #expect(scrollView.loadMoreState == .refreshing)
    #expect(scrollView.isRefreshActive == true)
    #expect(scrollView.isLoadMoreActive == true)
}
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
xcodebuild test -scheme Refreshable -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation -only-testing:RefreshableTests/RefreshComponentTests/stateChangeCallback -only-testing:RefreshableTests/UIScrollViewExtensionTests/publicStateQuery
```

Expected: build fails because public query properties do not exist and callbacks are not emitted.

- [ ] **Step 3: Emit callbacks from RefreshComponent**

In `RefreshComponent.swift`, update `state` didSet:

```swift
private(set) var state: RefreshState = .idle {
    didSet {
        guard state != oldValue else { return }
        let progress: CGFloat = if case .pulling(let p) = state { p } else { 0 }
        style.update(state: state, progress: progress)
        updateViewVisibility(state: state, progress: progress)
        options.onStateChange?(state)
        stateDidChange(from: oldValue, to: state)
    }
}
```

- [ ] **Step 4: Add public state query properties**

In `UIScrollView+Refreshable.swift`:

```swift
/// 当前下拉刷新状态。未安装 header 时返回 idle。
@MainActor
public var refreshState: RefreshState {
    headerComponent?.state ?? .idle
}

/// 当前上拉加载状态。未安装 footer 时返回 idle。
@MainActor
public var loadMoreState: RefreshState {
    footerComponent?.state ?? .idle
}

/// header 是否正在刷新。
@MainActor
public var isRefreshActive: Bool {
    refreshState.isRefreshing
}

/// footer 是否正在加载。
@MainActor
public var isLoadMoreActive: Bool {
    loadMoreState.isRefreshing
}
```

- [ ] **Step 5: Run targeted tests**

Run the command from Step 2.

Expected: both tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/Refreshable Tests/RefreshableTests
git commit -m "feat: expose refresh states"
```

---

### Task 4: Add Task Cancellation And Manual Auto-End Control

**Files:**
- Modify: `Sources/Refreshable/RefreshComponent.swift`
- Modify: `Sources/Refreshable/HeaderRefreshComponent.swift`
- Modify: `Sources/Refreshable/FooterRefreshComponent.swift`
- Modify: `Tests/RefreshableTests/HeaderRefreshComponentTests.swift`
- Modify: `Tests/RefreshableTests/FooterRefreshComponentTests.swift`

- [ ] **Step 1: Write failing tests**

Append to `HeaderRefreshComponentTests`:

```swift
@Test("automaticallyEndRefreshing 为 false 时 action 完成后保持 refreshing")
func headerManualEndOption() async {
    let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
    let style = MockStyle()
    let component = HeaderRefreshComponent(
        style: style,
        options: RefreshableOptions(automaticallyEndRefreshing: false)
    ) {}
    component.scrollView = scrollView

    component.trigger()
    try? await Task.sleep(nanoseconds: 50_000_000)

    #expect(component.state == .refreshing)
}

@Test("取消 header 当前任务会结束刷新")
func cancelHeaderTask() async {
    let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
    let style = MockStyle()
    var observedCancellation = false
    let component = HeaderRefreshComponent(style: style) {
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000)
        } catch {
            observedCancellation = Task.isCancelled
        }
    }
    component.scrollView = scrollView

    component.trigger()
    try? await Task.sleep(nanoseconds: 50_000_000)
    component.cancelCurrentTask(resetState: true)
    try? await Task.sleep(nanoseconds: 50_000_000)

    #expect(observedCancellation == true)
    #expect([RefreshState.ending, .idle].contains(component.state))
}
```

Append to `FooterRefreshComponentTests`:

```swift
@Test("automaticallyEndRefreshing 为 false 时 footer action 完成后保持 refreshing")
func footerManualEndOption() async {
    let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
    scrollView.contentSize = CGSize(width: 375, height: 2000)
    let style = MockStyle()
    let component = FooterRefreshComponent(
        style: style,
        options: RefreshableOptions(automaticallyEndRefreshing: false)
    ) {}
    component.scrollView = scrollView

    component.trigger()
    try? await Task.sleep(nanoseconds: 50_000_000)

    #expect(component.state == .refreshing)
}
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
xcodebuild test -scheme Refreshable -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation -only-testing:RefreshableTests/HeaderRefreshComponentTests/headerManualEndOption -only-testing:RefreshableTests/HeaderRefreshComponentTests/cancelHeaderTask -only-testing:RefreshableTests/FooterRefreshComponentTests/footerManualEndOption
```

Expected: build fails because `cancelCurrentTask(resetState:)` does not exist, and manual auto-end is ignored.

- [ ] **Step 3: Implement task management in RefreshComponent**

In `RefreshComponent.swift`, add:

```swift
private var currentTask: Task<Void, Never>?

deinit {
    currentTask?.cancel()
}
```

Replace `trigger()` with:

```swift
func trigger() {
    guard isEnabled else { return }
    guard !state.isRefreshing else { return }
    captureOriginalInset()
    setState(.refreshing)
    startActionTask()
}
```

Add helpers:

```swift
var isEnabled = true

func captureOriginalInset() {
    if let scrollView {
        originalInset = scrollView.contentInset
    }
}

func startActionTask() {
    currentTask?.cancel()
    currentTask = Task { @MainActor [weak self] in
        guard let self else { return }
        await self.action?()

        guard !Task.isCancelled else { return }
        self.currentTask = nil

        if self.options.automaticallyEndRefreshing {
            self.endRefreshing()
        }
    }
}

func cancelCurrentTask(resetState: Bool) {
    currentTask?.cancel()
    currentTask = nil

    guard resetState else { return }
    if state.isRefreshing || state == .ending {
        endRefreshing()
    } else if state != .idle && state != .noMoreData {
        setState(.idle)
    }
}
```

- [ ] **Step 4: Use startActionTask in manual begins**

In `HeaderRefreshComponent.beginRefreshing()`:

```swift
func beginRefreshing() {
    guard isEnabled else { return }
    guard !state.isRefreshing else { return }
    guard let scrollView else { return }

    captureOriginalInset()
    setState(.refreshing)

    UIView.animate(withDuration: options.animationDuration) {
        scrollView.contentInset.top = self.originalInset.top + self.threshold
        scrollView.contentOffset.y = -self.originalInset.top - self.threshold
    }

    startActionTask()
}
```

In `FooterRefreshComponent.beginLoadingMore()`:

```swift
func beginLoadingMore() {
    guard isEnabled else { return }
    guard !state.isRefreshing, state != .noMoreData else { return }
    guard let scrollView else { return }

    captureOriginalInset()
    setState(.refreshing)

    UIView.animate(withDuration: options.animationDuration) {
        scrollView.contentInset.bottom = self.originalInset.bottom + self.threshold
    }

    startActionTask()
}
```

- [ ] **Step 5: Run targeted tests**

Run the command from Step 2.

Expected: all targeted tests pass.

- [ ] **Step 6: Run full tests**

Run:

```bash
xcodebuild test -scheme Refreshable -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation
```

Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/Refreshable Tests/RefreshableTests
git commit -m "feat: manage refresh tasks safely"
```

---

### Task 5: Recapture Insets At Refresh Start

**Files:**
- Modify: `Sources/Refreshable/RefreshComponent.swift`
- Modify: `Sources/Refreshable/HeaderRefreshComponent.swift`
- Modify: `Sources/Refreshable/FooterRefreshComponent.swift`
- Modify: `Tests/RefreshableTests/HeaderRefreshComponentTests.swift`
- Modify: `Tests/RefreshableTests/FooterRefreshComponentTests.swift`

- [ ] **Step 1: Write failing tests**

Append to `HeaderRefreshComponentTests`:

```swift
@Test("开始刷新时重新捕获当前 top inset")
func recapturesHeaderInsetAtStart() {
    let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
    let style = MockStyle()
    let component = HeaderRefreshComponent(
        style: style,
        options: RefreshableOptions(automaticallyEndRefreshing: false)
    ) {}
    component.scrollView = scrollView

    scrollView.contentInset.top = 40
    component.beginRefreshing()

    #expect(component.originalInset.top == 40)
    #expect(scrollView.contentInset.top == 94)
}
```

Append to `FooterRefreshComponentTests`:

```swift
@Test("开始加载时重新捕获当前 bottom inset")
func recapturesFooterInsetAtStart() {
    let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
    scrollView.contentSize = CGSize(width: 375, height: 2000)
    let style = MockStyle()
    let component = FooterRefreshComponent(
        style: style,
        options: RefreshableOptions(automaticallyEndRefreshing: false)
    ) {}
    component.scrollView = scrollView

    scrollView.contentInset.bottom = 30
    component.beginLoadingMore()

    #expect(component.originalInset.bottom == 30)
    #expect(scrollView.contentInset.bottom == 84)
}
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
xcodebuild test -scheme Refreshable -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation -only-testing:RefreshableTests/HeaderRefreshComponentTests/recapturesHeaderInsetAtStart -only-testing:RefreshableTests/FooterRefreshComponentTests/recapturesFooterInsetAtStart
```

Expected before Task 4: tests fail because `originalInset` remains the install-time value. Expected after Task 4: tests pass because `captureOriginalInset()` is already used.

- [ ] **Step 3: Verify implementation**

Confirm the following calls exist:

```swift
captureOriginalInset()
setState(.refreshing)
```

These calls must appear in:

- `RefreshComponent.trigger()`
- `HeaderRefreshComponent.beginRefreshing()`
- `FooterRefreshComponent.beginLoadingMore()`

- [ ] **Step 4: Run targeted tests**

Run the command from Step 2.

Expected: both tests pass.

- [ ] **Step 5: Commit if Task 4 did not already include this behavior**

```bash
git add Sources/Refreshable Tests/RefreshableTests
git commit -m "fix: recapture content inset before refresh"
```

---

### Task 6: Add Enable, Disable, And Remove APIs

**Files:**
- Modify: `Sources/Refreshable/RefreshComponent.swift`
- Modify: `Sources/Refreshable/HeaderRefreshComponent.swift`
- Modify: `Sources/Refreshable/FooterRefreshComponent.swift`
- Modify: `Sources/Refreshable/UIScrollView+Refreshable.swift`
- Modify: `Tests/RefreshableTests/UIScrollViewExtensionTests.swift`

- [ ] **Step 1: Write failing tests**

Append to `UIScrollViewExtensionTests`:

```swift
@Test("禁用 header 后 beginRefreshing 不触发")
func disableHeaderPreventsBeginRefreshing() {
    let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
    scrollView.refreshable(options: RefreshableOptions(automaticallyEndRefreshing: false)) {}

    scrollView.setRefreshEnabled(false)
    scrollView.beginRefreshing()

    #expect(scrollView.refreshState == .idle)
}

@Test("禁用 footer 后 beginLoadingMore 不触发")
func disableFooterPreventsBeginLoadingMore() {
    let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
    scrollView.contentSize = CGSize(width: 375, height: 2000)
    scrollView.loadMoreable(options: RefreshableOptions(automaticallyEndRefreshing: false)) {}

    scrollView.setLoadMoreEnabled(false)
    scrollView.beginLoadingMore()

    #expect(scrollView.loadMoreState == .idle)
}

@Test("removeRefreshable 移除 header 组件和视图")
func removeRefreshable() {
    let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
    let style = MockStyle()
    scrollView.refreshable(style: style, options: RefreshableOptions()) {}

    scrollView.removeRefreshable()

    #expect(scrollView.headerComponent == nil)
    #expect(style.view.superview == nil)
}

@Test("removeLoadMoreable 移除 footer 组件和视图")
func removeLoadMoreable() {
    let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
    let style = MockStyle()
    scrollView.loadMoreable(style: style, options: RefreshableOptions()) {}

    scrollView.removeLoadMoreable()

    #expect(scrollView.footerComponent == nil)
    #expect(style.view.superview == nil)
}
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
xcodebuild test -scheme Refreshable -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation -only-testing:RefreshableTests/UIScrollViewExtensionTests/disableHeaderPreventsBeginRefreshing -only-testing:RefreshableTests/UIScrollViewExtensionTests/disableFooterPreventsBeginLoadingMore -only-testing:RefreshableTests/UIScrollViewExtensionTests/removeRefreshable -only-testing:RefreshableTests/UIScrollViewExtensionTests/removeLoadMoreable
```

Expected: build fails because public APIs do not exist.

- [ ] **Step 3: Add component enable behavior**

In `RefreshComponent.swift`, keep the `isEnabled` property from Task 4 and add:

```swift
func setEnabled(_ enabled: Bool) {
    guard isEnabled != enabled else { return }
    isEnabled = enabled

    if !enabled {
        cancelCurrentTask(resetState: true)
    }
}
```

In `HeaderRefreshComponent.scrollViewDidScroll(contentOffset:)`, add at the top:

```swift
guard isEnabled else { return }
```

In `FooterRefreshComponent.scrollViewDidScroll(contentOffset:)`, add at the top:

```swift
guard isEnabled else { return }
```

- [ ] **Step 4: Add UIScrollView public APIs**

In `UIScrollView+Refreshable.swift`:

```swift
/// 启用或禁用下拉刷新。禁用时会取消正在执行的刷新任务。
@MainActor
public func setRefreshEnabled(_ enabled: Bool) {
    headerComponent?.setEnabled(enabled)
}

/// 启用或禁用上拉加载。禁用时会取消正在执行的加载任务。
@MainActor
public func setLoadMoreEnabled(_ enabled: Bool) {
    footerComponent?.setEnabled(enabled)
}

/// 移除下拉刷新组件。
@MainActor
public func removeRefreshable() {
    headerComponent = nil
}

/// 移除上拉加载组件。
@MainActor
public func removeLoadMoreable() {
    footerComponent = nil
}
```

Update associated-object setters:

```swift
@MainActor
var headerComponent: HeaderRefreshComponent? {
    get {
        objc_getAssociatedObject(self, AssociatedKeys.header) as? HeaderRefreshComponent
    }
    set {
        if let old = headerComponent, old !== newValue {
            old.cancelCurrentTask(resetState: false)
            old.style.view.removeFromSuperview()
            old.scrollView = nil
        }
        objc_setAssociatedObject(self, AssociatedKeys.header, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

@MainActor
var footerComponent: FooterRefreshComponent? {
    get {
        objc_getAssociatedObject(self, AssociatedKeys.footer) as? FooterRefreshComponent
    }
    set {
        if let old = footerComponent, old !== newValue {
            old.cancelCurrentTask(resetState: false)
            old.style.view.removeFromSuperview()
            old.scrollView = nil
        }
        objc_setAssociatedObject(self, AssociatedKeys.footer, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
```

- [ ] **Step 5: Run targeted tests**

Run the command from Step 2.

Expected: all four tests pass.

- [ ] **Step 6: Run full tests**

Run:

```bash
xcodebuild test -scheme Refreshable -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation
```

Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/Refreshable Tests/RefreshableTests
git commit -m "feat: add refreshable runtime controls"
```

---

### Task 7: Document New APIs

**Files:**
- Modify: `README.md`
- Modify: `REQUIREMENTS.md`

- [ ] **Step 1: Update README API section**

Add these examples under `## API` in `README.md`:

```swift
// 行为配置
scrollView.refreshable(
    options: RefreshableOptions(triggerOffset: 80, animationDuration: 0.3)
) {
    await viewModel.fetchLatest()
}

scrollView.loadMoreable(
    options: RefreshableOptions(
        automaticallyEndRefreshing: false,
        allowsLoadMoreWhenContentFits: true
    )
) {
    await viewModel.fetchNextPage()
    scrollView.endLoadingMore()
}

// 状态查询
let refreshState = scrollView.refreshState
let loadMoreState = scrollView.loadMoreState
let isRefreshing = scrollView.isRefreshActive
let isLoadingMore = scrollView.isLoadMoreActive

// 运行时控制
scrollView.setRefreshEnabled(false)
scrollView.setLoadMoreEnabled(false)
scrollView.removeRefreshable()
scrollView.removeLoadMoreable()
```

Add callback example:

```swift
scrollView.refreshable(
    options: RefreshableOptions(onStateChange: { state in
        print("refresh state:", state)
    })
) {
    await viewModel.fetchLatest()
}
```

- [ ] **Step 2: Update REQUIREMENTS**

Add a new section after `4. 公开 API`:

````markdown
### 4.1 行为配置与状态查询

```swift
scrollView.refreshable(options: RefreshableOptions(...)) { ... }
scrollView.loadMoreable(options: RefreshableOptions(...)) { ... }
scrollView.refreshState
scrollView.loadMoreState
scrollView.isRefreshActive
scrollView.isLoadMoreActive
scrollView.setRefreshEnabled(_:)
scrollView.setLoadMoreEnabled(_:)
scrollView.removeRefreshable()
scrollView.removeLoadMoreable()
```

`RefreshableOptions` 支持：

- `triggerOffset`: 自定义触发距离，默认使用 `style.height`
- `animationDuration`: inset 展开/收起动画时长，默认 `0.25`
- `automaticallyEndRefreshing`: action 完成后是否自动结束，默认 `true`
- `allowsLoadMoreWhenContentFits`: 内容不足一屏时是否允许上拉加载，默认 `false`
- `onStateChange`: 状态变化回调
````

- [ ] **Step 3: Run tests after documentation changes**

Run:

```bash
xcodebuild test -scheme Refreshable -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation
```

Expected: all tests pass.

- [ ] **Step 4: Commit**

```bash
git add README.md REQUIREMENTS.md
git commit -m "docs: document refreshable enhancements"
```

---

## Phase 2 Roadmap

### Default Style Customization

Add initializer parameters to `DefaultHeaderStyle` and `DefaultFooterStyle`:

```swift
public init(
    texts: DefaultHeaderStyle.Texts = .zhCN,
    tintColor: UIColor = .secondaryLabel,
    font: UIFont = .preferredFont(forTextStyle: .subheadline),
    indicatorStyle: UIActivityIndicatorView.Style = .medium
)
```

Add nested text structs:

```swift
public struct Texts {
    public var idle: String
    public var triggered: String
    public var refreshing: String
    public var ending: String
}
```

Footer texts also include:

```swift
public var noMoreData: String
```

### Accessibility

For default styles:

- set `label.adjustsFontForContentSizeCategory = true`
- set `view.isAccessibilityElement = true`
- update `view.accessibilityLabel` when state changes
- post `UIAccessibility.post(notification: .announcement, argument: label.text)` only when entering `.refreshing`, `.ending`, and `.noMoreData`

### Demo Expansion

Add Demo screens for:

- custom option values
- custom default text/colors
- manual end mode
- disable/enable controls
- empty list with `allowsLoadMoreWhenContentFits`

## Phase 3 Roadmap

### Throwing Actions And Retry

Design separately because it changes the state model. A likely shape:

```swift
public enum RefreshState: Sendable, Equatable {
    case idle
    case pulling(CGFloat)
    case triggered
    case refreshing
    case ending
    case failed(String)
    case noMoreData
}
```

Add throwing overloads:

```swift
public func refreshable(action: @MainActor @escaping () async throws -> Void)
public func loadMoreable(action: @MainActor @escaping () async throws -> Void)
```

Footer retry should be opt-in through options:

```swift
public var keepsFooterVisibleOnFailure: Bool
```

This phase needs separate compatibility review because current `RefreshState` is public and `Equatable`.

## Self Review

- Spec coverage: Phase 1 covers configuration, state exposure, cancellation safety, robust inset handling, runtime enable/disable/remove APIs, tests, and docs.
- Placeholder scan: no implementation steps depend on undefined file paths or unspecified commands.
- Type consistency: all new APIs use `RefreshableOptions`, `RefreshState`, existing `HeaderRefreshComponent`, existing `FooterRefreshComponent`, and the current `UIScrollView` extension pattern.
