# List Refresh Production UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade the first demo tab into a production-quality vertical list screen that demonstrates pull-to-refresh and automatic bottom load-more.

**Architecture:** Keep the work scoped to the Demo app. `TableViewDemoController` owns the mock data, table header, refresh/load-more wiring, and private cell classes; the Refreshable package public API remains unchanged. Existing built-in refresh styles are reused, with `automaticTriggerOffset` enabling scroll-near-bottom loading.

**Tech Stack:** Swift, UIKit, Refreshable, SF Symbols, XCTest UI tests, Xcode project Demo app.

---

## Source Documents And Assets

- UI DSL: `docs/superpowers/specs/2026-07-06-list-refresh-production-ui-dsl.md`
- Selected target image: `docs/superpowers/specs/assets/list-refresh-selected-update-list.png`

## Visual Reference

![Selected list refresh production UI](../specs/assets/list-refresh-selected-update-list.png)

## File Structure

- Modify: `Demo/Demo/TableViewDemoController.swift`
  - Replace placeholder string data with a private `UpdateItem` model.
  - Add a production table header with status and segmented control.
  - Install `SystemNativeRefreshStyle` for top refresh and `DefaultBottomLoadMoreStyle` for bottom load-more.
  - Configure `automaticTriggerOffset: 120` on bottom load-more.
  - Add private `UpdateItemCell`, `UpdateListHeaderView`, `StatusChipView`, and supporting helpers.
- Modify: `Demo/DemoUITests/DemoUITests.swift`
  - Add UI tests for the first tab's production labels.
  - Add a refresh test that pulls the list and verifies the inserted row.
- Read only: `Sources/Refreshable/Core/RefreshableOptions.swift`
  - Confirms `automaticTriggerOffset` already exists and should be used.
- Read only: `Sources/Refreshable/Styles/Custom/SystemNativeRefreshStyle.swift`
  - Confirms a compact top refresh style exists and matches the target direction.
- Read only: `Sources/Refreshable/Styles/Default/DefaultBottomLoadMoreStyle.swift`
  - Confirms default bottom copy and no-more-data copy already exist.

## Task 1: Add UI Test Coverage For The New First Tab

**Files:**
- Modify: `Demo/DemoUITests/DemoUITests.swift`
- Modify later: `Demo/Demo/TableViewDemoController.swift`

- [ ] **Step 1: Add a production-screen smoke test**

Append this test inside `DemoUITests`:

```swift
@MainActor
func testListRefreshProductionScreenLoads() throws {
    let app = XCUIApplication()
    app.launch()

    let listTab = app.tabBars.buttons["列表"]
    XCTAssertTrue(listTab.waitForExistence(timeout: 5))
    listTab.tap()

    XCTAssertTrue(app.navigationBars["列表刷新"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["今日更新"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["刚刚同步 · 24 项缓存"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["全部"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["关注"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["系统"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["版本 2.1.0 发布"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["新增下拉刷新动画效果，优化自动加载逻辑，修复列表边界问题。"].waitForExistence(timeout: 3))
}
```

- [ ] **Step 2: Add a refresh behavior UI test**

Append this test inside `DemoUITests`:

```swift
@MainActor
func testListRefreshInsertsFreshRow() throws {
    let app = XCUIApplication()
    app.launch()

    let listTab = app.tabBars.buttons["列表"]
    XCTAssertTrue(listTab.waitForExistence(timeout: 5))
    listTab.tap()

    let table = app.tables.firstMatch
    XCTAssertTrue(table.waitForExistence(timeout: 3))

    let start = table.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.18))
    let end = table.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.74))
    start.press(forDuration: 0.08, thenDragTo: end)

    XCTAssertTrue(app.staticTexts["刚刚刷新完成"].waitForExistence(timeout: 4))
    XCTAssertTrue(app.staticTexts["已同步最新更新流，并重置底部自动加载状态。"].waitForExistence(timeout: 4))
}
```

