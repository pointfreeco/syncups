import CasePaths
import Dependencies
import IdentifiedCollections
import Sharing
import SwiftUI

@CasePathable
enum AppPath: Codable, Hashable {
  case detail(id: SyncUp.ID)
  case meeting(id: Meeting.ID, syncUpID: SyncUp.ID)
  case record(id: SyncUp.ID)
}

extension PersistenceReaderKey where Self == FileStorageKey<[AppPath]>.Default {
  static var path: Self {
    Self[
      .fileStorage(
        .documentsDirectory.appending(path: "path.json"),
        decode: { data in
          try JSONDecoder().decode([AppPath].self, from: data)
        },
        // TODO: write unit tests for encode logic
        encode: { path in
          try JSONEncoder().encode(
            path.filter {
              switch $0 {
              case .detail:
                true
              case .meeting:
                true
              case .record:
                false
              }
            }
          )
        }
      ),
      default: []
    ]
  }
}

struct AppView: View {
  @Shared(.path) var path

  var body: some View {
    NavigationStack(path: Binding($path)) {
      SyncUpsList()
        .navigationDestination(for: AppPath.self) { path in
          switch path {
          case let .detail(id: syncUpID):
            SyncUpDetailView(id: syncUpID)
          case let .meeting(id: meetingID, syncUpID: syncUpID):
            MeetingView(id: meetingID, syncUpID: syncUpID)
          case let .record(id: syncUpID):
            RecordMeetingView(id: syncUpID)
          }
        }
    }
  }
}

//#Preview("Happy path") {
//  @Shared(.syncUps) var syncUps: IdentifiedArray = [
//    SyncUp.mock,
//    .engineeringMock,
//    .designMock,
//  ]
//
//  AppView(
//    model: AppModel(syncUpsList: SyncUpsListModel())
//  )
//}
//
//#Preview("Deep link record flow") {
//  @Shared(.syncUps) var syncUps: IdentifiedArray = [
//    SyncUp.mock,
//    .engineeringMock,
//    .designMock,
//  ]
//
//  Preview(
//    message: """
//      The preview demonstrates how you can start the application navigated to a very specific \
//      screen just by constructing a piece of state. In particular we will start the app drilled \
//      down to the detail screen of a sync-up, and then further drilled down to the record screen \
//      for a new meeting.
//      """
//  ) {
//    AppView(
//      model: AppModel(
//        path: [
//          .detail(SyncUpDetailModel(syncUp: Shared(.mock))),
//          .record(RecordMeetingModel(syncUp: Shared(.mock))),
//        ],
//        syncUpsList: SyncUpsListModel()
//      )
//    )
//  }
//}
