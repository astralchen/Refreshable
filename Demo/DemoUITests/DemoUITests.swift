//
//  DemoUITests.swift
//  DemoUITests
//
//  Created by Sondra on 2026/7/1.
//

import XCTest

final class DemoUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testCustomRefreshStylesTriggerFromDemo() throws {
        let app = XCUIApplication()
        app.launch()

        let stylesTab = app.tabBars.buttons["样式"]
        XCTAssertTrue(stylesTab.waitForExistence(timeout: 5))
        stylesTab.tap()

        try verifyRefresh(styleTitle: "系统", expectedBody: "系统样式刚完成一次真实下拉刷新。", app: app)
        try verifyRefresh(styleTitle: "太极", expectedBody: "太极样式刚完成一次真实下拉刷新。", app: app)
        try verifyRefresh(styleTitle: "动感", expectedBody: "动感样式刚完成一次真实下拉刷新。", app: app)
    }

    @MainActor
    func testDefaultRefreshPreviewShowsAllControls() throws {
        let app = try launchDefaultRefreshPreview()
        let canvas = app.scrollViews["DefaultRefreshPreview.Canvas"]

        XCTAssertTrue(app.navigationBars["默认刷新控件"].waitForExistence(timeout: 3))
        XCTAssertTrue(canvas.exists)
        XCTAssertTrue(app.segmentedControls["DefaultRefreshPreview.EdgeSelector"].exists)
        XCTAssertTrue(app.segmentedControls["DefaultRefreshPreview.RoleSelector"].exists)
        XCTAssertTrue(app.switches["DefaultRefreshPreview.TextSwitch"].exists)
        XCTAssertTrue(app.buttons["DefaultRefreshPreview.Trigger"].exists)
        XCTAssertTrue(app.buttons["DefaultRefreshPreview.NoMoreData"].exists)
        XCTAssertTrue(app.buttons["DefaultRefreshPreview.Reset"].exists)
        XCTAssertTrue(app.staticTexts["DefaultRefreshPreview.Status"].exists)

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(
            waitForCanvasContent(toExceed: canvas, by: 200, timeout: 3),
            "Canvas content should remain scrollable in both axes on a wide viewport"
        )
    }

    @MainActor
    func testDefaultRefreshPreviewPhysicallyRefreshesAtEveryEdge() throws {
        let app = try launchDefaultRefreshPreview(actionDuration: 5)
        let canvas = app.scrollViews["DefaultRefreshPreview.Canvas"]
        let edgeSelector = app.segmentedControls["DefaultRefreshPreview.EdgeSelector"]
        let status = app.staticTexts["DefaultRefreshPreview.Status"]

        let cases: [(title: String, start: CGVector, end: CGVector, edge: CGRectEdge)] = [
            ("上", CGVector(dx: 0.5, dy: 0.20), CGVector(dx: 0.5, dy: 0.95), .minYEdge),
            ("下", CGVector(dx: 0.5, dy: 0.80), CGVector(dx: 0.5, dy: 0.05), .maxYEdge),
            ("左", CGVector(dx: 0.20, dy: 0.5), CGVector(dx: 0.95, dy: 0.5), .minXEdge),
            ("右", CGVector(dx: 0.80, dy: 0.5), CGVector(dx: 0.05, dy: 0.5), .maxXEdge),
        ]

        for testCase in cases {
            edgeSelector.buttons[testCase.title].tap()
            XCTAssertTrue(
                waitForLabel(
                    containing: "\(testCase.title) · 刷新 · 空闲",
                    in: status,
                    timeout: 3
                )
            )

            canvas.coordinate(withNormalizedOffset: testCase.start)
                .press(
                    forDuration: 0.15,
                    thenDragTo: canvas.coordinate(withNormalizedOffset: testCase.end),
                    withVelocity: .slow,
                    thenHoldForDuration: 0.2
                )

            XCTAssertTrue(
                waitForLabel(containing: "刷新中", in: status, timeout: 3),
                "\(testCase.title) edge should reach refreshing"
            )

            let indicator = app.descendants(matching: .any)
                .matching(identifier: "Refreshable.DefaultIndicator")
                .firstMatch
            XCTAssertTrue(indicator.exists)
            XCTAssertEqual(indicator.value as? String, "正在刷新")
            assert(indicator: indicator, isAt: testCase.edge, of: canvas)
            XCTAssertTrue((status.value as? String)?.isEmpty ?? true)
            XCTAssertFalse(app.staticTexts["正在刷新..."].exists)

            XCTAssertTrue(
                waitForLabel(containing: "空闲", in: status, timeout: 7),
                "\(testCase.title) edge should finish normally"
            )
        }
    }

    @MainActor
    func testDefaultRefreshPreviewTextAndNoMoreDataControls() throws {
        let app = try launchDefaultRefreshPreview(actionDuration: 8)
        let canvas = app.scrollViews["DefaultRefreshPreview.Canvas"]
        let status = app.staticTexts["DefaultRefreshPreview.Status"]

        app.switches["DefaultRefreshPreview.TextSwitch"].tap()
        app.buttons["DefaultRefreshPreview.Trigger"].tap()

        XCTAssertTrue(waitForLabel(containing: "刷新中", in: status, timeout: 3))
        let indicator = app.descendants(matching: .any)
            .matching(identifier: "Refreshable.DefaultIndicator")
            .firstMatch
        XCTAssertTrue(indicator.exists)
        XCTAssertEqual(indicator.value as? String, "正在刷新")
        XCTAssertEqual(status.value as? String, "正在刷新...")
        addPreviewScreenshot(named: "默认刷新控件-显示刷新文案", app: app)
        XCTAssertTrue(waitForLabel(containing: "空闲", in: status, timeout: 10))

        app.segmentedControls["DefaultRefreshPreview.RoleSelector"].buttons["加载更多"].tap()
        app.buttons["DefaultRefreshPreview.NoMoreData"].tap()

        XCTAssertEqual(indicator.value as? String, "没有更多数据")
        XCTAssertTrue(
            waitForIntersection(of: indicator, with: canvas, timeout: 3),
            "No-more-data indicator should be visible inside the canvas"
        )
        assert(indicator: indicator, isAt: .minYEdge, of: canvas)
        XCTAssertEqual(status.value as? String, "没有更多数据")
        addPreviewScreenshot(named: "默认刷新控件-没有更多数据", app: app)
        app.buttons["DefaultRefreshPreview.Reset"].tap()
        XCTAssertFalse(indicator.waitForExistence(timeout: 1))
    }

    @MainActor
    func testListRefreshProductionScreenLoads() throws {
        let app = XCUIApplication()
        app.launch()

        let listTab = app.tabBars.buttons["列表刷新"]
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

    @MainActor
    func testListRefreshInsertsFreshRow() throws {
        let app = XCUIApplication()
        app.launch()

        let listTab = app.tabBars.buttons["列表刷新"]
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

    @MainActor
    func testListRefreshSegmentSwitchFiltersRows() throws {
        let app = XCUIApplication()
        app.launch()

        let listTab = app.tabBars.buttons["列表刷新"]
        XCTAssertTrue(listTab.waitForExistence(timeout: 5))
        listTab.tap()

        XCTAssertTrue(app.staticTexts["版本 2.1.0 发布"].waitForExistence(timeout: 3))

        app.buttons["关注"].tap()
        XCTAssertTrue(app.staticTexts["关注：技术分享精选"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["系统通知"].exists)
        XCTAssertFalse(app.staticTexts["版本 2.1.0 发布"].exists)

        app.buttons["系统"].tap()
        XCTAssertTrue(app.staticTexts["系统通知"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["关注：技术分享精选"].exists)

        app.buttons["全部"].tap()
        XCTAssertTrue(app.staticTexts["版本 2.1.0 发布"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["关注：技术分享精选"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["系统通知"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testGridRefreshStateFooterScreenLoads() throws {
        let app = XCUIApplication()
        app.launch()

        let gridTab = app.tabBars.buttons["网格"]
        XCTAssertTrue(gridTab.waitForExistence(timeout: 5))
        gridTab.tap()

        XCTAssertTrue(app.navigationBars["刷新网格"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["最近更新"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["已加载 36 项"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["刚刚同步"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["全部"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["加载中"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["完成"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["下拉刷新 · 自动收起"].exists)
        XCTAssertTrue(app.staticTexts["版本 2.1.0 发布"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["接口文档更新"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testGridRefreshDoesNotShowNumberedPagination() throws {
        let app = XCUIApplication()
        app.launch()

        let gridTab = app.tabBars.buttons["网格"]
        XCTAssertTrue(gridTab.waitForExistence(timeout: 5))
        gridTab.tap()

        XCTAssertTrue(app.navigationBars["刷新网格"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["1"].exists)
        XCTAssertFalse(app.buttons["2"].exists)
        XCTAssertFalse(app.buttons["3"].exists)
        XCTAssertFalse(app.staticTexts["..."].exists)
        XCTAssertFalse(app.staticTexts["…"].exists)
    }

    @MainActor
    func testGridRefreshFiltersItems() throws {
        let app = XCUIApplication()
        app.launch()

        let gridTab = app.tabBars.buttons["网格"]
        XCTAssertTrue(gridTab.waitForExistence(timeout: 5))
        gridTab.tap()

        XCTAssertTrue(app.staticTexts["版本 2.1.0 发布"].waitForExistence(timeout: 3))

        app.buttons["加载中"].tap()
        XCTAssertTrue(app.staticTexts["接口文档更新"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["性能优化"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["构建任务完成"].exists)

        app.buttons["完成"].tap()
        XCTAssertTrue(app.staticTexts["构建任务完成"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["问题修复"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["接口文档更新"].exists)

        app.buttons["全部"].tap()
        XCTAssertTrue(app.staticTexts["版本 2.1.0 发布"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["系统通知"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testGridRefreshCellsUseStableTwoColumnRows() throws {
        let app = XCUIApplication()
        app.launch()

        let gridTab = app.tabBars.buttons["网格"]
        XCTAssertTrue(gridTab.waitForExistence(timeout: 5))
        gridTab.tap()

        let collectionView = app.collectionViews.firstMatch
        XCTAssertTrue(collectionView.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["版本 2.1.0 发布"].waitForExistence(timeout: 3))

        let firstCell = collectionView.cells.element(boundBy: 0)
        let secondCell = collectionView.cells.element(boundBy: 1)
        let thirdCell = collectionView.cells.element(boundBy: 2)
        let fourthCell = collectionView.cells.element(boundBy: 3)
        XCTAssertTrue(firstCell.waitForExistence(timeout: 3))
        XCTAssertTrue(secondCell.waitForExistence(timeout: 3))
        XCTAssertTrue(thirdCell.waitForExistence(timeout: 3))
        XCTAssertTrue(fourthCell.waitForExistence(timeout: 3))

        XCTAssertEqual(firstCell.frame.minY, secondCell.frame.minY, accuracy: 2)
        XCTAssertEqual(firstCell.frame.height, secondCell.frame.height, accuracy: 2)
        XCTAssertEqual(thirdCell.frame.minY, fourthCell.frame.minY, accuracy: 2)
        XCTAssertEqual(thirdCell.frame.height, fourthCell.frame.height, accuracy: 2)
    }

    @MainActor
    func testGridRefreshDoesNotInsertStatusCard() throws {
        let app = XCUIApplication()
        app.launch()

        let gridTab = app.tabBars.buttons["网格"]
        XCTAssertTrue(gridTab.waitForExistence(timeout: 5))
        gridTab.tap()

        let collectionView = app.collectionViews.firstMatch
        XCTAssertTrue(collectionView.waitForExistence(timeout: 3))

        let start = collectionView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.18))
        let end = collectionView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.74))
        start.press(forDuration: 0.08, thenDragTo: end)

        XCTAssertFalse(app.staticTexts["刚刚刷新完成"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["版本 2.1.0 发布"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testGridRefreshShowsNoMoreDataFooter() throws {
        let app = XCUIApplication()
        app.launch()

        let gridTab = app.tabBars.buttons["网格"]
        XCTAssertTrue(gridTab.waitForExistence(timeout: 5))
        gridTab.tap()

        let collectionView = app.collectionViews.firstMatch
        XCTAssertTrue(collectionView.waitForExistence(timeout: 3))

        for _ in 0..<8 {
            collectionView.swipeUp()
        }

        XCTAssertTrue(app.staticTexts["没有更多数据"].waitForExistence(timeout: 4))
        let title = app.staticTexts["没有更多数据"]
        let message = app.staticTexts["下拉刷新后重新加载"]
        let count = app.staticTexts["36 项已加载"]
        XCTAssertTrue(message.exists)
        XCTAssertTrue(count.exists)
        let footer = app.otherElements["GridNoMoreDataFooter"]
        XCTAssertTrue(footer.exists)
        XCTAssertFalse(collectionView.cells.containing(.staticText, identifier: "没有更多数据").firstMatch.exists)
        XCTAssertGreaterThan(footer.frame.width, footer.frame.height)
        XCTAssertLessThan(title.frame.maxY, message.frame.minY)
        XCTAssertLessThanOrEqual(message.frame.maxY + 8, count.frame.minY)
        XCTAssertGreaterThan(footer.frame.height, 108)
        let noMoreDataTexts = app.staticTexts.matching(NSPredicate(format: "label == %@", "没有更多数据"))
        XCTAssertEqual(noMoreDataTexts.count, 1)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    private func launchDefaultRefreshPreview(actionDuration: TimeInterval = 3) throws -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["DefaultRefreshPreview.UITestActionDuration"] = String(actionDuration)
        app.launch()
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(
            waitForPortraitLayout(in: app, timeout: 5),
            "Preview tests require a settled portrait app window"
        )

        let stylesTab = app.tabBars.buttons["样式"]
        XCTAssertTrue(stylesTab.waitForExistence(timeout: 5))
        stylesTab.tap()

        let entry = app.buttons["DefaultRefreshPreview.Entry"]
        XCTAssertTrue(entry.waitForExistence(timeout: 3))
        entry.tap()
        return app
    }

    @MainActor
    private func waitForPortraitLayout(
        in app: XCUIApplication,
        timeout: TimeInterval
    ) -> Bool {
        let window = app.windows.firstMatch
        let predicate = NSPredicate { _, _ in
            window.exists && window.frame.height > window.frame.width
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: window)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    private func waitForLabel(
        containing text: String,
        in element: XCUIElement,
        timeout: TimeInterval
    ) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    private func waitForIntersection(
        of element: XCUIElement,
        with viewport: XCUIElement,
        timeout: TimeInterval
    ) -> Bool {
        let predicate = NSPredicate { _, _ in
            element.exists && element.frame.intersects(viewport.frame)
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    private func waitForCanvasContent(
        toExceed canvas: XCUIElement,
        by minimumOverflow: CGFloat,
        timeout: TimeInterval
    ) -> Bool {
        let predicate = NSPredicate { _, _ in
            guard let contentSize = self.reportedContentSize(for: canvas) else {
                return false
            }
            return contentSize.width >= canvas.frame.width + minimumOverflow
                && contentSize.height >= canvas.frame.height + minimumOverflow
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: canvas)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    private func reportedContentSize(for canvas: XCUIElement) -> CGSize? {
        guard let value = canvas.value as? String else { return nil }
        let fields = value.split(separator: ";").reduce(into: [Substring: Substring]()) {
            let pair = $1.split(separator: "=", maxSplits: 1)
            guard pair.count == 2 else { return }
            $0[pair[0]] = pair[1]
        }
        guard let widthText = fields["contentWidth"],
              let heightText = fields["contentHeight"],
              let width = Double(widthText),
              let height = Double(heightText) else {
            return nil
        }
        return CGSize(width: width, height: height)
    }

    @MainActor
    private func addPreviewScreenshot(named name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func assert(
        indicator: XCUIElement,
        isAt edge: CGRectEdge,
        of canvas: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let indicatorFrame = indicator.frame
        let canvasFrame = canvas.frame

        switch edge {
        case .minXEdge:
            XCTAssertLessThan(indicatorFrame.midX, canvasFrame.minX + canvasFrame.width * 0.35, file: file, line: line)
        case .maxXEdge:
            XCTAssertGreaterThan(indicatorFrame.midX, canvasFrame.maxX - canvasFrame.width * 0.35, file: file, line: line)
        case .minYEdge:
            XCTAssertLessThan(indicatorFrame.midY, canvasFrame.minY + canvasFrame.height * 0.35, file: file, line: line)
        case .maxYEdge:
            XCTAssertGreaterThan(indicatorFrame.midY, canvasFrame.maxY - canvasFrame.height * 0.35, file: file, line: line)
        @unknown default:
            XCTFail("Unsupported canvas edge", file: file, line: line)
        }
    }

    @MainActor
    private func verifyRefresh(styleTitle: String, expectedBody: String, app: XCUIApplication) throws {
        let styleButton = app.buttons[styleTitle]
        XCTAssertTrue(styleButton.waitForExistence(timeout: 3), "\(styleTitle) segment should exist")
        styleButton.tap()

        let table = app.tables.firstMatch
        XCTAssertTrue(table.waitForExistence(timeout: 3), "feed table should exist")

        let start = table.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.18))
        let end = table.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.76))
        start.press(forDuration: 0.08, thenDragTo: end)

        let refreshResult = app.staticTexts[expectedBody]
        XCTAssertTrue(refreshResult.waitForExistence(timeout: 4), "\(styleTitle) refresh should insert a matching row")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "\(styleTitle)刷新样式"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
