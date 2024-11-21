import CasePaths
import Dependencies
import IdentifiedCollections
import Sharing
import SwiftUI

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

#Preview("Happy path") {
  @Shared(.syncUps) var syncUps
  let _ = $syncUps.withLock {
    $0 = [
      SyncUp.mock,
      .engineeringMock,
      .designMock,
    ]
  }
  AppView()
}

#Preview("Deep link record flow") {
  let syncUp = SyncUp.mock
  @Shared(.syncUps) var syncUps
  let _ = $syncUps.withLock {
    $0 = [
      syncUp,
      .engineeringMock,
      .designMock,
    ]
  }
  @Shared(.path) var path = [
    .detail(id: syncUp.id),
    .record(id: syncUp.id),
  ]

  Preview(
    message: """
      The preview demonstrates how you can start the application navigated to a very specific \
      screen just by constructing a piece of state. In particular we will start the app drilled \
      down to the detail screen of a sync-up, and then further drilled down to the record screen \
      for a new meeting.
      """
  ) {
    AppView()
  }
}
