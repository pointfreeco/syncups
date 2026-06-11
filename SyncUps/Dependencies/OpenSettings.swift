import Dependencies
import DependenciesMacros
import UIKit

nonisolated protocol OpenSettings: Sendable {
  func callAsFunction() async
}

extension DependencyValues {
  @DependencyEntry(liveValue: LiveOpenSettings())
  nonisolated var openSettings: any OpenSettings = TestOpenSettings()
}

private struct LiveOpenSettings: OpenSettings {
  @MainActor
  func callAsFunction() {
    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
  }
}

private struct TestOpenSettings: OpenSettings {
  func callAsFunction() async {
    reportIssue("OpenSettings() unimplemented")
  }
}

actor MockOpenSettings: OpenSettings {
  var openCount = 0
  func callAsFunction() async {
    openCount += 1
  }
  var hasOpened: Bool { openCount > 0 }
}
