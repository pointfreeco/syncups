import Dependencies
import SwiftUI

@main
struct StandupsApp: App {
  var body: some Scene {
    WindowGroup {
      // NB: This conditional is here only to facilitate UI testing so that we can mock out certain
      //     dependencies for the duration of the test (e.g. the data manager). We do not really
      //     recommend performing UI tests in general, but we do want to demonstrate how it can be
      //     done.
      if let testName = ProcessInfo.processInfo.environment["UITest"] {
        UITestingView(testName: testName)
      } else {
        StandupsList(model: StandupsListModel())
      }
    }
  }
}

struct UITestingView: View {
  let testName: String

  var body: some View {
    withDependencies {
      switch testName {
      case "testAdd":
        $0.dataManager = .mock()
      case "testDelete", "testEdit":
        $0.dataManager = .mock(initialData: try? JSONEncoder().encode([Standup.mock]))
      default:
        fatalError()
      }
    } operation: {
      StandupsList(model: StandupsListModel())
    }
  }
}
