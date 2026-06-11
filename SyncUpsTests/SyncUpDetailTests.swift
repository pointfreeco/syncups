import CasePaths
import CustomDump
import DebugSnapshots
import Dependencies
import DependenciesTestSupport
import Foundation
import Sharing
import Testing

@testable import SyncUps

@Suite(
  .dependencies {
    $0.uuid = .incrementing
  }
)
struct SyncUpDetailTests {
  @Dependency(\.openSettings, as: MockOpenSettings.self) var openSettings

  @Test(
    .dependencies {
      $0.speechClient = TestSpeechClient(authorizationStatus: { .restricted })
    }
  )
  func `start meeting with restricted speech recognition`() async throws {
    let model = SyncUpDetailModel(syncUp: Shared(value: .mock))

    expect(model) {
      model.startMeetingButtonTapped()
    } changes: {
      $0.destination = .alert(.speechRecognitionRestricted)
    }
  }

  @Test(
    .dependencies {
      $0.speechClient = TestSpeechClient(authorizationStatus: { .denied })
    }
  )
  func `start meeting with denied speech recognition`() async throws {
    let model = SyncUpDetailModel(syncUp: Shared(value: .mock))

    expect(model) {
      model.startMeetingButtonTapped()
    } changes: {
      $0.destination = .alert(.speechRecognitionDenied)
    }
  }

  @Test(
    .dependencies {
      $0.openSettings = MockOpenSettings()
    }
  )
  func `open settings`() async {
    let model = SyncUpDetailModel(
      destination: .alert(.speechRecognitionDenied),
      syncUp: Shared(value: .mock)
    )

    await model.alertButtonTapped(.openSettings)

    #expect(await openSettings.hasOpened)
  }

  @Test func `continue meeting without recording`() async throws {
    let syncUp = SyncUp.mock

    let model = SyncUpDetailModel(
      destination: .alert(.speechRecognitionDenied),
      syncUp: Shared(value: syncUp)
    )
    nonisolated(unsafe) var meetingStarted = false
    model.onMeetingStarted = { _ in meetingStarted = true }

    await model.alertButtonTapped(.continueWithoutRecording)

    #expect(meetingStarted)
  }

  @Test(
    .dependencies {
      $0.speechClient = TestSpeechClient(authorizationStatus: { .authorized })
    }
  )
  func `start meeting with authorized speech recognition`() async throws {
    let model = SyncUpDetailModel(syncUp: Shared(value: .mock))

    nonisolated(unsafe) var meetingStarted = false
    model.onMeetingStarted = { _ in meetingStarted = true }

    model.startMeetingButtonTapped()

    #expect(meetingStarted)
  }

  @Test
  func `edit the sync up`() async throws {
    let syncUp = SyncUp(
      id: SyncUp.ID(UUID(0)),
      title: "Engineering"
    )
    let model = SyncUpDetailModel(syncUp: Shared(value: syncUp))

    expect(model) {
      model.editButtonTapped()
    } changes: {
      $0.destination = .edit(
        SyncUpFormModel.DebugSnapshot(
          focus: .title,
          syncUp: SyncUp(
            id: syncUp.id,
            attendees: [
              Attendee(
                id: Attendee.ID(UUID(0))
              )
            ],
            title: syncUp.title
          )
        )
      )
    }

    try expect(model) {
      let editModel = try #require(model.destination?.edit)
      editModel.syncUp.title = "Engineering"
      editModel.syncUp.theme = .lavender
      model.doneEditingButtonTapped()
    } changes: {
      $0.destination = nil
      $0.syncUp = SyncUp(
        id: SyncUp.ID(uuidString: "00000000-0000-0000-0000-000000000000")!,
        attendees: [
          Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000000")!)
        ],
        theme: .lavender,
        title: "Engineering"
      )
    }
  }

  @Test(
    .dependencies {
      $0.continuousClock = ContinuousClock()
    }
  )
  func `delete the sync up`() async {
    let syncUp = SyncUp.mock
    @Shared(.syncUps) var syncUps = [syncUp]

    let model = SyncUpDetailModel(syncUp: Shared($syncUps[id: syncUp.id])!)

    expect(model) {
      model.deleteButtonTapped()
    } changes: {
      $0.destination = .alert(.deleteSyncUp)
    }

    await expect(model) {
      await model.alertButtonTapped(.confirmDeletion)
    } changes: {
      $0.isDismissed = true
      #expect(syncUps == [])
    }
  }
}
