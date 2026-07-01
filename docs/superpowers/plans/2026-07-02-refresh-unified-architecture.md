# Refresh Unified Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the legacy header/footer component split so every refresh and load-more edge uses `EdgeRefreshComponent` as the only internal component.

**Architecture:** Keep public `UIScrollView` APIs unchanged. Migrate tests to construct `EdgeRefreshComponent(edge:role:style:options:action:)` directly for top refresh and bottom load-more behavior, then remove the wrapper source files. Default style selection stays role/edge based and remains separate from component architecture.

**Tech Stack:** Swift 6 package, UIKit, Swift Testing, Xcode iOS Simulator build.

---

## File Structure

- Modify: `Tests/RefreshableTests/RefreshComponentTests.swift`
  - Replace `HeaderRefreshComponent` construction with `EdgeRefreshComponent(edge: .top, role: .refresh, ...)`.
- Move/Modify: `Tests/RefreshableTests/HeaderRefreshComponentTests.swift` -> `Tests/RefreshableTests/EdgeTopRefreshComponentTests.swift`
  - Keep top-refresh behavior coverage, but name the suite around `.top + .refresh`.
- Move/Modify: `Tests/RefreshableTests/FooterRefreshComponentTests.swift` -> `Tests/RefreshableTests/EdgeBottomLoadMoreComponentTests.swift`
  - Keep bottom-load-more behavior coverage, but name the suite around `.bottom + .loadMore`.
- Delete: `Sources/Refreshable/HeaderRefreshComponent.swift`
- Delete: `Sources/Refreshable/FooterRefreshComponent.swift`
- Modify: `REQUIREMENTS.md`
  - Update current architecture notes so docs no longer describe header/footer as separate component branches.

## Task 1: Establish Structural Red Test

**Files:**
- Test command only.

- [ ] **Step 1: Run the structural test before implementation**

Run:

```bash
rg -n "HeaderRefreshComponent|FooterRefreshComponent" Sources/Refreshable Tests/RefreshableTests
```

Expected: command exits `0` and prints matches in source and tests. This is the red state because the unified architecture should not require these internal wrapper names.

## Task 2: Convert Base Component Tests

**Files:**
- Modify: `Tests/RefreshableTests/RefreshComponentTests.swift`

- [ ] **Step 1: Replace header wrapper construction**

Use this helper inside `RefreshComponentTests`:

```swift
private func makeTopRefreshComponent(
    style: MockStyle = MockStyle(),
    options: RefreshableOptions = RefreshableOptions(),
    action: @escaping @Sendable () async -> Void = {}
) -> EdgeRefreshComponent {
    EdgeRefreshComponent(edge: .top, role: .refresh, style: style, options: options, action: action)
}
```

Replace every `HeaderRefreshComponent(...)` in this file with `makeTopRefreshComponent(...)`.

- [ ] **Step 2: Typecheck the migrated tests**

Run:

```bash
xcrun --sdk iphonesimulator swiftc -typecheck -target x86_64-apple-ios13.0-simulator -sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator26.2.sdk -swift-version 6 -plugin-path /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/plugins/testing -I /private/tmp/refreshable-typecheck -F /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/Library/Frameworks Tests/RefreshableTests/MockStyle.swift Tests/RefreshableTests/RefreshComponentTests.swift
```

Expected: exits `0`.

## Task 3: Migrate Top Refresh Tests

**Files:**
- Move/Modify: `Tests/RefreshableTests/HeaderRefreshComponentTests.swift` -> `Tests/RefreshableTests/EdgeTopRefreshComponentTests.swift`

- [ ] **Step 1: Rename suite and direct construction**

Rename the suite to:

```swift
@Suite("EdgeRefreshComponent .top refresh")
@MainActor
struct EdgeTopRefreshComponentTests {
```

Use this SUT signature:

```swift
private func makeSUT() -> (UIScrollView, EdgeRefreshComponent, MockStyle) {
    let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
    let style = MockStyle()
    let component = EdgeRefreshComponent(
        edge: .top,
        role: .refresh,
        style: style,
        options: RefreshableOptions(automaticallyEndRefreshing: false)
    ) {}
    component.scrollView = scrollView
    return (scrollView, component, style)
}
```

Replace each direct `HeaderRefreshComponent(...)` with an equivalent `EdgeRefreshComponent(edge: .top, role: .refresh, ...)`.

- [ ] **Step 2: Typecheck top refresh tests**

Run:

```bash
xcrun --sdk iphonesimulator swiftc -typecheck -target x86_64-apple-ios13.0-simulator -sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator26.2.sdk -swift-version 6 -plugin-path /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/plugins/testing -I /private/tmp/refreshable-typecheck -F /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/Library/Frameworks Tests/RefreshableTests/MockStyle.swift Tests/RefreshableTests/EdgeTopRefreshComponentTests.swift
```

