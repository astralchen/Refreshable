# Grid Refresh State Footer UI DSL

Date: 2026-07-06
Status: Selected visual target for implementation
Selected visual: `assets/grid-refresh-state-footer-selected.png`

## Goal

Turn the existing `CollectionViewDemoController` into a production-quality mobile grid demo that demonstrates Refreshable's framework behavior without desktop-style pagination controls.

The screen should feel like a simple native iOS app surface:

- Pull down to refresh the grid data.
- Refresh completion resets page state and allows bottom loading again.
- Scrolling near the bottom automatically loads more items.
- After the final batch, a full-width collection footer shows `没有更多数据`.
- The bottom load-more control ends normally, then is removed from the view hierarchy; `collectionView.noMoreData()` is not called in this demo.
- There are no manual page number buttons, no ellipsis pagination, and no left/right page navigation row.

## Effect Images

![Selected grid refresh state footer UI](assets/grid-refresh-state-footer-selected.png)

## Product Surface

```refresh-ui-dsl
screen GridRefreshDemo {
  platform: iOS UIKit
  viewport: 390x844
  controller: Demo/Demo/CollectionViewDemoController.swift
  tabTitle: "网格"
  navigationTitle: "刷新网格"
  purpose: "Demonstrate UICollectionView refresh and automatic bottom load-more in a simple mobile grid, with the terminal no-more copy rendered by a collection footer."

  hardAvoid {
    numberedPagination: true
    pageChevronControls: true
    ellipsisPagination: true
    desktopPaginationBar: true
    denseDashboardMetrics: true
    searchField: true
  }

  refreshBehavior {
    top {
      api: scrollView.refreshable
      edge: .top
      gesture: pullDown
      triggerOffset: 72
      style: SystemNativeRefreshStyle
      extent: 52
      visibleCopy {
        idle: "下拉刷新"
        pulling: "下拉刷新"
        triggered: "释放刷新"
        refreshing: "正在刷新..."
        ending: "刷新完成"
      }
      presentation: overlay(viewport, locksContentOffset)
      rule: "Top refresh floats above the grid and must not reserve contentInset or push the header/cards downward."
      headerHint: hidden
      result: "Replace items with the latest first page, set page to 0, hide the no-more footer, and re-enable bottom loading; do not insert a refresh-status card into the grid."
    }

    bottom {
      api: scrollView.loadMoreable
      edge: .bottom
      gesture: scrollNearBottom
      style: DefaultBottomLoadMoreStyle
      automaticTriggerOffset: 120
      visibleCopy {
        idle: "继续向上滑动"
        pulling: "继续向上滑动"
        triggered: "释放加载"
        refreshing: "正在加载..."
        ending: "加载完成"
        noMoreData: hidden
      }
      terminalFooter: "没有更多数据"
      terminalSubtitle: "下拉刷新后重新加载"
      presentation: overlay(contentBoundary)
      rule: "The framework load-more control ends normally and is removed from the view hierarchy; noMoreData is represented as a full-width UICollectionView section footer, not as a regular grid cell."
      result: "Append four grid items per page until page 3; after the final normal load finishes, show the terminal footer, remove loadMoreable, and do not call collectionView.noMoreData()."
    }
  }
}
```

## Visual Tokens

```refresh-ui-dsl
tokens {
  colors {
    pageBackground: UIColor.systemGroupedBackground
    surface: UIColor.secondarySystemGroupedBackground
    cardBackground: UIColor.systemBackground
    primaryText: UIColor.label
    secondaryText: UIColor.secondaryLabel
    tertiaryText: UIColor.tertiaryLabel
    separator: UIColor.separator.withAlpha(0.45)
    accent: UIColor.systemBlue
    success: UIColor.systemGreen
    warning: UIColor.systemOrange
    teal: UIColor.systemTeal
    purple: UIColor.systemPurple
  }

  typography {
    navTitle: system 17 semibold
    headerTitle: system 28 bold
    loadedCount: system 17 regular
    syncStatus: system 16 regular
    segment: system 16 semibold
    cardTitle: system 18 semibold
    cardMeta: system 15 regular
    chip: system 13 semibold
    terminalTitle: system 18 semibold
    terminalMeta: system 15 regular
  }

  spacing {
    screenHorizontal: 18
    headerTop: 28
    headerBottom: 20
    segmentHeight: 38
    gridColumnGap: 8
    gridRowGap: 10
    gridInset: 18
    cardPadding: 14
    cardMinHeight: 188
    iconSize: 52
    chipHorizontal: 10
    chipVertical: 4
  }

  radius {
    segmentOuter: 8
    segmentSelected: 8
    card: 8
    icon: 26
    chip: 6
  }
}
```

## Layout DSL

