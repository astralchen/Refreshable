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
