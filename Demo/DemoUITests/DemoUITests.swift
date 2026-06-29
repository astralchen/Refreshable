import XCTest

@MainActor
final class DemoUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testTaijiRefreshScreenshots() throws {
        app.launchArguments = ["-taiji-ui-screenshots"]
        app.launch()

        let table = app.tables["taiji.tableView"]
        XCTAssertTrue(table.waitForExistence(timeout: 5))
        attachScreenshot(named: "01-taiji-nebula-idle")

        app.terminate()

        app = XCUIApplication()
        app.launchArguments = ["-taiji-ui-screenshots", "-taiji-auto-refresh"]
        app.launch()

        let refreshedTable = app.tables["taiji.tableView"]
        XCTAssertTrue(refreshedTable.waitForExistence(timeout: 5))
        waitForAnimations()
        attachScreenshot(named: "02-taiji-nebula-refreshing")
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func waitForAnimations() {
        let expectation = XCTestExpectation(description: "Wait for refresh animation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.8)
    }
}
