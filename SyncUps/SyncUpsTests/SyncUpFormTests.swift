import CustomDump
import Dependencies

@testable import SyncUps

#if canImport(Testing)
  import Testing

  extension BaseTestSuite {
    @Suite
    @MainActor
    struct SyncUpFormTests {}
  }
  extension BaseTestSuite.SyncUpFormTests {
    @Test
    func addAttendee() {
      let model = withDependencies {
        $0.uuid = .incrementing
      } operation: {
        SyncUpFormModel(
          syncUp: SyncUp(
            id: SyncUp.ID(),
            attendees: [],
            title: "Engineering"
          )
        )
      }

      expectNoDifference(
        model.syncUp.attendees,
        [
          Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000000")!)
        ]
      )

      model.addAttendeeButtonTapped()

      expectNoDifference(
        model.syncUp.attendees,
        [
          Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000000")!),
          Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000001")!),
        ]
      )
    }

    @Test
    func focus_AddAttendee() {
      let model = withDependencies {
        $0.uuid = .incrementing
      } operation: {
        SyncUpFormModel(
          syncUp: SyncUp(
            id: SyncUp.ID(),
            attendees: [],
            title: "Engineering"
          )
        )
      }

      #expect(model.focus == .title)

      model.addAttendeeButtonTapped()

      #expect(
        model.focus ==
        .attendee(Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000001")!)
      )
    }

    @Test
    func focus_RemoveAttendee() {
      let model = withDependencies {
        $0.uuid = .incrementing
      } operation: {
        @Dependency(\.uuid) var uuid

        return SyncUpFormModel(
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
      }

      model.deleteAttendees(atOffsets: [0])

      expectNoDifference(
        model.focus,
        .attendee(Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000001")!)
      )
      expectNoDifference(
        model.syncUp.attendees,
        [
          Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000001")!),
          Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000002")!),
          Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000003")!),
        ]
      )

      model.deleteAttendees(atOffsets: [1])

      expectNoDifference(
        model.focus,
        .attendee(Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000003")!)
      )
      expectNoDifference(
        model.syncUp.attendees,
        [
          Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000001")!),
          Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000003")!),
        ]
      )

      model.deleteAttendees(atOffsets: [1])

      expectNoDifference(
        model.focus,
        .attendee(Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000001")!)
      )
      expectNoDifference(
        model.syncUp.attendees,
        [
          Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000001")!)
        ]
      )

      model.deleteAttendees(atOffsets: [0])

      expectNoDifference(
        model.focus,
        .attendee(Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000004")!)
      )
      expectNoDifference(
        model.syncUp.attendees,
        [
          Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000004")!)
        ]
      )
    }
  }
#else
  import XCTest

  final class SyncUpFormTests: BaseTestCase {
    @MainActor
    func testAddAttendee() {
      let model = withDependencies {
        $0.uuid = .incrementing
      } operation: {
        SyncUpFormModel(
          syncUp: SyncUp(
            id: SyncUp.ID(),
            attendees: [],
            title: "Engineering"
          )
        )
      }

      expectNoDifference(
        model.syncUp.attendees,
        [
          Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000000")!)
        ]
      )

      model.addAttendeeButtonTapped()

      expectNoDifference(
        model.syncUp.attendees,
        [
          Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000000")!),
          Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000001")!),
        ]
      )
    }

    @MainActor
    func testFocus_AddAttendee() {
      let model = withDependencies {
        $0.uuid = .incrementing
      } operation: {
        SyncUpFormModel(
          syncUp: SyncUp(
            id: SyncUp.ID(),
            attendees: [],
            title: "Engineering"
          )
        )
      }

      XCTAssertEqual(model.focus, .title)

      model.addAttendeeButtonTapped()

      XCTAssertEqual(
        model.focus,
        .attendee(Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000001")!)
      )
    }

    @MainActor
    func testFocus_RemoveAttendee() {
      let model = withDependencies {
        $0.uuid = .incrementing
      } operation: {
        @Dependency(\.uuid) var uuid

        return SyncUpFormModel(
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
      }

      model.deleteAttendees(atOffsets: [0])

      expectNoDifference(
        model.focus,
        .attendee(Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000001")!)
      )
      expectNoDifference(
        model.syncUp.attendees,
        [
          Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000001")!),
          Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000002")!),
          Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000003")!),
        ]
      )

      model.deleteAttendees(atOffsets: [1])

      expectNoDifference(
        model.focus,
        .attendee(Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000003")!)
      )
      expectNoDifference(
        model.syncUp.attendees,
        [
          Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000001")!),
          Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000003")!),
        ]
      )

      model.deleteAttendees(atOffsets: [1])

      expectNoDifference(
        model.focus,
        .attendee(Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000001")!)
      )
      expectNoDifference(
        model.syncUp.attendees,
        [
          Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000001")!)
        ]
      )

      model.deleteAttendees(atOffsets: [0])

      expectNoDifference(
        model.focus,
        .attendee(Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000004")!)
      )
      expectNoDifference(
        model.syncUp.attendees,
        [
          Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000004")!)
        ]
      )
    }
  }
#endif
