import CasePaths
import CustomDump
import Dependencies
import Foundation

@testable import SyncUps

#if canImport(Testing)
  import Testing

  extension BaseTestSuite {
    @Suite
    @MainActor
    struct AppTests {}
  }
  extension BaseTestSuite.AppTests {
    @Test
    func recordingWithTranscript() async throws {
      let syncUp = SyncUp(
        id: SyncUp.ID(),
        attendees: [
          .init(id: Attendee.ID()),
          .init(id: Attendee.ID()),
        ],
        duration: .seconds(10),
        title: "Engineering"
      )

      let model = withDependencies {
        $0.continuousClock = ImmediateClock()
        $0.date.now = Date(timeIntervalSince1970: 1_234_567_890)
        $0.dataManager = .mock(initialData: try? JSONEncoder().encode([syncUp]))
        $0.soundEffectClient = .noop
        $0.speechClient.authorizationStatus = { .authorized }
        $0.speechClient.startTask = { @Sendable _ in
          AsyncThrowingStream { continuation in
            continuation.yield(
              SpeechRecognitionResult(
                bestTranscription: Transcription(formattedString: "I completed the project"),
                isFinal: true
              )
            )
            continuation.finish()
          }
        }
        $0.uuid = .incrementing
      } operation: {
        AppModel(
          path: [
            .detail(SyncUpDetailModel(syncUp: syncUp)),
            .record(RecordMeetingModel(syncUp: syncUp)),
          ],
          syncUpsList: SyncUpsListModel()
        )
      }

      let recordModel = try #require(model.path[1].record)
      await recordModel.task()

      expectNoDifference(
        model.syncUpsList.syncUps[0].meetings,
        [
          Meeting(
            id: Meeting.ID(uuidString: "00000000-0000-0000-0000-000000000000")!,
            date: Date(timeIntervalSince1970: 1_234_567_890),
            transcript: "I completed the project"
          )
        ]
      )
    }

    @Test
    func delete() async throws {
      let model = try withDependencies {
        $0.continuousClock = ImmediateClock()
        $0.dataManager = .mock(
          initialData: try JSONEncoder().encode([SyncUp.mock])
        )
      } operation: {
        AppModel(syncUpsList: SyncUpsListModel())
      }

      model.syncUpsList.syncUpTapped(syncUp: model.syncUpsList.syncUps[0])

      let detailModel = try #require(model.path[0].detail)

      detailModel.deleteButtonTapped()

      let alert = try #require(detailModel.destination?.alert)

      expectNoDifference(alert, .deleteSyncUp)

      await detailModel.alertButtonTapped(.confirmDeletion)

      expectNoDifference(model.path, [])
      expectNoDifference(model.syncUpsList.syncUps, [])
    }

    @Test
    func detailEdit() async throws {
      let model = try withDependencies {
        $0.continuousClock = ImmediateClock()
        $0.dataManager = .mock(
          initialData: try JSONEncoder().encode([
            SyncUp(
              id: SyncUp.ID(uuidString: "00000000-0000-0000-0000-000000000000")!,
              attendees: [
                Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000001")!)
              ]
            )
          ])
        )
      } operation: {
        AppModel(syncUpsList: SyncUpsListModel())
      }

      model.syncUpsList.syncUpTapped(syncUp: model.syncUpsList.syncUps[0])

      let detailModel = try #require(model.path[0].detail)

      detailModel.editButtonTapped()

      let editModel = try #require(detailModel.destination?.edit)

      editModel.syncUp.title = "Design"
      detailModel.doneEditingButtonTapped()

      #expect(detailModel.destination == nil)
      expectNoDifference(
        model.syncUpsList.syncUps,
        [
          SyncUp(
            id: SyncUp.ID(uuidString: "00000000-0000-0000-0000-000000000000")!,
            attendees: [
              Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000001")!)
            ],
            title: "Design"
          )
        ]
      )
    }
  }
#else
  import XCTest

  final class AppTests: BaseTestCase {
    @MainActor
    func testRecordWithTranscript() async throws {
      let syncUp = SyncUp(
        id: SyncUp.ID(),
        attendees: [
          .init(id: Attendee.ID()),
          .init(id: Attendee.ID()),
        ],
        duration: .seconds(10),
        title: "Engineering"
      )

      let model = withDependencies {
        $0.continuousClock = ImmediateClock()
        $0.date.now = Date(timeIntervalSince1970: 1_234_567_890)
        $0.dataManager = .mock(initialData: try? JSONEncoder().encode([syncUp]))
        $0.soundEffectClient = .noop
        $0.speechClient.authorizationStatus = { .authorized }
        $0.speechClient.startTask = { @Sendable _ in
          AsyncThrowingStream { continuation in
            continuation.yield(
              SpeechRecognitionResult(
                bestTranscription: Transcription(formattedString: "I completed the project"),
                isFinal: true
              )
            )
            continuation.finish()
          }
        }
        $0.uuid = .incrementing
      } operation: {
        AppModel(
          path: [
            .detail(SyncUpDetailModel(syncUp: syncUp)),
            .record(RecordMeetingModel(syncUp: syncUp)),
          ],
          syncUpsList: SyncUpsListModel()
        )
      }

      let recordModel = try XCTUnwrap(model.path[1].record)
      await recordModel.task()

      expectNoDifference(
        model.syncUpsList.syncUps[0].meetings,
        [
          Meeting(
            id: Meeting.ID(uuidString: "00000000-0000-0000-0000-000000000000")!,
            date: Date(timeIntervalSince1970: 1_234_567_890),
            transcript: "I completed the project"
          )
        ]
      )
    }

    @MainActor
    func testDelete() async throws {
      let model = try withDependencies {
        $0.continuousClock = ImmediateClock()
        $0.dataManager = .mock(
          initialData: try JSONEncoder().encode([SyncUp.mock])
        )
      } operation: {
        AppModel(syncUpsList: SyncUpsListModel())
      }

      model.syncUpsList.syncUpTapped(syncUp: model.syncUpsList.syncUps[0])

      let detailModel = try XCTUnwrap(model.path[0].detail)

      detailModel.deleteButtonTapped()

      let alert = try XCTUnwrap(detailModel.destination?.alert)

      expectNoDifference(alert, .deleteSyncUp)

      await detailModel.alertButtonTapped(.confirmDeletion)

      XCTAssertEqual(model.path, [])
      XCTAssertEqual(model.syncUpsList.syncUps, [])
    }

    @MainActor
    func testDetailEdit() async throws {
      let model = try withDependencies {
        $0.continuousClock = ImmediateClock()
        $0.dataManager = .mock(
          initialData: try JSONEncoder().encode([
            SyncUp(
              id: SyncUp.ID(uuidString: "00000000-0000-0000-0000-000000000000")!,
              attendees: [
                Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000001")!)
              ]
            )
          ])
        )
      } operation: {
        AppModel(syncUpsList: SyncUpsListModel())
      }

      model.syncUpsList.syncUpTapped(syncUp: model.syncUpsList.syncUps[0])

      let detailModel = try XCTUnwrap(model.path[0].detail)

      detailModel.editButtonTapped()

      let editModel = try XCTUnwrap(detailModel.destination?.edit)

      editModel.syncUp.title = "Design"
      detailModel.doneEditingButtonTapped()

      XCTAssertNil(detailModel.destination)
      XCTAssertEqual(
        model.syncUpsList.syncUps,
        [
          SyncUp(
            id: SyncUp.ID(uuidString: "00000000-0000-0000-0000-000000000000")!,
            attendees: [
              Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000001")!)
            ],
            title: "Design"
          )
        ]
      )
    }
  }
#endif
