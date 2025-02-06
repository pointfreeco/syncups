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
    syncUpsList: SyncUpsListModel = SyncUpsListModel()
  ) {
    self.path = path
    self.syncUpsList = syncUpsList
    self.bind()
  }

  private func bind() {
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
      guard let self else { return }
      withDependencies(from: self) {
        path.append(.record(RecordMeetingModel(syncUp: syncUp)))
      }
    }
  }
}

struct AppView: View {
  @Bindable var model: AppModel

  var body: some View {
    NavigationStack(path: $model.path) {
      SyncUpsList(model: model.syncUpsList)
        .navigationDestination(for: AppModel.Path.self) { path in
          switch path {
          case let .detail(model):
            SyncUpDetailView(model: model)
          case let .meeting(meeting, syncUp: syncUp):
            MeetingView(meeting: meeting, syncUp: syncUp)
          case let .record(model):
            RecordMeetingView(model: model)
          }
        }
    }
  }
}

#Preview("Happy path") {
  AppView(model: AppModel())
}

#Preview("Deep link record flow") {
  let syncUp = SyncUp.mock
  @Shared(.syncUps) var syncUps = [syncUp]

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
          .detail(SyncUpDetailModel(syncUp: Shared($syncUps[id: syncUp.id])!)),
          .record(RecordMeetingModel(syncUp: Shared($syncUps[id: syncUp.id])!)),
        ]
      )
    )
  }
}
