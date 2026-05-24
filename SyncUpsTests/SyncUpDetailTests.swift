import CasePaths
import CustomDump
import DebugSnapshots
import Dependencies
import DependenciesTestSupport
import Foundation
import Sharing
import Synchronization
import Testing

@testable import SyncUps

@Suite(
  .dependencies {
    $0.uuid = .incrementing
  }
)
struct SyncUpDetailTests {
  @Test(
    .dependencies {
      $0.speechClient.authorizationStatus = { .restricted }
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
      $0.speechClient.authorizationStatus = { .denied }
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

  @Test func `open settings`() async {
    let settingsOpened = Mutex(false)
    await withDependencies {
      $0.openSettings = { settingsOpened.withLock { $0 = true } }
    } operation: {
      let model = SyncUpDetailModel(
        destination: .alert(.speechRecognitionDenied),
        syncUp: Shared(value: .mock)
      )

      await model.alertButtonTapped(.openSettings)

      #expect(settingsOpened.withLock { $0 })
    }
  }

  @Test func continueWithoutRecording() async throws {
    let syncUp = SyncUp.mock

    let model = SyncUpDetailModel(
      destination: .alert(.speechRecognitionDenied),
      syncUp: Shared(value: syncUp)
    )
    let meetingStarted = Mutex(false)
    model.onMeetingStarted = { _ in meetingStarted.withLock { $0 = true } }

    await model.alertButtonTapped(.continueWithoutRecording)

    #expect(meetingStarted.withLock { $0 })
  }

  @Test(
    .dependencies {
      $0.speechClient.authorizationStatus = { .authorized }
    }
  )
  func speechAuthorized() async throws {
    let model = SyncUpDetailModel(syncUp: Shared(value: .mock))

    let meetingStarted = Mutex(false)
    model.onMeetingStarted = { _ in meetingStarted.withLock { $0 = true } }

    model.startMeetingButtonTapped()

    #expect(meetingStarted.withLock { $0 })
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

    let settingsOpened = Mutex(false)
    await withDependencies {
      $0.openSettings = { settingsOpened.withLock { $0 = true } }
    } operation: {
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
}
