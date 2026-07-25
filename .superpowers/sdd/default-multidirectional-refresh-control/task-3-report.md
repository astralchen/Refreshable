# Task 3 Report: Four-direction default refresh preview

## Status

Implemented and verified on branch `codex/default-refresh-control`.

Implementation commit:

- `0953a4c3b86ed02300d29b93f7b9855bc17088a7` — `Add four-direction default refresh preview`

## Changed files

- `Demo/Demo/CustomStylesDemoController.swift`
  - Replaces the inert trailing navigation icon with the `默认预览` entry point.
  - Pushes the dedicated default-control preview and exposes a stable UI-test identifier.
- `Demo/Demo/DefaultRefreshControlPreviewController.swift`
  - Adds a two-axis `UIScrollView` canvas with a visible grid and physical boundary markers.
  - Adds edge, role, text, manual-trigger, no-more-data, reset, and status controls.
  - Removes every prior edge/role component before installing exactly one selected no-style component.
  - Uses `RefreshableOptions` with `allowsLoadMoreWhenContentFits: true`, optional built-in text configuration, and state reporting.
  - Positions the canvas at the selected physical top, bottom, leading, or trailing boundary after layout.
  - Uses the existing public begin, no-more-data, and reset APIs.
  - Keeps the normal async preview action at 1.2 seconds; UI automation can lengthen it through a test-only launch environment value.
  - Mirrors the actual visible default-indicator label into the existing status element's accessibility value so UI automation verifies rendered copy without adding duplicate visible Demo text.
- `Demo/DemoUITests/DemoUITests.swift`
  - Adds controls/canvas coverage.
  - Adds deliberate physical coordinate drags for top, bottom, leading, and trailing and verifies refresh state and indicator placement.
  - Verifies default mode has no visible status copy.
  - Verifies the real indicator renders `正在刷新...` with text enabled and `没有更多数据` in the load-more terminal state.
  - Verifies reset removes the terminal indicator and keeps screenshots for both text states.
  - Pins only these preview tests to portrait and uses test-only action windows so gesture distance and transient accessibility assertions are deterministic.
  - Preserves the existing System, Tai Chi, and Dynamic real-pull regression test.

## RED

Tests were added before the preview implementation.

Initial command:

```bash
xcodebuild test \
  -project Demo/Demo.xcodeproj \
  -scheme Demo \
  -destination 'platform=iOS Simulator,id=40789BEC-6977-4FC6-AA42-0ACDF687EF7D' \
  -derivedDataPath '/Users/chenchen/Library/Developer/Xcode/DerivedData/Refreshable-default-refresh-control-fakszpqajdnmcggiroakruhhzqup' \
  -skipPackagePluginValidation \
  -enableCodeCoverage NO \
  -only-testing:DemoUITests/DemoUITests/testDefaultRefreshPreviewShowsAllControls
```

Result:

- Exit code `65`.
- Expected failure at `DemoUITests.swift:345`: `XCTAssertTrue failed`.
- The stable `DefaultRefreshPreview.Entry` button did not exist before production changes.
- Result bundle: `Test-Demo-2026.07.25_19-57-50-+0800.xcresult`.

Independent review then identified that the first tests proved indicator state and captured screenshots but did not directly prove the rendered Chinese copy. Exact-copy assertions were added before the accessibility bridge.

Review follow-up RED command:

```bash
xcodebuild test \
  -project Demo/Demo.xcodeproj \
  -scheme Demo \
  -destination 'platform=iOS Simulator,id=40789BEC-6977-4FC6-AA42-0ACDF687EF7D' \
  -derivedDataPath '/Users/chenchen/Library/Developer/Xcode/DerivedData/Refreshable-default-refresh-control-fakszpqajdnmcggiroakruhhzqup' \
  -skipPackagePluginValidation \
  -enableCodeCoverage NO \
  -parallel-testing-enabled NO \
  -maximum-parallel-testing-workers 1 \
  -only-testing:DemoUITests/DemoUITests/testDefaultRefreshPreviewTextAndNoMoreDataControls
```

Result:

- Exit code `65`.
- Expected failure at `DemoUITests.swift:115`: the status accessibility value was empty instead of `正在刷新...`.
- Result bundle: `Test-Demo-2026.07.25_20-23-59-+0800.xcresult`.

## GREEN

The focused exact-copy test passed after deriving the accessibility value from the real visible `UILabel` inside `Refreshable.DefaultIndicator`:

- Exit code `0`.
- `1 test, 0 failures` in `27.289` seconds.
- Result bundle: `Test-Demo-2026.07.25_20-26-12-+0800.xcresult`.

An earlier full Demo UI run, before the review follow-up assertions, also preserved all existing regression coverage:

