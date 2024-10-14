#if canImport(Testing)
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
      let savedData = LockIsolated(Data?.none)

      let model = withDependencies {
        $0.continuousClock = ImmediateClock()
        $0.dataManager = .mock()
        $0.dataManager.save = { @Sendable data, _ in savedData.setValue(data) }
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
        $0.dataManager = .mock()
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

    @Test
    func loadingDataDecodingFailed() async throws {
      let model = withDependencies {
        $0.continuousClock = ImmediateClock()
        $0.dataManager = .mock(
          initialData: Data("!@#$ BAD DATA %^&*()".utf8)
        )
      } operation: {
        SyncUpsListModel()
      }

      let alert = try #require(model.destination?.alert)

      expectNoDifference(alert, .dataFailedToLoad)

      model.alertButtonTapped(.confirmLoadMockData)

      expectNoDifference(model.syncUps, [.mock, .designMock, .engineeringMock])
    }

    @Test
    func loadingDataFileNotFound() async throws {
      let model = withDependencies {
        $0.dataManager.load = { @Sendable _ in
          struct FileNotFound: Error {}
          throw FileNotFound()
        }
      } operation: {
        SyncUpsListModel()
      }

      #expect(model.destination == nil)
    }

    @Test
    func save() async throws {
      let clock = TestClock()

      let savedData = LockIsolated<Data>(Data())
      await confirmation { confirmation in
        let model = withDependencies {
          $0.dataManager.load = { @Sendable _ in try JSONEncoder().encode([SyncUp]()) }
          $0.dataManager.save = { @Sendable data, _ in
            savedData.setValue(data)
            confirmation()
          }
          $0.continuousClock = clock
        } operation: {
          SyncUpsListModel(
            destination: .add(SyncUpFormModel(syncUp: .mock))
          )
        }

        model.confirmAddSyncUpButtonTapped()
        await clock.advance(by: .seconds(1))
      }

      expectNoDifference(
        try JSONDecoder().decode([SyncUp].self, from: savedData.value),
        [.mock]
      )
    }
  }
#endif
