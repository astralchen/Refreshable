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
        app.launchArguments = ["-taiji-ui-screenshots", "-taiji-pulling-snapshot"]
        app.launch()

        let pullingTable = app.tables["taiji.tableView"]
        XCTAssertTrue(pullingTable.waitForExistence(timeout: 5))
        waitForAnimations()
        attachScreenshot(named: "02-taiji-nebula-pulling")

        app.terminate()

        app = XCUIApplication()
        app.launchArguments = ["-taiji-ui-screenshots", "-taiji-auto-refresh"]
        app.launch()

        let refreshedTable = app.tables["taiji.tableView"]
        XCTAssertTrue(refreshedTable.waitForExistence(timeout: 5))
        waitForAnimations()
        attachScreenshot(named: "03-taiji-nebula-refreshing")

        app.terminate()

        app = XCUIApplication()
        app.launchArguments = ["-taiji-ui-screenshots", "-taiji-dark-screenshots", "-taiji-auto-refresh"]
        app.launch()

        let darkRefreshedTable = app.tables["taiji.tableView"]
        XCTAssertTrue(darkRefreshedTable.waitForExistence(timeout: 5))
        waitForAnimations()
        attachScreenshot(named: "04-taiji-dark-refreshing-after-release")

        app.terminate()

        app = XCUIApplication()
        app.launchArguments = ["-taiji-ui-screenshots", "-taiji-ending-snapshot"]
        app.launch()

        let endingTable = app.tables["taiji.tableView"]
        XCTAssertTrue(endingTable.waitForExistence(timeout: 5))
        waitForAnimations()
        attachScreenshot(named: "05-taiji-nebula-ending-after-release")
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
