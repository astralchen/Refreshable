# Refresh Unified Architecture Design

Date: 2026-07-02
Status: Approved for implementation review

## Goal

Unify the refresh and load-more implementation around one internal component architecture. Top refresh, bottom load-more, leading refresh, and trailing load-more should all be represented by `EdgeRefreshComponent(edge:role:style:options:action:)`.

## Problem

The public API already installs `EdgeRefreshComponent` for refresh and load-more edges, but the codebase still contains legacy `HeaderRefreshComponent` and `FooterRefreshComponent` types plus separate header/footer test suites. This makes the top refresh path look like a different architecture even though it should share the same state machine, inset handling, safe-area behavior, and edge geometry rules.

## Architecture

`EdgeRefreshComponent` is the single internal component for all semantic edges and roles:

- `.top + .refresh`
- `.bottom + .loadMore`
- `.leading + .refresh`
- `.trailing + .loadMore`
- Any other supported edge/role combination exposed by the existing API

The component owns:

- Installing and removing `style.view`
- KVO-driven scroll observation
- Pull distance calculation
- State transitions
- Manual begin/end behavior
- Content inset and content offset adjustment
- Overlay presentation behavior
- Safe-area and adjusted-inset handling
- `noMoreData` behavior for load-more only

`DefaultHeaderStyle`, `DefaultFooterStyle`, and `DefaultEdgeStyle` remain separate style objects. They are UI choices, not component architecture branches.

## Compatibility

Public API remains unchanged:

- `refreshable(...)`
- `loadMoreable(...)`
- `beginRefreshing(...)`
- `endRefreshing(...)`
- `beginLoadingMore(...)`
- `endLoadingMore(...)`
- `noMoreData(...)`
- `resetNoMoreData(...)`
- State query and enable/disable helpers

The old internal wrapper classes should not be required by public API behavior. If no internal callsites need them after tests are migrated, remove `HeaderRefreshComponent.swift` and `FooterRefreshComponent.swift` from the package. If removal creates project-file churn or compatibility risk, reduce them to temporary aliases with no unique behavior and mark them for follow-up removal.

## Test Strategy

Move behavior coverage from header/footer-specific suites into unified edge-component coverage.

Unified tests should cover:

- `.top + .refresh` installation, frame, state transitions, begin/end, inset reset, current inset recapture, custom trigger offset, invalid trigger fallback, action execution, cancellation, and nil-scroll-view ending.
- `.bottom + .loadMore` installation, frame, state transitions, begin/end, inset reset, content-size repositioning, short-content load rules, custom trigger offset, no-more-data, action execution, and manual ending.
- Cross-edge isolation so removing or ending one edge does not corrupt another edge's inset.
- Safe-area and adjusted-inset behavior for bottom and horizontal edges.
- Overlay presentation behavior for refresh and load-more.
- Public `UIScrollView` API still installs and routes to the unified component store.

Tests may keep helper names that mention header or footer only when describing public semantics. New component tests should prefer edge/role wording.

## Non-Goals

- No public API changes.
- No style redesign.
- No new dependency or snapshot testing framework.
- No behavior change for existing default header/footer visuals.
- No broad refactor of unrelated demo UI.

## Acceptance Criteria

- `HeaderRefreshComponent` and `FooterRefreshComponent` no longer contain unique architecture logic.
- Unified edge tests cover top refresh and bottom load-more behavior.
- Existing public API tests still pass or typecheck under the available iOS test workflow.
- Demo iOS Simulator build succeeds.
- `swift test` limitation for UIKit-on-macOS remains documented if no iOS test-host scheme is added.
