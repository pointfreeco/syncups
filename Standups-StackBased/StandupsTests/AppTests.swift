import CasePaths
import CustomDump
import Dependencies
import XCTest

@testable import Standups_StackBased

@MainActor
final class AppTests: BaseTestCase {
  func testRecordWithTranscript() async throws {
    let standup = Standup(
      id: Standup.ID(),
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
      $0.mainQueue = .immediate
      $0.dataManager = .mock(initialData: try? JSONEncoder().encode([standup]))
      $0.soundEffectClient = .noop
      $0.speechClient.authorizationStatus = { .authorized }
      $0.speechClient.startTask = { _ in
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
          .detail(StandupDetailModel(standup: standup)),
          .record(RecordMeetingModel(standup: standup)),
        ],
        standupsList: StandupsListModel()
      )
    }

    let recordModel = try XCTUnwrap(model.path[1], case: /AppModel.Destination.record)
    await recordModel.task()

    XCTAssertEqual(model.path, [model.path[0]])
    XCTAssertNoDifference(
      model.standupsList.standups[0].meetings,
      [
        Meeting(
          id: Meeting.ID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          date: Date(timeIntervalSince1970: 1_234_567_890),
          transcript: "I completed the project"
        )
      ]
    )
  }

  func testDelete() async throws {
    let model = try withDependencies { dependencies in
      dependencies.dataManager = .mock(
        initialData: try JSONEncoder().encode([Standup.mock])
      )
      dependencies.mainQueue = .immediate
    } operation: {
      AppModel(standupsList: StandupsListModel())
    }

    model.standupsList.standupTapped(standup: model.standupsList.standups[0])

    let detailModel = try XCTUnwrap(model.path[0], case: /AppModel.Destination.detail)

    detailModel.deleteButtonTapped()

    let alert = try XCTUnwrap(detailModel.destination, case: /StandupDetailModel.Destination.alert)

    XCTAssertNoDifference(alert, .deleteStandup)

    await detailModel.alertButtonTapped(.confirmDeletion)

    XCTAssertEqual(model.path, [])
    XCTAssertEqual(model.standupsList.standups, [])
  }

  func testDetailEdit() async throws {
    let model = try withDependencies { dependencies in
      dependencies.dataManager = .mock(
        initialData: try JSONEncoder().encode([
          Standup(
            id: Standup.ID(uuidString: "00000000-0000-0000-0000-000000000000")!,
            attendees: [
              Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000001")!)
            ]
          )
        ])
      )
      dependencies.mainQueue = .immediate
    } operation: {
      AppModel(standupsList: StandupsListModel())
    }

    model.standupsList.standupTapped(standup: model.standupsList.standups[0])

    let detailModel = try XCTUnwrap(model.path[0], case: /AppModel.Destination.detail)

    detailModel.editButtonTapped()

    let editModel = try XCTUnwrap(
      detailModel.destination, case: /StandupDetailModel.Destination.edit)

    editModel.standup.title = "Design"
    detailModel.doneEditingButtonTapped()

    XCTAssertNil(detailModel.destination)
    XCTAssertEqual(
      model.standupsList.standups,
      [
        Standup(
          id: Standup.ID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          attendees: [
            Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000001")!)
          ],
          title: "Design"
        )
      ]
    )
  }
}
