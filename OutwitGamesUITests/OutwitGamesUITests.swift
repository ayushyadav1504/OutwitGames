import XCTest

final class OutwitGamesUITests: XCTestCase {
  @MainActor
  func testAppLaunchesIntoRootView() {
    let app = XCUIApplication()
    app.launchArguments += ["-app.language", "not-configured"]
    app.launch()

    XCTAssertTrue(app.staticTexts["language-title"].waitForExistence(timeout: 5))
  }
}