Expected: exits `0`.

## Task 4: Migrate Bottom Load-More Tests

**Files:**
- Move/Modify: `Tests/RefreshableTests/FooterRefreshComponentTests.swift` -> `Tests/RefreshableTests/EdgeBottomLoadMoreComponentTests.swift`

- [ ] **Step 1: Rename suite and direct construction**

Rename the suite to:

```swift
@Suite("EdgeRefreshComponent .bottom loadMore")
@MainActor
struct EdgeBottomLoadMoreComponentTests {
```

Use this SUT signature:

```swift
private func makeSUT() -> (UIScrollView, EdgeRefreshComponent, MockStyle) {
    let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
    scrollView.contentSize = CGSize(width: 375, height: 2000)
    let style = MockStyle()
    let component = EdgeRefreshComponent(
        edge: .bottom,
        role: .loadMore,
        style: style,
        options: RefreshableOptions(automaticallyEndRefreshing: false)
    ) {}
    component.scrollView = scrollView
    return (scrollView, component, style)
}
```

Replace each direct `FooterRefreshComponent(...)` with an equivalent `EdgeRefreshComponent(edge: .bottom, role: .loadMore, ...)`.

- [ ] **Step 2: Typecheck bottom load-more tests**

Run:

```bash
xcrun --sdk iphonesimulator swiftc -typecheck -target x86_64-apple-ios13.0-simulator -sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator26.2.sdk -swift-version 6 -plugin-path /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/plugins/testing -I /private/tmp/refreshable-typecheck -F /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/Library/Frameworks Tests/RefreshableTests/MockStyle.swift Tests/RefreshableTests/EdgeBottomLoadMoreComponentTests.swift
```

Expected: exits `0`.

## Task 5: Remove Legacy Wrapper Source Files

**Files:**
- Delete: `Sources/Refreshable/HeaderRefreshComponent.swift`
- Delete: `Sources/Refreshable/FooterRefreshComponent.swift`

- [ ] **Step 1: Delete wrappers**

Remove both files after all direct test references have been migrated.

- [ ] **Step 2: Run structural test again**

Run:

```bash
rg -n "HeaderRefreshComponent|FooterRefreshComponent" Sources/Refreshable Tests/RefreshableTests
```

Expected: command exits `1` with no output.

## Task 6: Update Architecture Documentation

**Files:**
- Modify: `REQUIREMENTS.md`

- [ ] **Step 1: Replace wrapper references**

Update the architecture section so it describes:

```text
EdgeRefreshComponent      edge/role geometry, inset, trigger, and state logic
```

Remove current-tree references to `HeaderRefreshComponent.swift`, `FooterRefreshComponent.swift`, `HeaderRefreshComponentTests.swift`, and `FooterRefreshComponentTests.swift`.

- [ ] **Step 2: Check current docs no longer describe wrappers as active architecture**

Run:

```bash
rg -n "HeaderRefreshComponent|FooterRefreshComponent" REQUIREMENTS.md docs/superpowers/specs/2026-07-02-refresh-unified-architecture-design.md
```

Expected: matches are allowed only in the new spec where it describes the removed legacy names.

## Task 7: Final Verification

**Files:**
- All modified files.

- [ ] **Step 1: Rebuild typecheck module**

Run:

```bash
mkdir -p /private/tmp/refreshable-typecheck
xcrun --sdk iphonesimulator swiftc -emit-module -parse-as-library -module-name Refreshable -enable-testing -target x86_64-apple-ios13.0-simulator -sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator26.2.sdk -swift-version 6 -emit-module-path /private/tmp/refreshable-typecheck/Refreshable.swiftmodule Sources/Refreshable/*.swift
```

Expected: exits `0`.

- [ ] **Step 2: Typecheck all migrated tests**

Run:

```bash
xcrun --sdk iphonesimulator swiftc -typecheck -target x86_64-apple-ios13.0-simulator -sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator26.2.sdk -swift-version 6 -plugin-path /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/plugins/testing -I /private/tmp/refreshable-typecheck -F /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/Library/Frameworks Tests/RefreshableTests/MockStyle.swift Tests/RefreshableTests/RefreshComponentTests.swift Tests/RefreshableTests/EdgeTopRefreshComponentTests.swift Tests/RefreshableTests/EdgeBottomLoadMoreComponentTests.swift Tests/RefreshableTests/EdgeRefreshComponentTests.swift Tests/RefreshableTests/UIScrollViewExtensionTests.swift
```

Expected: exits `0`.

- [ ] **Step 3: Build Demo**

Run:

```bash
xcodebuild -project Demo/Demo.xcodeproj -scheme Demo -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Diff hygiene**

Run:

```bash
git diff --check
git status --short
```

Expected: no whitespace errors; status shows only intended source, test, doc, and existing demo changes.
