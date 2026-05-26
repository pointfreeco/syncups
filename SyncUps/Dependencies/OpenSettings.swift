import Dependencies
import UIKit

nonisolated protocol OpenSettings: Sendable {
  func callAsFunction() async
}

extension DependencyValues {
  nonisolated var openSettings: any OpenSettings {
    get { self[OpenSettingsKey.self] }
    set { self[OpenSettingsKey.self] = newValue }
  }
}

nonisolated private enum OpenSettingsKey: DependencyKey {
  static var liveValue: any OpenSettings {
    LiveOpenSettings()
  }
  static var testValue: any OpenSettings {
    UnimplementedOpenSettings()
  }
}

private struct LiveOpenSettings: OpenSettings {
  @MainActor
  func callAsFunction() {
    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
  }
}

private struct UnimplementedOpenSettings: OpenSettings {
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