```bash
xcodebuild test \
  -project Demo/Demo.xcodeproj \
  -scheme Demo \
  -destination 'platform=iOS Simulator,id=40789BEC-6977-4FC6-AA42-0ACDF687EF7D' \
  -derivedDataPath '/Users/chenchen/Library/Developer/Xcode/DerivedData/Refreshable-default-refresh-control-fakszpqajdnmcggiroakruhhzqup' \
  -skipPackagePluginValidation \
  -enableCodeCoverage NO \
  -parallel-testing-enabled NO \
  -maximum-parallel-testing-workers 1 \
  -only-testing:DemoUITests
```

Result:

- Exit code `0`.
- `18 tests, 0 failures` in `362.647` seconds.
- Includes the retained System, Tai Chi, and Dynamic physical-pull coverage.
- Result bundle: `Test-Demo-2026.07.25_20-14-27-+0800.xcresult`.

The first combined follow-up run exposed a transient top-pull miss in the simulator's persisted landscape orientation. A deliberate slow held drag alone still left the landscape canvas too short, and a later run showed the 3-second UI-test action could finish just before a slow accessibility snapshot. The tests were narrowed to portrait and given role-appropriate test-only action windows; production behavior remained 1.2 seconds.

Final Task 3 UI command:

```bash
xcodebuild test \
  -project Demo/Demo.xcodeproj \
  -scheme Demo \
  -destination 'platform=iOS Simulator,id=40789BEC-6977-4FC6-AA42-0ACDF687EF7D' \
  -derivedDataPath '/Users/chenchen/Library/Developer/Xcode/DerivedData/Refreshable-default-refresh-control-fakszpqajdnmcggiroakruhhzqup' \
  -skipPackagePluginValidation \
  -enableCodeCoverage NO \
  -parallel-testing-enabled NO \
  -maximum-parallel-testing-workers 1 \
  -only-testing:DemoUITests/DemoUITests/testDefaultRefreshPreviewShowsAllControls \
  -only-testing:DemoUITests/DemoUITests/testDefaultRefreshPreviewPhysicallyRefreshesAtEveryEdge \
  -only-testing:DemoUITests/DemoUITests/testDefaultRefreshPreviewTextAndNoMoreDataControls
```

Result:

- Exit code `0`.
- `3 tests, 0 failures` in `113.718` seconds.
- All four real physical edge drags, edge-location assertions, exact rendered-copy assertions, screenshots, no-more-data, and reset passed.
- Result bundle: `Test-Demo-2026.07.25_20-33-17-+0800.xcresult`.

Final Demo build command:

```bash
xcodebuild build \
  -project Demo/Demo.xcodeproj \
  -scheme Demo \
  -destination 'platform=iOS Simulator,id=40789BEC-6977-4FC6-AA42-0ACDF687EF7D' \
  -derivedDataPath '/Users/chenchen/Library/Developer/Xcode/DerivedData/Refreshable-default-refresh-control-fakszpqajdnmcggiroakruhhzqup' \
  -skipPackagePluginValidation
```

Result:

- Exit code `0`.
- `BUILD SUCCEEDED`.
- The App Intents metadata extractor emitted the existing no-framework warning only.
- `git diff --check` passed before the implementation commit.

## Self-review

- Confirmed the preview installs only the no-style `refreshable(edge:options:)` and `loadMoreable(edge:options:)` overloads.
- Confirmed every selection change removes refresh and load-more components from all four edges before installing one selected component.
- Confirmed text-off passes `nil` and text-on passes `RefreshableTextConfiguration()`.
- Confirmed the default visible-copy assertion is derived from the real indicator label and is empty in all four no-text edge cases.
- Confirmed the text-enabled and no-more-data assertions validate exact built-in copy from the real rendered label.
- Confirmed all four directions use real coordinate drags and verify the indicator frame against the selected canvas edge.
- Confirmed the canvas is positioned without animation using adjusted inset-aware minimum and maximum offsets.
- Confirmed the preview is fixed to LTR so leading and trailing match left and right.
- Confirmed manual trigger, no-more-data, and reset use existing public library APIs.
- Confirmed no Task 2 library implementation or public API was changed.
- Confirmed existing custom-style pull coverage remains present and passed in the full Demo UI run.
- Independent follow-up review reported no remaining Blocker or Important issues.

## Concerns

- The Demo project resolves its local Swift package through `../../Refreshable`, which maps to `/tmp/Refreshable` from this worktree. That path did not exist, so an untracked symlink `/private/tmp/Refreshable -> /private/tmp/Refreshable-default-refresh-control` was created outside the repository for build/test resolution. No project file was modified.
- The simulator was initially shutdown, so the exact required UDID was booted once and was not shut down or erased.
- No code concerns remain.