- [ ] **Step 3: Run the tests to verify they fail before implementation**

Run:

```bash
xcodebuild test -project Demo/Demo.xcodeproj -scheme Demo -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DemoUITests/DemoUITests/testListRefreshProductionScreenLoads -only-testing:DemoUITests/DemoUITests/testListRefreshInsertsFreshRow
```

Expected before implementation: at least one assertion fails because `TableViewDemoController` still shows placeholder `Item N` rows and lacks the production header.

## Task 2: Replace Placeholder Data With Production Update Items

**Files:**
- Modify: `Demo/Demo/TableViewDemoController.swift`

- [ ] **Step 1: Replace string data with a private model**

Replace:

```swift
private var items: [String] = []
```

with:

```swift
fileprivate struct UpdateItem {
    enum ChipStyle {
        case blue
        case teal
        case green
        case gray
        case purple
    }

    let title: String
    let summary: String
    let source: String
    let time: String
    let chip: String
    let chipStyle: ChipStyle
    let symbolName: String
    let tintColor: UIColor
    let isUnread: Bool
}

private var items: [UpdateItem] = []
private var refreshCount = 0
```

- [ ] **Step 2: Add deterministic item factories**

Add these methods before `loadInitialData()`:

```swift
private func makeInitialItems() -> [UpdateItem] {
    [
        UpdateItem(
            title: "版本 2.1.0 发布",
            summary: "新增下拉刷新动画效果，优化自动加载逻辑，修复列表边界问题。",
            source: "刷新库",
            time: "10:34",
            chip: "更新",
            chipStyle: .blue,
            symbolName: "paperplane.fill",
            tintColor: .systemPurple,
            isUnread: true
        ),
        UpdateItem(
            title: "关注：技术分享精选",
            summary: "iOS 列表性能优化实践：从数据源到渲染的全链路优化方案。",
            source: "张三",
            time: "09:58",
            chip: "文章",
            chipStyle: .teal,
            symbolName: "person.2.fill",
            tintColor: .systemTeal,
            isUnread: true
        ),
        UpdateItem(
            title: "系统通知",
            summary: "你的缓存将在 7 天后过期，请及时清理以释放存储空间。",
            source: "系统",
            time: "09:12",
            chip: "提醒",
            chipStyle: .gray,
            symbolName: "bell.fill",
            tintColor: .systemOrange,
            isUnread: false
        ),
        UpdateItem(
            title: "接口文档更新",
            summary: "刷新接口新增字段说明与示例代码，支持更多自定义配置。",
            source: "API 团队",
            time: "昨天 18:42",
            chip: "更新",
            chipStyle: .blue,
            symbolName: "doc.text.fill",
            tintColor: .systemBlue,
            isUnread: false
        ),
        UpdateItem(
            title: "构建任务完成",
            summary: "Refreshable iOS Demo 2.1.0 (45) 构建成功，可用于测试。",
            source: "CI 服务",
            time: "昨天 17:33",
            chip: "成功",
            chipStyle: .green,
            symbolName: "checkmark.circle.fill",
            tintColor: .systemGreen,
            isUnread: false
        ),
        UpdateItem(
            title: "问题修复",
            summary: "修复快速连续下拉时刷新状态异常的问题，提升稳定性。",
            source: "李四",
            time: "昨天 16:21",
            chip: "修复",
            chipStyle: .purple,
            symbolName: "chevron.left.forwardslash.chevron.right",
            tintColor: .systemPurple,
            isUnread: false
        ),
        UpdateItem(
            title: "新功能：自定义刷新头",
            summary: "支持开发者自定义刷新头视图与交互，灵活适配业务需求。",
            source: "产品团队",
            time: "昨天 15:07",
            chip: "新功能",
            chipStyle: .blue,
            symbolName: "star.fill",
            tintColor: .systemBlue,
            isUnread: false
        ),
    ]
}

private func makeRefreshedItem() -> UpdateItem {
    refreshCount += 1
    return UpdateItem(
        title: "刚刚刷新完成",
        summary: "已同步最新更新流，并重置底部自动加载状态。",
        source: "刷新库",
        time: "刚刚",
        chip: "刚刚",
        chipStyle: .green,
        symbolName: "arrow.clockwise.circle.fill",
        tintColor: .systemGreen,
        isUnread: true
    )
}

private func makePageItems(page: Int) -> [UpdateItem] {
    let base = page * 3
    return [
        UpdateItem(
            title: "分页记录 \(base + 1)",
            summary: "滚动到底部后自动加载的生产列表内容，用于验证自动触发距离。",
            source: "自动加载",
            time: "今天",
            chip: "分页",
            chipStyle: .blue,
            symbolName: "tray.and.arrow.down.fill",
            tintColor: .systemBlue,
            isUnread: false
        ),
        UpdateItem(
            title: "缓存同步 \(base + 2)",
            summary: "新增的分页数据保持与主列表一致的排版、图标和状态标签。",
            source: "同步队列",
            time: "今天",
            chip: "同步",
            chipStyle: .teal,
            symbolName: "externaldrive.connected.to.line.below.fill",
            tintColor: .systemTeal,
            isUnread: false
        ),
        UpdateItem(
            title: "后台任务 \(base + 3)",
            summary: "确认加载更多、没有更多数据和下拉刷新重置逻辑可以共存。",
            source: "系统",
            time: "今天",
            chip: "任务",
            chipStyle: .gray,
            symbolName: "gearshape.2.fill",
            tintColor: .systemGray,
            isUnread: false
        ),
    ]
}
```

