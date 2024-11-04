import XCTest

// This test case demonstrates how one can write UI tests using the swift-dependencies library. We
// do not really recommend writing UI tests in general as they are slow and flakey, but if you must
// then this shows how.
//
// The key to doing this is to set a launch environment variable on your XCUIApplication instance,
// and then check for that value in the entry point of the application. If the environment value
// exists, you can use 'withDependencies' to override dependencies to be used in the UI test.
final class SyncUpsListUITests: XCTestCase {
  var app: XCUIApplication!

  override func setUpWithError() throws {
    nonisolated(unsafe) let test = self
    MainActor.assumeIsolated {
      test.app = XCUIApplication()
      test.app.launchEnvironment["SWIFT_DEPENDENCIES_CONTEXT"] = "test"
      test.app.launchEnvironment["UI_TEST_NAME"] = String(
        test.name.split(separator: " ").last?.dropLast() ?? ""
      )
      test.app.launchEnvironment["TEST_UUID"] = UUID().uuidString
      test.app.launch()
    }
  }

  // This test demonstrates the simple flow of tapping the "Add" button, filling in some fields in
  // the form, and then adding the sync-up to the list. It's a very simple test, but it takes
  // approximately 10 seconds to run, and it depends on a lot of internal implementation details to
  // get right, such as tapping a button with the literal label "Add".
  //
  // This test is also written in the simpler, "unit test" style in SyncUpsListTests.swift, where
  // it takes 0.025 seconds (400 times faster) and it even tests more. It further confirms that when
  // the sync-up is added to the list its data will be persisted to disk so that it will be
  // available on next launch.
  @MainActor
  func testAdd() throws {
    self.app.navigationBars["Daily Sync-ups"].buttons["Add"].tap()
    let titleTextField = self.app.collectionViews.textFields["Title"]
    let nameTextField = self.app.collectionViews.textFields["Name"]

    titleTextField.typeText("Engineering")

    nameTextField.tap()
    nameTextField.typeText("Blob")

    self.app.buttons["New attendee"].tap()
    self.app.typeText("Blob Jr.")

    self.app.navigationBars["New sync-up"].buttons["Add"].tap()

    XCTAssertEqual(self.app.staticTexts["Engineering"].exists, true)
  }

  @MainActor
  func testDelete() async throws {
    self.app.staticTexts["Design"].tap()

    self.app.buttons["Delete"].tap()
    XCTAssertEqual(self.app.staticTexts["Delete?"].exists, true)

    self.app.buttons["Yes"].tap()
    try await Task.sleep(for: .seconds(0.5))
    XCTAssertEqual(self.app.staticTexts["Design"].exists, false)
    XCTAssertEqual(self.app.staticTexts["Daily Sync-ups"].exists, true)
  }

  @MainActor
  func testEdit() async throws {
    self.app.staticTexts["Design"].tap()

    self.app.buttons["Edit"].tap()
    let titleTextField = self.app.textFields["Title"]
    titleTextField.typeText(" & Product")

    self.app.buttons["Done"].tap()
    XCTAssertEqual(self.app.staticTexts["Design & Product"].exists, true)

    self.app.buttons["Daily Sync-ups"].tap()
    try await Task.sleep(for: .seconds(0.3))
    XCTAssertEqual(self.app.staticTexts["Design & Product"].exists, true)
    XCTAssertEqual(self.app.staticTexts["Daily Sync-ups"].exists, true)
  }

  @MainActor
  func testRecord() async throws {
    self.app.staticTexts["Design"].tap()

    self.app.buttons["Start Meeting"].tap()
    self.app.buttons["End meeting"].tap()

    XCTAssertEqual(self.app.staticTexts["End meeting?"].exists, true)
    self.app.buttons["Save and end"].tap()

    try await Task.sleep(for: .seconds(0.5))
    XCTAssertEqual(self.app.staticTexts["Design"].exists, true)
    XCTAssertEqual(self.app.staticTexts["February 13, 2009"].exists, true)

    self.app.buttons["Daily Sync-ups"].tap()
    self.app.staticTexts["Design"].tap()

    XCTAssertEqual(self.app.staticTexts["Design"].exists, true)
    XCTAssertEqual(self.app.staticTexts["February 13, 2009"].exists, true)

    self.app.staticTexts["February 13, 2009"].tap()
    self.app.staticTexts["Hello world!"].tap()
  }

  @MainActor
  func testRecord_Discard() async throws {
    self.app.staticTexts["Design"].tap()

    self.app.buttons["Start Meeting"].tap()
    self.app.buttons["End meeting"].tap()

    XCTAssertEqual(self.app.staticTexts["End meeting?"].exists, true)
    self.app.buttons["Discard"].tap()

    try await Task.sleep(for: .seconds(0.5))
    XCTAssertEqual(self.app.staticTexts["Design"].exists, true)
    XCTAssertEqual(self.app.staticTexts["February 13, 2009"].exists, false)
  }
}
