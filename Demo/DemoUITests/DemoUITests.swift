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

        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.28))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.56))
        start.press(forDuration: 0.08, thenDragTo: end)

        let refreshResult = app.staticTexts[expectedBody]
        XCTAssertTrue(refreshResult.waitForExistence(timeout: 4), "\(styleTitle) refresh should insert a matching row")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "\(styleTitle)刷新样式"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