- [ ] **Step 3: Update initial loading**

Replace `loadInitialData()` with:

```swift
private func loadInitialData() {
    items = makeInitialItems()
    tableView.reloadData()
}
```

## Task 3: Build The Production Header And Refresh Wiring

**Files:**
- Modify: `Demo/Demo/TableViewDemoController.swift`

- [ ] **Step 1: Register a custom cell and tune table appearance**

In `setupTableView()`, replace the current table visual setup with:

```swift
tableView.frame = view.bounds
tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
tableView.backgroundColor = .systemGroupedBackground
tableView.dataSource = self
tableView.rowHeight = UITableView.automaticDimension
tableView.estimatedRowHeight = 104
tableView.separatorStyle = .none
tableView.contentInsetAdjustmentBehavior = .automatic
tableView.register(UpdateItemCell.self, forCellReuseIdentifier: UpdateItemCell.reuseIdentifier)
view.addSubview(tableView)
```

- [ ] **Step 2: Add and size the table header**

Add:

```swift
private let headerView = UpdateListHeaderView()

private func installTableHeader() {
    headerView.configure(
        title: "今日更新",
        status: "刚刚同步 · 24 项缓存",
        selectedIndex: 0
    )
    headerView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 138)
    tableView.tableHeaderView = headerView
}

override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    guard let header = tableView.tableHeaderView else { return }
    let fittingSize = CGSize(width: tableView.bounds.width, height: UIView.layoutFittingCompressedSize.height)
    let height = header.systemLayoutSizeFitting(
        fittingSize,
        withHorizontalFittingPriority: .required,
        verticalFittingPriority: .fittingSizeLevel
    ).height
    if abs(header.frame.height - height) > 0.5 {
        header.frame.size.height = height
        tableView.tableHeaderView = header
    }
}
```

Call `installTableHeader()` after adding the table view and before installing refresh controls.

- [ ] **Step 3: Use Refreshable options for automatic load-more**

Replace the current refresh/load-more closures with:

