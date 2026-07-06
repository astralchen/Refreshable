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
