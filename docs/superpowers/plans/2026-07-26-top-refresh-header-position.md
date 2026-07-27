# Top Refresh Header Position Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep the grid header visible at the top boundary before, during, and after a locked overlay refresh, even when the refresh action reloads content and invalidates layout.

**Architecture:** `EdgeRefreshComponent` owns a refresh-lifecycle boundary lock for overlay presentations whose `locksContentOffset` option is enabled. It establishes the lock only when refreshing begins at the component edge, recomputes the physical boundary from the current inset-coordinator baseline after geometry changes, preserves the cross axis, performs a final correction when ending, and clears the lock for every terminal/removal path.

**Tech Stack:** Swift 6, UIKit, Swift Testing, XCTest UI tests, iOS 13+

## Global Constraints

- Work in the existing `main` workspace because the user explicitly requested the prior work be merged there.
- Preserve the existing uncommitted pan-gesture and grid UI-test changes.
- Reuse iPhone 17 Pro simulator `40789BEC-6977-4FC6-AA42-0ACDF687EF7D` and the existing DerivedData directory.
- Do not boot or create another simulator.
- Follow red-green-refactor: every production behavior change starts with a test that fails for the intended reason.

---

## Task 1: Lock the overlay boundary for the complete refresh lifecycle

**Files:**

- Modify: `Tests/RefreshableTests/EdgeRefreshComponentTests.swift`
- Modify: `Sources/Refreshable/Components/EdgeRefreshComponent.swift`

- [x] Add a Swift Testing regression that installs a top `.overlay(spacing: 12, locksContentOffset: true)` refresh component at the adjusted top boundary, begins refreshing, simulates a layout-driven `contentOffset` drift, calls `scrollViewContentSizeDidChange`, and expects the component to restore the adjusted top boundary.
- [x] Run `xcodebuild test -scheme Refreshable-Package -destination 'platform=iOS Simulator,id=40789BEC-6977-4FC6-AA42-0ACDF687EF7D' -derivedDataPath '/Users/chenchen/Library/Developer/Xcode/DerivedData/Refreshable-default-refresh-control-fakszpqajdnmcggiroakruhhzqup' -only-testing:RefreshableTests/EdgeRefreshComponentTests` and confirm the new assertion fails because the offset remains drifted.
- [x] Add an internal lifecycle flag to `EdgeRefreshComponent`.
- [x] Establish the flag when a locked overlay refresh is revealed while already at the target boundary.
- [x] Restore the current physical boundary after content-size, bounds, content-inset, and environment changes while the flag is active. Reuse `lockedOverlayContentOffset(in:)` so the coordinator baseline, safe-area adjustment, content size, RTL, and cross-axis preservation remain centralized.
- [x] Before overlay ending/removal completion, perform one last restore and clear the flag. Also clear it from installed-view removal.
- [x] Add a second regression proving that, after refresh ending/removal, later geometry updates no longer restore the obsolete boundary.
- [x] Re-run the targeted suite and confirm both regressions pass.

## Task 2: Assert the grid header is visibly inside the viewport

**Files:**

- Modify: `Demo/DemoUITests/DemoUITests.swift`
- Preserve: `Demo/Demo/CollectionViewDemoController.swift`

- [x] Reuse the frame-intersection assertion to verify that “最近更新” intersects the collection-view frame; `.exists` alone is insufficient because XCTest reports offscreen supplementary views as existing.
- [x] Add a real top pull test with `GridRefresh.UITestRefreshActionDuration` set long enough to observe refreshing, then wait for completion and assert the header is still visible and the original first item remains.
- [x] Assert that the refresh indicator stays above `GridHeaderView`, then remove the grid page's explicit overlay configuration so `RefreshableOptions` uses its default `.contentInset`.
- [x] Add a core regression for a default content-inset refresh whose layout reload moves `contentOffset` by one header height, then maintain the reveal boundary during refreshing and restore the adjusted baseline boundary while ending.
- [x] Run only the new UI test against the shared simulator with parallel testing disabled.
- [x] Confirm that no Demo `setContentOffset` workaround is needed.

## Task 3: Verification

- [x] Run the full `Refreshable-Package` test suite.
- [x] Run the grid screen-load, top-refresh release, header-position, bottom-load-more safe-area, and no-more-data UI tests serially on the shared simulator.
- [x] Build the Demo for testing with Swift 6 settings using the existing DerivedData.
- [x] Inspect `git diff --check`, `git status`, and the final scoped diff to ensure previous user changes remain intact.
- [x] Use `superpowers:verification-before-completion` before reporting the fix complete.
