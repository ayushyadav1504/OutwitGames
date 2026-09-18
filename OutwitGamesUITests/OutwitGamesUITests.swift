import XCTest

final class OutwitGamesUITests: XCTestCase {
  @MainActor
  func testAppLaunchesIntoRootView() {
    let app = XCUIApplication()
    app.launchArguments += [
      "-ui-testing",
      "-app.language", "not-configured",
      "-onboarding.complete", "NO",
    ]
    app.launch()

    XCTAssertTrue(app.staticTexts["language-title"].waitForExistence(timeout: 5))
  }

  @MainActor
  func testTutorialAdvancesThroughAllPages() {
    let app = XCUIApplication()
    app.launchArguments += [
      "-ui-testing",
      "-app.language", "en",
      "-onboarding.introduction_seen", "NO",
      "-onboarding.complete", "NO",
    ]
    app.launch()

    let continueButton = app.buttons["onboarding-continue"]
    XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
    XCTAssertTrue(app.otherElements["tutorial-page-0"].exists)

    continueButton.tap()
    XCTAssertTrue(app.otherElements["tutorial-page-1"].waitForExistence(timeout: 2))

    continueButton.tap()
    XCTAssertTrue(app.otherElements["tutorial-page-2"].waitForExistence(timeout: 2))

    continueButton.tap()
    XCTAssertTrue(app.buttons["notifications-turn-on"].waitForExistence(timeout: 2))
  }
}
