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

  @MainActor
  func testPhoneLoginAdvancesThroughOTPToFeed() {
    let app = XCUIApplication()
    app.launchArguments += [
      "-ui-testing-login",
      "-AppleLanguages", "(en)",
    ]
    app.launch()

    let phoneField = app.textFields["login-phone-field"]
    XCTAssertTrue(phoneField.waitForExistence(timeout: 5))
    phoneField.tap()
    phoneField.typeText("9876543210")

    let primaryAction = app.buttons["login-primary-action"]
    primaryAction.tap()

    let otpField = app.textFields["login-otp-field"]
    XCTAssertTrue(otpField.waitForExistence(timeout: 2))
    otpField.tap()
    otpField.typeText("2468")

    XCTAssertTrue(app.otherElements["feed-card-101"].waitForExistence(timeout: 5))
  }

  @MainActor
  func testFeedPagesAndOpensChallengePlaceholder() {
    let app = XCUIApplication()
    app.launchArguments += [
      "-ui-testing-feed",
      "-AppleLanguages", "(en)",
    ]
    app.launch()

    let firstCard = app.otherElements["feed-card-101"]
    XCTAssertTrue(firstCard.waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["feed-coin-balance"].exists)

    firstCard.swipeUp()
    let secondCard = app.otherElements["feed-card-102"]
    XCTAssertTrue(secondCard.waitForExistence(timeout: 3))

    let startButton = secondCard.buttons["feed-start-challenge"]
    startButton.tap()

    let pendingFeature = app.descendants(matching: .any)["pending-feature"]
    if !pendingFeature.waitForExistence(timeout: 2) {
      startButton.tap()
    }
    XCTAssertTrue(pendingFeature.waitForExistence(timeout: 3))
  }
}
