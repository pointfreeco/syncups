import CasePaths
import CustomDump
import Dependencies
import DependenciesTestSupport
import Sharing
import Testing

@testable import SyncUps

@MainActor
@Suite
struct SyncUpDetailTests {
  @Test func speechRestricted() async throws {
    let model = withDependencies {
      $0.speechClient.authorizationStatus = { .restricted }
    } operation: {
      SyncUpDetailModel(syncUp: Shared(value: .mock))
    }

    model.startMeetingButtonTapped()

    let alert = try #require(model.destination?.alert)

    expectNoDifference(alert, .speechRecognitionRestricted)
  }

  @Test func speechDenied() async throws {
    let model = withDependencies {
      $0.speechClient.authorizationStatus = { .denied }
    } operation: {
      SyncUpDetailModel(syncUp: Shared(value: .mock))
    }

    model.startMeetingButtonTapped()

    let alert = try #require(model.destination?.alert)

    expectNoDifference(alert, .speechRecognitionDenied)
  }

  @Test func openSettings() async {
    let settingsOpened = LockIsolated(false)
    let model = withDependencies {
      $0.openSettings = { settingsOpened.setValue(true) }
    } operation: {
      SyncUpDetailModel(
        destination: .alert(.speechRecognitionDenied),
        syncUp: Shared(value: .mock)
      )
    }

    await model.alertButtonTapped(.openSettings)

    #expect(settingsOpened.value == true)
  }

  @Test func continueWithoutRecording() async throws {
    let syncUp = SyncUp.mock

    let model = SyncUpDetailModel(
      destination: .alert(.speechRecognitionDenied),
      syncUp: Shared(value: syncUp)
    )
    let meetingStarted = LockIsolated(false)
    model.onMeetingStarted = { _ in
      meetingStarted.setValue(true)
    }

    await model.alertButtonTapped(.continueWithoutRecording)

    #expect(meetingStarted.value)
  }

  @Test func speechAuthorized() async throws {
    let syncUp = SyncUp.mock

    let model = withDependencies {
      $0.speechClient.authorizationStatus = { .authorized }
    } operation: {
      SyncUpDetailModel(syncUp: Shared(value: syncUp))
    }
    let meetingStarted = LockIsolated(false)
    model.onMeetingStarted = { _ in
      meetingStarted.setValue(true)
    }

    model.startMeetingButtonTapped()

    #expect(meetingStarted.value)
  }

  @Test(.dependency(\.uuid, .incrementing))
  func edit() async throws {
    @Dependency(\.uuid) var uuid
    let model = SyncUpDetailModel(
      syncUp: Shared(
        value: SyncUp(
          id: SyncUp.ID(uuid()),
          title: "Engineering"
        )
      )
    )

    model.editButtonTapped()

    let editModel = try #require(model.destination?.edit)
    editModel.syncUp.title = "Engineering"
    editModel.syncUp.theme = .lavender
    model.doneEditingButtonTapped()

    #expect(model.destination == nil)
    expectNoDifference(
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

  @Test func delete() async {
    let syncUp = SyncUp.mock
    @Shared(.syncUps) var syncUps = [syncUp]

    let settingsOpened = LockIsolated(false)
    let model = withDependencies {
      $0.continuousClock = ContinuousClock()
      $0.openSettings = { settingsOpened.setValue(true) }
    } operation: {
      SyncUpDetailModel(syncUp: Shared($syncUps[id: syncUp.id])!)
    }

    model.deleteButtonTapped()

    #expect(model.destination?.alert == .deleteSyncUp)

    await model.alertButtonTapped(.confirmDeletion)

    #expect(syncUps == [])
    #expect(model.isDismissed)
  }
}
