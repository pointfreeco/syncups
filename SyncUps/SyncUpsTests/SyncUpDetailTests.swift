import CasePaths
import CustomDump
import Dependencies

@testable import SyncUps

#if canImport(Testing)
  import Testing

  extension BaseTestSuite {
    @Suite
    @MainActor
    struct SyncUpDetailTests {}
  }
  extension BaseTestSuite.SyncUpDetailTests {
    @Test
    func speechRestricted() throws {
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
#else
  import XCTest

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

      expectNoDifference(alert, .speechRecognitionRestricted)
    }

    func testSpeechDenied() async throws {
      let model = withDependencies {
        $0.speechClient.authorizationStatus = { .denied }
      } operation: {
        SyncUpDetailModel(syncUp: .mock)
      }

      model.startMeetingButtonTapped()

      let alert = try XCTUnwrap(model.destination?.alert)

      expectNoDifference(alert, .speechRecognitionDenied)
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

      let onMeetingStartedExpectation = self.expectation(description: "onMeetingStarted")
      model.onMeetingStarted = { syncUp in
        XCTAssertEqual(syncUp, .mock)
        onMeetingStartedExpectation.fulfill()
      }

      await model.alertButtonTapped(.continueWithoutRecording)

      await self.fulfillment(of: [onMeetingStartedExpectation])
    }

    func testSpeechAuthorized() async throws {
      let model = withDependencies {
        $0.speechClient.authorizationStatus = { .authorized }
      } operation: {
        SyncUpDetailModel(syncUp: .mock)
      }

      let onMeetingStartedExpectation = self.expectation(description: "onMeetingStarted")
      model.onMeetingStarted = { syncUp in
        XCTAssertEqual(syncUp, .mock)
        onMeetingStartedExpectation.fulfill()
      }

      model.startMeetingButtonTapped()

      await self.fulfillment(of: [onMeetingStartedExpectation])
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

      let onSyncUpUpdatedExpectation = self.expectation(description: "onSyncUpUpdated")
      defer { self.wait(for: [onSyncUpUpdatedExpectation], timeout: 0) }
      model.onSyncUpUpdated = { _ in onSyncUpUpdatedExpectation.fulfill() }

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
#endif