```swift
let refreshOptions = RefreshableOptions(
    triggerOffset: 86,
    animationDuration: 0.32,
    placement: RefreshablePlacement(contentSpacing: 4)
)

tableView.refreshable(
    style: SystemNativeRefreshStyle(
        extent: 72,
        lastUpdatedText: "松手即可查看最新内容"
    ),
    options: refreshOptions
) { [weak self] in
    try? await Task.sleep(nanoseconds: 900_000_000)
    await MainActor.run {
        self?.performRefresh()
    }
}

let loadMoreOptions = RefreshableOptions(
    animationDuration: 0.28,
    automaticTriggerOffset: 120,
    placement: RefreshablePlacement(contentSpacing: 6)
)

tableView.loadMoreable(options: loadMoreOptions) { [weak self] in
    try? await Task.sleep(nanoseconds: 700_000_000)
    await MainActor.run {
        self?.appendNextPage()
    }
}
```

- [ ] **Step 4: Add refresh and pagination methods**

Add:

```swift
private func performRefresh() {
    page = 0
    var refreshed = makeInitialItems()
    refreshed.insert(makeRefreshedItem(), at: 0)
    items = refreshed
    headerView.configure(
        title: "今日更新",
        status: "刚刚同步 · 24 项缓存",
        selectedIndex: headerView.selectedIndex
    )
    tableView.reloadData()
    tableView.resetNoMoreData()
}

private func appendNextPage() {
    page += 1
    guard page <= 3 else {
        tableView.noMoreData()
        return
    }
    items.append(contentsOf: makePageItems(page: page))
    tableView.reloadData()
}
```

## Task 4: Implement Header And Row Components

**Files:**
- Modify: `Demo/Demo/TableViewDemoController.swift`

- [ ] **Step 1: Replace the data source cell configuration**

Replace `cellForRowAt` with:

```swift
func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(
        withIdentifier: UpdateItemCell.reuseIdentifier,
        for: indexPath
    ) as! UpdateItemCell
    cell.configure(with: items[indexPath.row])
    return cell
}
```

- [ ] **Step 2: Add `UpdateListHeaderView`**

Add a private view after `TableViewDemoController`:

```swift
private final class UpdateListHeaderView: UIView {
    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let statusDot = UIView()
    private let segmentedControl = UISegmentedControl(items: ["全部", "关注", "系统"])

    var selectedIndex: Int { segmentedControl.selectedSegmentIndex }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String, status: String, selectedIndex: Int) {
        titleLabel.text = title
        statusLabel.text = status
        segmentedControl.selectedSegmentIndex = selectedIndex
    }

    private func configureUI() {
        backgroundColor = .systemGroupedBackground

        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.font = .systemFont(ofSize: 15)
        statusLabel.textColor = .secondaryLabel
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        statusDot.backgroundColor = .systemGreen
        statusDot.layer.cornerRadius = 4
        statusDot.translatesAutoresizingMaskIntoConstraints = false

        segmentedControl.selectedSegmentTintColor = .systemBlue
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.secondaryLabel], for: .normal)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false

        addSubview(titleLabel)
        addSubview(statusLabel)
        addSubview(statusDot)
        addSubview(segmentedControl)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 28),

            statusDot.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            statusDot.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            statusDot.widthAnchor.constraint(equalToConstant: 8),
            statusDot.heightAnchor.constraint(equalToConstant: 8),

            statusLabel.trailingAnchor.constraint(equalTo: statusDot.leadingAnchor, constant: -8),
            statusLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),

            segmentedControl.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            segmentedControl.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            segmentedControl.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            segmentedControl.heightAnchor.constraint(equalToConstant: 38),
            segmentedControl.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -22),
        ])
    }
}
```

- [ ] **Step 3: Add `StatusChipView` and `UpdateItemCell`**

Add:

