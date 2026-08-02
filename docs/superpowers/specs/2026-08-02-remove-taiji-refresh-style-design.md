# Remove Taiji Refresh Style Design

## Goal

Remove the Taiji refresh style from the repository as a deliberate breaking change. The shipped `RefreshableStyles` product, Demo, tests, API baseline, active documentation, historical working-tree documentation, and Taiji-only visual assets must no longer expose or describe the style.

Git history remains the recovery path. No deprecated compatibility wrapper or renamed replacement will be retained.

## Scope

### Production API and implementation

- Delete `Sources/RefreshableStyles/TaijiRefreshStyle.swift` in full.
- Remove the public `TaijiRefreshStyle`, `TaijiRefreshTheme`, and `TaijiRefreshPalette` APIs with no compatibility alias.
- Keep the `RefreshableStyles` product itself; it continues to ship the Kinetic and Video styles.
- Refresh `API-Baselines/RefreshableStyles.sha256` after verifying the reduced public API.

### Demo behavior

- Remove the Taiji case and title from `CustomStylesDemoController.StyleChoice`.
- Remove Taiji installation and trigger-offset branches.
- Preserve System Native and Kinetic as the two selectable list-refresh demonstrations.
- Keep Kinetic selected by default. Its raw segmented-control index changes from `2` to `1`, which remains derived from the enum and therefore needs no migration state.
- Delete the Taiji UI-test flow and keep coverage for the remaining styles.

### Unit tests

- Delete Taiji theme synchronization and live appearance tests from `RefreshableStylesTests`.
- Preserve Kinetic, Video, and shared style-contract coverage.
- Do not replace removed API tests with stand-in coverage; absence from the module and API baseline is the intended assertion.

### Documentation and assets

- Remove Taiji examples and product descriptions from `README.md` and `REQUIREMENTS.md`.
- Update file trees, renderer inventories, test inventories, style counts, and Demo descriptions to describe only remaining behavior.
- Delete the dedicated Taiji design specification and its reference image.
- Remove Taiji sections and references from shared historical plans and UI-audit notes while preserving unrelated System Native and Kinetic material.
- Delete Taiji-only plan and UI-audit images.
- This design document and the ensuing implementation plan are temporary execution records. They will be deleted in the final repository cleanup so that the checked-out working tree has no Taiji references; their committed versions remain available through Git history.

## Architecture and data flow

No core refresh architecture changes. `Refreshable`, its renderer protocol, state reducer, geometry, inset coordination, and UIScrollView APIs remain untouched.

The only runtime path removed is:

`Demo style selection -> TaijiRefreshStyle.makeRenderer() -> Taiji renderer/view/layers`

After removal, the Demo selector maps only `system` and `kinetic` to their existing style installations. The `RefreshableStyles` Swift target discovers its remaining Swift source files automatically through Swift Package Manager, so deleting the implementation file does not require a `Package.swift` target edit.

## Compatibility and failure behavior

This is a source-breaking public API removal. Downstream code that imports or constructs a Taiji type will fail at compile time, which is intentional. The repository will not provide a runtime fallback, type alias, unavailable declaration, or deprecation period.

Because the public surface changes, release notes and semantic versioning should treat the eventual release as breaking. This repository change will update the checked-in API baseline so CI recognizes the removal as intentional.

No runtime error handling is added: remaining style selection is exhaustive at compile time, and removed cases cannot be decoded or restored from persisted Demo state because the Demo does not persist the selection.

## Verification

Verification must cover both absence and regression safety:

1. Search tracked and untracked working-tree files for `Taiji`, `taiji`, and `太极`. At final completion there must be no matches, including temporary design/plan files.
2. Run the package test suite and confirm all core and remaining style tests pass.
3. Run the API baseline check and confirm the refreshed `RefreshableStyles` baseline is accepted while the core `Refreshable` baseline remains unchanged.
4. Build the Demo with Swift 6 settings to catch enum-switch, segmented-control, and package-linking regressions.
5. Run the remaining Demo UI smoke coverage when the configured simulator is available.
6. Inspect the final diff to ensure only Taiji-specific material and required references were removed; System Native, Kinetic, Video, and core refresh behavior must remain intact.

## Success criteria

- The Taiji source file and all three public Taiji API types are absent.
- The Demo exposes only System Native and Kinetic style choices.
- No Taiji-specific unit test or UI test remains.
- No Taiji-specific image or active/historical working-tree documentation remains.
- A full working-tree text search returns no Taiji name matches.
- Package tests, API baseline validation, and Demo build pass.
