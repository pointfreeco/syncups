import CasePaths
import CustomDump
import Dependencies
import Testing

@testable import SyncUps

@MainActor
@Suite
struct SyncUpDetailTests {
  @Test
  func speechRestricted() async throws {
    let model = withDependencies {
      $0.speechClient.authorizationStatus = { .restricted }
    } operation: {
      SyncUpDetailModel(syncUp: .mock)
    }

    model.startMeetingButtonTapped()

    let alert = try #require(model.destination?.alert)

    expectNoDifference(alert, .speechRecognitionRestricted)
  }

  @Test
  func speechDenied() async throws {
    let model = withDependencies {
      $0.speechClient.authorizationStatus = { .denied }
    } operation: {
      SyncUpDetailModel(syncUp: .mock)
    }

    model.startMeetingButtonTapped()

    let alert = try #require(model.destination?.alert)

    expectNoDifference(alert, .speechRecognitionDenied)
  }

  @Test
  func openSettings() async {
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

    #expect(settingsOpened.value == true)
  }

  @Test
  func continueWithoutRecording() async throws {
    let model = SyncUpDetailModel(
      destination: .alert(.speechRecognitionDenied),
      syncUp: .mock
    )

    await confirmation { confirmation in
      model.onMeetingStarted = { syncUp in
        #expect(syncUp == .mock)
        confirmation()
      }

      await model.alertButtonTapped(.continueWithoutRecording)
    }
  }

  @Test
  func speechAuthorized() async throws {
    let model = withDependencies {
      $0.speechClient.authorizationStatus = { .authorized }
    } operation: {
      SyncUpDetailModel(syncUp: .mock)
    }

    await confirmation { confirmation in
      model.onMeetingStarted = { syncUp in
        #expect(syncUp == .mock)
        confirmation()
      }

      model.startMeetingButtonTapped()
    }
  }

  @Test
  func edit() async throws {
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

    try await confirmation { confirmation in
      model.onSyncUpUpdated = { _ in confirmation() }

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
  }
}
