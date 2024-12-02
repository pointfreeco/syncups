import CasePaths
import CustomDump
import Dependencies
import DependenciesTestSupport
import Foundation
import IdentifiedCollections
import Testing

@testable import SyncUps

@MainActor
@Suite
struct SyncUpsListTests {
  @Test(
    .dependency(\.continuousClock, ImmediateClock()),
    .dependency(\.uuid, .incrementing)
  )
  func add() async throws {
    let model = SyncUpsListModel()

    model.addSyncUpButtonTapped()

    let addModel = try #require(model.addSyncUp)

    addModel.syncUp.title = "Engineering"
    addModel.syncUp.attendees[0].name = "Blob"
    addModel.addAttendeeButtonTapped()
    addModel.syncUp.attendees[1].name = "Blob Jr."
    model.confirmAddSyncUpButtonTapped()

    #expect(model.addSyncUp == nil)

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

  @Test(
    .dependency(\.continuousClock, ImmediateClock()),
    .dependency(\.uuid, .incrementing)
  )
  func addValidatedAttendees() async throws {
    let model = SyncUpsListModel(
      addSyncUp: SyncUpFormModel(
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

    model.confirmAddSyncUpButtonTapped()

    #expect(model.addSyncUp == nil)
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