```swift
private final class StatusChipView: UILabel {
    func configure(text: String, style: UpdateItem.ChipStyle) {
        self.text = text
        font = .systemFont(ofSize: 13, weight: .semibold)
        textAlignment = .center
        layer.cornerRadius = 6
        layer.cornerCurve = .continuous
        clipsToBounds = true

        switch style {
        case .blue:
            textColor = .systemBlue
            backgroundColor = UIColor.systemBlue.withAlphaComponent(0.12)
        case .teal:
            textColor = .systemTeal
            backgroundColor = UIColor.systemTeal.withAlphaComponent(0.12)
        case .green:
            textColor = .systemGreen
            backgroundColor = UIColor.systemGreen.withAlphaComponent(0.14)
        case .gray:
            textColor = .secondaryLabel
            backgroundColor = UIColor.systemGray5
        case .purple:
            textColor = .systemPurple
            backgroundColor = UIColor.systemPurple.withAlphaComponent(0.12)
        }
    }
}

private final class UpdateItemCell: UITableViewCell {
    static let reuseIdentifier = "UpdateItemCell"

    private let unreadDot = UIView()
    private let avatarView = UIView()
    private let avatarImageView = UIImageView()
    private let titleLabel = UILabel()
    private let summaryLabel = UILabel()
    private let metaLabel = UILabel()
    private let chipLabel = StatusChipView()
    private let chevronView = UIImageView(image: UIImage(systemName: "chevron.right"))
    private let separatorView = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configureUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with item: UpdateItem) {
        unreadDot.isHidden = !item.isUnread
        avatarView.configure(tintColor: item.tintColor)
        avatarImageView.image = UIImage(systemName: item.symbolName)
        avatarImageView.tintColor = .white
        titleLabel.text = item.title
        summaryLabel.text = item.summary
        metaLabel.text = "\(item.source) · \(item.time)"
        chipLabel.configure(text: item.chip, style: item.chipStyle)
        accessibilityLabel = "\(item.title)，\(item.summary)，\(item.source)，\(item.time)，\(item.chip)"
    }

    private func configureUI() {
        selectionStyle = .none
        backgroundColor = .secondarySystemGroupedBackground
        contentView.backgroundColor = .secondarySystemGroupedBackground
        isAccessibilityElement = true

        unreadDot.backgroundColor = .systemBlue
        unreadDot.layer.cornerRadius = 4
        unreadDot.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(unreadDot)

        avatarView.layer.cornerRadius = 36
        avatarView.layer.cornerCurve = .continuous
        avatarView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(avatarView)

        avatarImageView.contentMode = .center
        avatarImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 34, weight: .semibold)
        avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.addSubview(avatarImageView)

        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 1
        titleLabel.adjustsFontForContentSizeCategory = true

        summaryLabel.font = .systemFont(ofSize: 16)
        summaryLabel.textColor = .label
        summaryLabel.numberOfLines = 2
        summaryLabel.adjustsFontForContentSizeCategory = true

        metaLabel.font = .systemFont(ofSize: 14)
        metaLabel.textColor = .secondaryLabel

        let metaRow = UIStackView(arrangedSubviews: [metaLabel, chipLabel])
        metaRow.axis = .horizontal
        metaRow.alignment = .center
        metaRow.spacing = 12

        let textStack = UIStackView(arrangedSubviews: [titleLabel, summaryLabel, metaRow])
        textStack.axis = .vertical
        textStack.spacing = 6
        textStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textStack)

        chevronView.tintColor = .tertiaryLabel
        chevronView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(chevronView)

        separatorView.backgroundColor = UIColor.separator.withAlphaComponent(0.45)
        separatorView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(separatorView)

        NSLayoutConstraint.activate([
            unreadDot.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            unreadDot.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),
            unreadDot.widthAnchor.constraint(equalToConstant: 8),
            unreadDot.heightAnchor.constraint(equalToConstant: 8),

            avatarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 38),
            avatarView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            avatarView.widthAnchor.constraint(equalToConstant: 72),
            avatarView.heightAnchor.constraint(equalToConstant: 72),

            avatarImageView.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            avatarImageView.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),

            textStack.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 18),
            textStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            textStack.trailingAnchor.constraint(equalTo: chevronView.leadingAnchor, constant: -12),
            textStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),

            chevronView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            chevronView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            chipLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 24),
            chipLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 48),

            separatorView.leadingAnchor.constraint(equalTo: textStack.leadingAnchor),
            separatorView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            separatorView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            separatorView.heightAnchor.constraint(equalToConstant: 0.5),
        ])
    }
}
```

