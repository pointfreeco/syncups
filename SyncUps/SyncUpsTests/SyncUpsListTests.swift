import CasePaths
import CustomDump
import Dependencies
import Foundation
import IdentifiedCollections
import Testing

@testable import SyncUps

@MainActor
@Suite
struct SyncUpsListTests {
  @Test
  func add() async throws {
    let model = withDependencies {
      $0.continuousClock = ImmediateClock()
      $0.uuid = .incrementing
    } operation: {
      SyncUpsListModel()
    }

    model.addSyncUpButtonTapped()

    let addModel = try #require(model.destination?.add)

    addModel.syncUp.title = "Engineering"
    addModel.syncUp.attendees[0].name = "Blob"
    addModel.addAttendeeButtonTapped()
    addModel.syncUp.attendees[1].name = "Blob Jr."
    model.confirmAddSyncUpButtonTapped()

    #expect(model.destination == nil)

    expectNoDifference(
      model.syncUps,
      [
        SyncUp(
          id: SyncUp.ID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          attendees: [
            Attendee(
              id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000001")!,
              name: "Blob"
            ),
            Attendee(
              id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000002")!,
              name: "Blob Jr."
            ),
          ],
          title: "Engineering"
        )
      ]
    )
  }

  @Test
  func addValidatedAttendees() async throws {
    let model = withDependencies {
      $0.continuousClock = ImmediateClock()
      $0.uuid = .incrementing
    } operation: {
      SyncUpsListModel(
        destination: .add(
          SyncUpFormModel(
            syncUp: SyncUp(
              id: SyncUp.ID(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")!,
              attendees: [
                Attendee(id: Attendee.ID(), name: ""),
                Attendee(id: Attendee.ID(), name: "    "),
              ],
              title: "Design"
            )
          )
        )
      )
    }

    model.confirmAddSyncUpButtonTapped()

    #expect(model.destination == nil)
    expectNoDifference(
      model.syncUps,
      [
        SyncUp(
          id: SyncUp.ID(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")!,
          attendees: [
            Attendee(
              id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000000")!,
              name: ""
            )
          ],
          title: "Design"
        )
      ]
    )
  }
}
