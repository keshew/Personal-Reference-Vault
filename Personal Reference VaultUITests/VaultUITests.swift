import XCTest

final class VaultUITests: XCTestCase {
    @MainActor func testOnboardingCreateSearchAndEdit() throws {
        let app = XCUIApplication()
        app.launch()
        if app.buttons["Continue"].waitForExistence(timeout: 5) {
            for _ in 0..<3 { app.buttons["Continue"].tap() }
            app.buttons["Get Started"].tap()
        }
        XCTAssertTrue(app.buttons["addReference"].waitForExistence(timeout: 5))
        app.buttons["addReference"].tap()
        let title = app.textFields["referenceTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap(); title.typeText("QA Kitchen Filter")
        let value = app.textFields["referenceValue"]; value.tap(); value.typeText("DA29-00020B")
        app.buttons["saveReference"].tap()
        XCTAssertTrue(app.staticTexts["QA Kitchen Filter"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Search"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("DA29-00020B")
        app.staticTexts["QA Kitchen Filter"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Edit"].waitForExistence(timeout: 5))
        app.buttons["Edit"].tap()
        let editedTitle = app.textFields["referenceTitle"]; XCTAssertTrue(editedTitle.waitForExistence(timeout: 5)); editedTitle.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5)).tap(); editedTitle.typeText("Updated ")
        app.buttons["saveReference"].tap()
        XCTAssertTrue(app.staticTexts["Updated QA Kitchen Filter"].waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "Reference detail - iPhone SE"; attachment.lifetime = .keepAlways; add(attachment)
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["Updated QA Kitchen Filter"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Settings"].tap()
        app.buttons["Appearance"].tap()
        app.buttons["Dark"].tap()
        let dark = XCTAttachment(screenshot: app.screenshot()); dark.name = "Dark appearance - iPhone SE"; dark.lifetime = .keepAlways; add(dark)
    }
}
