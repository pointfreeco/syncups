import Dependencies
import IdentifiedCollections
import Sharing
import SwiftUI

@main
struct SyncUpsApp: App {
  static let model = AppModel(syncUpsList: SyncUpsListModel())

  var body: some Scene {
    WindowGroup {
      // NB: This conditional is here only to facilitate UI testing so that we can mock out certain
      //     dependencies for the duration of the test (e.g. the data manager). We do not really
      //     recommend performing UI tests in general, but we do want to demonstrate how it can be
      //     done.
      if let testName = ProcessInfo.processInfo.environment["UI_TEST_NAME"] {
        UITestingView(testName: testName)
      } else {
        AppView(model: Self.model)
      }
    }
  }
}

struct UITestingView: View {
  let testName: String

  var body: some View {
    withDependencies {
      $0.continuousClock = ContinuousClock()
      $0.date = DateGenerator { Date() }
      $0.soundEffectClient = .noop
      $0.uuid = UUIDGenerator { UUID() }
      $0.defaultFileStorage = .inMemory
      switch testName {
      case "testAdd", "testDelete", "testEdit":
        break
      case "testRecord", "testRecord_Discard":
        $0.date = DateGenerator { Date(timeIntervalSince1970: 1_234_567_890) }
        $0.speechClient.authorizationStatus = { .authorized }
        $0.speechClient.startTask = { @Sendable _ in
          AsyncThrowingStream {
            $0.yield(
              SpeechRecognitionResult(
                bestTranscription: Transcription(formattedString: "Hello world!"),
                isFinal: true
              )
            )
            $0.finish()
          }
        }
      default:
        fatalError()
      }
    } operation: {
      switch testName {
      case "testDelete", "testEdit", "testRecord", "testRecord_Discard":
        @Shared(.syncUps) var syncUps: IdentifiedArray = [SyncUp.mock]
      default:
        break
      }
      return AppView(model: AppModel(syncUpsList: SyncUpsListModel()))
    }
  }
}
