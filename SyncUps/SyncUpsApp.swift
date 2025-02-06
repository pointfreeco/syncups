import Dependencies
import IdentifiedCollections
import Sharing
import SwiftUI

@main
struct SyncUpsApp: App {
  static let model = AppModel()

  init() {
    setUpForUITest()
  }

  var body: some Scene {
    WindowGroup {
      AppView(model: Self.model)
    }
  }
}

//// NB: During UI tests we override certain dependencies for the app and seed initial state.
private func setUpForUITest() {
  guard let testName = ProcessInfo.processInfo.environment["UI_TEST_NAME"]
  else {
    return
  }

  // Set up dependencies for UI testing.
  prepareDependencies {
    $0.continuousClock = ContinuousClock()
    $0.defaultFileStorage = .inMemory
    $0.soundEffectClient = .noop
    $0.uuid = UUIDGenerator { UUID() }
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
      reportIssue("Unrecognized test: \(testName)")
    }
  }

  // Seed certain test cases with specific state.
  switch testName {
  case "testDelete", "testEdit", "testRecord", "testRecord_Discard":
    @Shared(.syncUps) var syncUps = [.mock]
  default:
    break
  }
}
