import CasePaths
import Dependencies
import IdentifiedCollections
import Sharing
import SwiftUI

@MainActor
@Observable
class AppModel {
  var path: [Path] {
    didSet { bind() }
  }
  var syncUpsList: SyncUpsListModel {
    didSet { bind() }
  }

  @ObservationIgnored
  @Dependency(\.continuousClock) var clock
  @ObservationIgnored
  @Dependency(\.date.now) var now
  @ObservationIgnored
  @Dependency(\.uuid) var uuid

  @CasePathable
  @dynamicMemberLookup
  enum Path: Hashable {
    case detail(SyncUpDetailModel)
    case meeting(Meeting, syncUp: SyncUp)
    case record(RecordMeetingModel)
  }

  init(
    path: [Path] = [],
    syncUpsList: SyncUpsListModel
  ) {
    self.path = path
    self.syncUpsList = syncUpsList
    self.bind()
  }

  private func bind() {
    syncUpsList.onSyncUpTapped = { [weak self] syncUp in
      guard
        let self,
        let sharedSyncUp = Shared(syncUpsList.$syncUps[id: syncUp.id])
      else { return }
      withDependencies(from: self) {
        self.path.append(.detail(SyncUpDetailModel(syncUp: sharedSyncUp)))
      }
    }

    for destination in path {
      switch destination {
      case let .detail(detailModel):
        bindDetail(model: detailModel)

      case .meeting, .record:
        break
      }
    }
  }

  private func bindDetail(model: SyncUpDetailModel) {
    model.onMeetingStarted = { [weak self] syncUp in
      guard
        let self,
        let sharedSyncUp = Shared(syncUpsList.$syncUps[id: syncUp.id])
      else { return }

      withDependencies(from: self) {
        self.path.append(
          .record(
            RecordMeetingModel(syncUp: sharedSyncUp)
          )
        )
      }
    }

    model.onMeetingTapped = { [weak model, weak self] meeting in
      guard let model, let self else { return }
      path.append(.meeting(meeting, syncUp: model.syncUp))
    }
  }
}

struct AppView: View {
  @State var model: AppModel

  var body: some View {
    NavigationStack(path: $model.path) {
      SyncUpsList(model: model.syncUpsList)
        .navigationDestination(for: AppModel.Path.self) { destination in
          switch destination {
          case let .detail(detailModel):
            SyncUpDetailView(model: detailModel)
          case let .meeting(meeting, syncUp: syncUp):
            MeetingView(meeting: meeting, syncUp: syncUp)
          case let .record(recordModel):
            RecordMeetingView(model: recordModel)
          }
        }
    }
  }
}

#Preview("Happy path") {
  @Shared(.syncUps) var syncUps: IdentifiedArray = [
    SyncUp.mock,
    .engineeringMock,
    .designMock,
  ]

  AppView(
    model: AppModel(syncUpsList: SyncUpsListModel())
  )
}

#Preview("Deep link record flow") {
  @Shared(.syncUps) var syncUps: IdentifiedArray = [
    SyncUp.mock,
    .engineeringMock,
    .designMock,
  ]

  Preview(
    message: """
      The preview demonstrates how you can start the application navigated to a very specific \
      screen just by constructing a piece of state. In particular we will start the app drilled \
      down to the detail screen of a sync-up, and then further drilled down to the record screen \
      for a new meeting.
      """
  ) {
    AppView(
      model: AppModel(
        path: [
          .detail(SyncUpDetailModel(syncUp: Shared(.mock))),
          .record(RecordMeetingModel(syncUp: Shared(.mock))),
        ],
        syncUpsList: SyncUpsListModel()
      )
    )
  }
}
