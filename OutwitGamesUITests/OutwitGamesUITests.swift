import XCTest

final class OutwitGamesUITests: XCTestCase {
  @MainActor
  func testAppLaunchesIntoRootView() {
    let app = XCUIApplication()
    app.launch()

    XCTAssertTrue(app.staticTexts["app-title"].waitForExistence(timeout: 5))
  }
}
