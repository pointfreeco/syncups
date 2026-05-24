import CustomDump
import DebugSnapshots
import Dependencies
import Foundation
import Testing

@testable import SyncUps

@Suite(
  .dependencies {
    $0.uuid = .incrementing
  }
)
struct SyncUpFormTests {
  @Dependency(\.uuid) var uuid

  @Test func `add attendee`() async {
    let model = SyncUpFormModel(
      syncUp: SyncUp(
        id: SyncUp.ID(),
        attendees: [],
        title: "Engineering"
      )
    )

    expect(model) {
      $0.syncUp.attendees = [
        Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000000")!)
      ]
    }

    expect(model) {
      model.addAttendeeButtonTapped()
    } changes: {
      $0.focus = .attendee(Attendee.ID(UUID(1)))
      $0.syncUp.attendees = [
        Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000000")!),
        Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000001")!),
      ]
    }
  }

  @Test func `remove attendee`() async {
    let model = SyncUpFormModel(
      syncUp: SyncUp(
        id: SyncUp.ID(),
        attendees: [
          Attendee(id: Attendee.ID(uuid())),
          Attendee(id: Attendee.ID(uuid())),
          Attendee(id: Attendee.ID(uuid())),
          Attendee(id: Attendee.ID(uuid())),
        ],
        title: "Engineering"
      )
    )

    expect(model) {
      model.deleteAttendees(atOffsets: [0])
    } changes: {
      $0.focus = .attendee(Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000001")!)
      $0.syncUp.attendees =
      [
        Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000001")!),
        Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000002")!),
        Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000003")!),
      ]
    }

    expect(model) {
      model.deleteAttendees(atOffsets: [1])
    } changes: {
      $0.focus = .attendee(Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000003")!)
      $0.syncUp.attendees = [
        Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000001")!),
        Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000003")!),
      ]
    }

    expect(model) {
      model.deleteAttendees(atOffsets: [1])
    } changes: {
      $0.focus = .attendee(Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000001")!)
      $0.syncUp.attendees = [
        Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000001")!)
      ]
    }

    expect(model) {
      model.deleteAttendees(atOffsets: [0])
    } changes: {
      $0.focus = .attendee(Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000004")!)
      $0.syncUp.attendees = [
        Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000004")!)
      ]
    }
  }
}
