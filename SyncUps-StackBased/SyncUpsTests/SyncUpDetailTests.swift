import CasePaths
import CustomDump
import Dependencies
import XCTest

@testable import SyncUps_StackBased

@MainActor
final class SyncUpDetailTests: BaseTestCase {
  func testSpeechRestricted() throws {
    let model = withDependencies {
      $0.speechClient.authorizationStatus = { .restricted }
    } operation: {
      SyncUpDetailModel(syncUp: .mock)
    }

    model.startMeetingButtonTapped()

    let alert = try XCTUnwrap(model.destination?.alert)

    XCTAssertNoDifference(alert, .speechRecognitionRestricted)
  }

  func testSpeechDenied() async throws {
    let model = withDependencies {
      $0.speechClient.authorizationStatus = { .denied }
    } operation: {
      SyncUpDetailModel(syncUp: .mock)
    }

    model.startMeetingButtonTapped()

    let alert = try XCTUnwrap(model.destination?.alert)

    XCTAssertNoDifference(alert, .speechRecognitionDenied)
  }

  func testOpenSettings() async {
    let settingsOpened = LockIsolated(false)
    let model = withDependencies {
      $0.openSettings = { settingsOpened.setValue(true) }
    } operation: {
      SyncUpDetailModel(
        destination: .alert(.speechRecognitionDenied),
        syncUp: .mock
      )
    }

    await model.alertButtonTapped(.openSettings)

    XCTAssertEqual(settingsOpened.value, true)
  }

  func testContinueWithoutRecording() async throws {
    let model = SyncUpDetailModel(
      destination: .alert(.speechRecognitionDenied),
      syncUp: .mock
    )

    model.$onMeetingStarted { syncUp in
      XCTAssertEqual(syncUp, .mock)
    }

    await model.alertButtonTapped(.continueWithoutRecording)
  }

  func testSpeechAuthorized() async throws {
    let model = withDependencies {
      $0.speechClient.authorizationStatus = { .authorized }
    } operation: {
      SyncUpDetailModel(syncUp: .mock)
    }

    model.$onMeetingStarted { syncUp in
      XCTAssertEqual(syncUp, .mock)
    }

    model.startMeetingButtonTapped()
  }

  func testEdit() throws {
    let model = withDependencies {
      $0.uuid = .incrementing
    } operation: {
      @Dependency(\.uuid) var uuid

      return SyncUpDetailModel(
        syncUp: SyncUp(
          id: SyncUp.ID(uuid()),
          title: "Engineering"
        )
      )
    }

    model.editButtonTapped()

    let editModel = try XCTUnwrap(model.destination?.edit)

    editModel.syncUp.title = "Engineering"
    editModel.syncUp.theme = .lavender
    model.doneEditingButtonTapped()

    XCTAssertNil(model.destination)
    XCTAssertEqual(
      model.syncUp,
      SyncUp(
        id: SyncUp.ID(uuidString: "00000000-0000-0000-0000-000000000000")!,
        attendees: [
          Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000001")!)
        ],
        theme: .lavender,
        title: "Engineering"
      )
    )
  }
}
