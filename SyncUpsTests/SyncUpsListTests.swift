import CasePaths
import CustomDump
import DebugSnapshots
import Dependencies
import DependenciesTestSupport
import Foundation
import IdentifiedCollections
import Testing

@testable import SyncUps

@Suite(
  .dependencies {
    $0.continuousClock = ImmediateClock()
    $0.uuid = .incrementing
  }
)
struct SyncUpsListTests {
  @Test
  func `add sync up`() async throws {
    let model = SyncUpsListModel()

    expect(model) {
      model.addSyncUpButtonTapped()
    } changes: {
      $0.addSyncUp = SyncUpFormModel.DebugSnapshot(
        focus: .title,
        syncUp: SyncUp(
          id: SyncUp.ID(UUID(0)),
          attendees: [Attendee(id: Attendee.ID(UUID(1)))]
        )
      )
    }

    try expect(model) {
      let addModel = try #require(model.addSyncUp)
      addModel.syncUp.title = "Engineering"
      addModel.syncUp.attendees[0].name = "Blob"
      addModel.addAttendeeButtonTapped()
      addModel.syncUp.attendees[1].name = "Blob Jr."
      model.confirmAddSyncUpButtonTapped()
    } changes: {
      $0.addSyncUp = nil
      $0.syncUps = [
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
    }
  }

  @Test
  func `remove attendees with empty name`() async throws {
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
    
    expect(model) {
      model.confirmAddSyncUpButtonTapped()
    } changes: {
      $0.addSyncUp = nil
      $0.syncUps = [
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
    }
  }
}
