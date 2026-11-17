import XCTest

final class TideLabUITests: XCTestCase {
    @MainActor func testPlayAndLogTabsShowOnlyGames() {
        let app = XCUIApplication()
        app.launch()

        let play = app.buttons["tide.tab.Play"]
        let log = app.buttons["tide.tab.Log"]
        XCTAssertTrue(play.waitForExistence(timeout: 8))
        XCTAssertTrue(log.exists)
        XCTAssertFalse(app.buttons["tide.tab.Vault"].exists)
        XCTAssertFalse(app.buttons["addReference"].exists)

        let recentRounds = app.staticTexts["Recent rounds"]
        // Permission alerts on a clean install can interrupt the first tap.
        for _ in 0..<3 where !recentRounds.exists {
            log.tap()
            if recentRounds.waitForExistence(timeout: 3) { break }
        }
        XCTAssertTrue(recentRounds.exists)
        play.tap()

        let game = app.buttons["tide.game.four"]
        XCTAssertTrue(game.waitForExistence(timeout: 5))
        game.tap()
        app.buttons["tide.start"].tap()
        let empty = app.buttons["Row 6, column 4, empty"]
        XCTAssertTrue(empty.waitForExistence(timeout: 5))
        empty.tap()
        XCTAssertTrue(app.buttons["Row 6, column 4, your disc"].waitForExistence(timeout: 5))
    }
}
