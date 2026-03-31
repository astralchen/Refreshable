# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

```bash
# Build (UIKit requires iOS SDK, cannot use plain `swift build`)
xcodebuild -scheme Refreshable -destination 'generic/platform=iOS' -skipPackagePluginValidation build

# Run all tests (74 tests, Swift Testing framework)
xcodebuild test -scheme Refreshable -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation

# Build Demo app
xcodebuild build -project Demo/Demo.xcodeproj -scheme Demo -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Architecture

UIScrollView extension providing pull-to-refresh and load-more via async/await, distributed as a Swift Package (iOS 13+, Swift 6.0 strict concurrency).

**Core design**: `UIScrollView` extension stores `HeaderRefreshComponent` / `FooterRefreshComponent` via associated objects. Components observe scrollView through KVO (`contentOffset`, `contentSize`, `panGestureRecognizer.state`) and drive a state machine: `idle → pulling → triggered → refreshing → ending → idle`. Footer adds a `noMoreData` terminal state.

**Customization**: `RefreshableStyle` protocol — provide a `view`, `height`, and `update(state:progress:)`. The component manages `style.view.alpha` automatically (0 when idle, fades in with pull progress, 1 during refresh).

**Concurrency**: Everything is `@MainActor`. KVO callbacks use `MainActor.assumeIsolated`. Action closures are `@MainActor () async -> Void`.

## Key Constraints

- No third-party dependencies, UIKit only
- `UIView.animate` completion runs synchronously when view has no window (affects test expectations — use `[.ending, .idle].contains(state)` instead of exact state checks)
- Associated object keys use `malloc(1)!` (not `&String`) to avoid `UnsafeRawPointer` to inout String warning
- Footer ignores pull when `contentSize.height < scrollView.bounds.height`
- Language: all user-facing strings are in Chinese (zh-CN)
