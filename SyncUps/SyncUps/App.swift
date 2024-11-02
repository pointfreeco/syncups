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
      guard let self else { return }
      withDependencies(from: self) {
        self.path.append(.detail(SyncUpDetailModel(syncUp: syncUp)))
      }
    }

    for destination in path {
      switch destination {
      case let .detail(detailModel):
        bindDetail(model: detailModel)

      case .meeting:
        break

      case let .record(recordModel):
        bindRecord(model: recordModel)
      }
    }
  }

  private func bindDetail(model: SyncUpDetailModel) {
    model.onMeetingStarted = { [weak self] syncUp in
      guard let self else { return }
      withDependencies(from: self) {
        self.path.append(
          .record(
            RecordMeetingModel(syncUp: syncUp)
          )
        )
      }
    }

    model.onConfirmDeletion = { [weak model, weak self] in
      guard let model, let self else { return }
      _ = syncUpsList.$syncUps.withLock { $0.remove(id: model.syncUp.id) }
      path.removeLast()
    }

    model.onMeetingTapped = { [weak model, weak self] meeting in
      guard let model, let self else { return }
      path.append(.meeting(meeting, syncUp: model.syncUp))
    }

    model.onSyncUpUpdated = { [weak self] syncUp in
      guard let self else { return }
      syncUpsList.$syncUps.withLock { $0[id: syncUp.id] = syncUp }
    }
  }

  private func bindRecord(model: RecordMeetingModel) {
    model.onMeetingFinished = { [weak self] transcript in
      guard let self else { return }

      guard
        case let .some(.detail(detailModel)) = path.dropLast().last
      else {
        return
      }

      let meeting = Meeting(
        id: Meeting.ID(self.uuid()),
        date: self.now,
        transcript: transcript
      )

      let didCancel = (try? await clock.sleep(for: .milliseconds(400))) == nil
      _ = withAnimation(didCancel ? nil : .default) {
        detailModel.syncUp.meetings.insert(meeting, at: 0)
      }
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
          .detail(SyncUpDetailModel(syncUp: .mock)),
          .record(RecordMeetingModel(syncUp: .mock)),
        ],
        syncUpsList: SyncUpsListModel()
      )
    )
  }
}