```refresh-ui-dsl
navigationBar {
  background: systemBackground
  title: text("刷新网格", token.navTitle)
  trailing: iconButton(symbol: "ellipsis", accessibilityLabel: "更多操作")
}

collectionHeader {
  background: pageBackground
  layout: verticalStack(spacing: 18)
  safeAreaAware: true

  titleRow {
    leading {
      text("最近更新", token.headerTitle)
      text("已加载 36 项", token.loadedCount, color: secondaryText)
    }
    trailing {
      dot(size: 8, color: success)
      text("刚刚同步", token.syncStatus, color: secondaryText)
    }
  }

  segmentedControl {
    items: ["全部", "加载中", "完成"]
    selectedIndex: 0
    height: token.segmentHeight
    selectedTint: accent
    selectedTextColor: white
    normalTextColor: primaryText
    background: cardBackground
    border: separator 1px
  }
}

collectionGrid {
  owner: UICollectionViewCompositionalLayout
  background: pageBackground
  columns: 2
  horizontalInset: token.gridInset
  columnGap: token.gridColumnGap
  rowGap: token.gridRowGap
  itemHeight: fixed(150)
  itemWidth: fractional(0.5)
  behavior: "All cells in a row keep equal height; long titles may wrap to two lines but must not create a masonry layout."
  scrollIndicators: false
}

terminalNoMoreDataFooter {
  owner: collectionGrid
  visibleWhen: hasLoadedAllPages
  size: fullWidthFooter(height: 124)
  placement: "section footer after the final two-column row"
  background: cardBackground
  radius: token.radius.card
  border: separator 1px
  cardInset: top 14, right 0, bottom 14, left 0
  content: horizontalFooterCard {
    icon(symbol("checkmark.circle"), size: 44, color: success)
    text("没有更多数据", token.terminalTitle, color: primaryText)
    text("下拉刷新后重新加载", token.terminalMeta, color: secondaryText)
    centeredText("36 项已加载", token.terminalCount, color: tertiaryText)
  }
  layoutRules:
    - "Title, subtitle, and count must be vertically separated; count baseline never overlaps the subtitle."
    - "The footer remains wider than tall and is supplementary footer content, not a grid cell."
}

loadMoreOverlay {
  owner: Refreshable
  visibleWhen: refreshing
  placement: overlay(contentBoundary)
  refreshingContent {
    spinner(style: medium, color: tertiaryText)
    text("正在加载...", system 15 regular, color: secondaryText)
  }

  frameworkNoMoreDataLabel {
    visible: false
    reason: "Avoid duplicating the terminal collection footer."
  }
}
```

## Cell DSL

```refresh-ui-dsl
component GridUpdateCell {
  reuseIdentifier: "GridUpdateCell"
  background: cardBackground
  cornerRadius: token.radius.card
  border: separator 1px
  selection: none
  accessibility: combineChildren

  layout: verticalStack(spacing: 12) {
    iconCircle {
      size: token.iconSize
      cornerRadius: token.radius.icon
      background: item.tint.withAlpha(0.16)
      symbol: item.symbolName
      symbolColor: item.tint
      symbolPointSize: 26
    }

    text(item.title, token.cardTitle, color: primaryText, maxLines: 2)
    text(item.source + " · " + item.time, token.cardMeta, color: secondaryText, maxLines: 1)
    chip(item.chip, style: item.chipStyle)
  }
}

component Chip {
  variants: update | article | reminder | success | repair | feature | optimize
  typography: token.chip
  cornerRadius: token.radius.chip
  padding: horizontal token.chipHorizontal, vertical token.chipVertical

  update { foreground: accent, background: accent.withAlpha(0.12) }
  article { foreground: teal, background: teal.withAlpha(0.12) }
  reminder { foreground: warning, background: warning.withAlpha(0.12) }
  success { foreground: success, background: success.withAlpha(0.12) }
  repair { foreground: purple, background: purple.withAlpha(0.12) }
  feature { foreground: accent, background: accent.withAlpha(0.12) }
  optimize { foreground: success, background: success.withAlpha(0.12) }
}
```

## Data Contract

```refresh-ui-dsl
model GridUpdateItem {
  title: String
  source: String
  time: String
  chip: String
  chipStyle: ChipStyle
  symbolName: String
  tintColor: UIColor
  status: GridStatus
}

enum GridStatus {
  all
  loading
  complete
}

paginationState {
  page: Int
  maxPage: 3
  loadedCount: Int
  totalCount: Int = 36
  state: idle | refreshing | loadingMore | hasLoadedAllPages
}
```

## Copy

```refresh-ui-dsl
copy {
  navigationTitle: "刷新网格"
  headerTitle: "最近更新"
  loadedCount: "已加载 36 项"
  syncStatus: "刚刚同步"
  filters: ["全部", "加载中", "完成"]
  loadMoreRefreshing: "正在加载..."
  noMoreTitle: "没有更多数据"
  noMoreSubtitle: "下拉刷新后重新加载"
  terminalCount: "36 项已加载"
}
```

## Accessibility

- Navigation title reads as `刷新网格`.
- Segmented control exposes three tappable filters: `全部`, `加载中`, `完成`.
- Each grid tile combines title, source, time, and chip into one VoiceOver element.
- Top refresh view exposes the framework refresh label and current state.
- Terminal collection footer exposes `没有更多数据，下拉刷新后重新加载，36 项已加载`.
- Dynamic Type is supported by using `UIFontMetrics` and allowing labels to wrap within card bounds.

## Acceptance Criteria

- The grid demo uses `UICollectionView`, not a table view.
- The screen does not show numbered pagination, ellipsis pagination, or page chevron navigation.
- Initial screen shows `最近更新`, `已加载 36 项`, and a two-column grid without a separate refresh hint row.
- Pull-to-refresh resets data, sets page back to 0, hides the footer, and reinstalls bottom loading.
- Bottom automatic load-more uses `automaticTriggerOffset: 120`.
- After the final page, a full-width collection footer shows `没有更多数据`, `下拉刷新后重新加载`, and `36 项已加载`.
- The bottom load-more control ends normally and is removed from the view hierarchy; `collectionView.noMoreData()` is not used for this demo screen.
- The UI remains simple on a 390x844 viewport with no search field, no metrics strip, and no inspector panel.