## Task 5: Verify Build And UI Behavior

**Files:**
- Modify: `Demo/Demo/TableViewDemoController.swift`
- Modify: `Demo/DemoUITests/DemoUITests.swift`

- [ ] **Step 1: Build the Demo app**

Run:

```bash
xcodebuild build -project Demo/Demo.xcodeproj -scheme Demo -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: build succeeds.

- [ ] **Step 2: Run the new UI tests**

Run:

```bash
xcodebuild test -project Demo/Demo.xcodeproj -scheme Demo -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DemoUITests/DemoUITests/testListRefreshProductionScreenLoads -only-testing:DemoUITests/DemoUITests/testListRefreshInsertsFreshRow
```

Expected: both new tests pass.

- [ ] **Step 3: Manual visual QA**

Open the first tab in the Demo app and compare it against:

```text
docs/superpowers/specs/assets/list-refresh-selected-update-list.png
```

Expected:

- Navigation title is `列表刷新`.
- Header title is `今日更新`.
- Status line is `刚刚同步 · 24 项缓存`.
- Segmented control shows `全部 / 关注 / 系统`.
- The `正在刷新...` area appears only during pull/refresh, not as a permanent idle header row.
- First visible row is `版本 2.1.0 发布`.
- Rows use circular symbol avatars, bold titles, two-line summaries, metadata, chips, separators, and chevrons.
- Pull down inserts `刚刚刷新完成`.
- Scrolling near the bottom starts loading automatically.
- After the final page, footer shows `没有更多数据`.

## Task 6: Final Cleanup

**Files:**
- Modify: `Demo/Demo/TableViewDemoController.swift`
- Modify: `Demo/DemoUITests/DemoUITests.swift`

- [ ] **Step 1: Remove unused code**

Check:

```bash
rg "刷新后 Item|reuseIdentifier: \"Cell\"|withIdentifier: \"Cell\"" Demo/Demo/TableViewDemoController.swift
```

Expected: no matches for placeholder row generation or the old `"Cell"` reuse identifier.

- [ ] **Step 2: Check touched files**

Run:

```bash
git diff -- Demo/Demo/TableViewDemoController.swift Demo/DemoUITests/DemoUITests.swift docs/superpowers/specs/2026-07-06-list-refresh-production-ui-dsl.md docs/superpowers/plans/2026-07-06-list-refresh-production-ui.md
```

Expected: diff only contains the planned demo UI, UI tests, and docs.

- [ ] **Step 3: Commit**

```bash
git add Demo/Demo/TableViewDemoController.swift Demo/DemoUITests/DemoUITests.swift docs/superpowers/specs/2026-07-06-list-refresh-production-ui-dsl.md docs/superpowers/plans/2026-07-06-list-refresh-production-ui.md docs/superpowers/specs/assets/list-refresh-selected-update-list.png
git commit -m "docs: plan production list refresh demo"
```

Expected: commit succeeds with only the docs, image assets, and implemented demo changes.

## Plan Self-Review

- Spec coverage: The plan covers selected target image, header, segmented control, realistic rows, top refresh, automatic bottom load-more, no-more-data reset, and UI tests.
- Placeholder scan: No unresolved placeholder markers or unspecified implementation steps remain.
- Type consistency: `UpdateItem`, `ChipStyle`, `UpdateItemCell`, and `UpdateListHeaderView` names are consistent across tasks.
- Scope check: The implementation is limited to the first Demo tab and UI tests; Refreshable public APIs remain unchanged.
