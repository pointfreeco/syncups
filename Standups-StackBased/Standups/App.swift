import Combine
import Dependencies
import SwiftUI

@MainActor
@Observable
class AppModel {
  var path: [Destination] {
    didSet { self.bind() }
  }
  var standupsList: StandupsListModel {
    didSet { self.bind() }
  }

  @ObservationIgnored
  @Dependency(\.continuousClock) var clock
  @ObservationIgnored
  @Dependency(\.date.now) var now
  @ObservationIgnored
  @Dependency(\.uuid) var uuid

  @ObservationIgnored
  private var detailCancellable: AnyCancellable?

  enum Destination: Hashable {
    case detail(StandupDetailModel)
    case meeting(Meeting, standup: Standup)
    case record(RecordMeetingModel)
  }

  init(
    path: [Destination] = [],
    standupsList: StandupsListModel
  ) {
    self.path = path
    self.standupsList = standupsList
    self.bind()
  }

  private func bind() {
    self.standupsList.onStandupTapped = { [weak self] standup in
      self?.path.append(.detail(StandupDetailModel(standup: standup)))
    }

    for destination in self.path {
      switch destination {
      case let .detail(detailModel):
        self.bindDetail(model: detailModel)

      case .meeting:
        break

      case let .record(recordModel):
        self.bindRecord(model: recordModel)
      }
    }
  }

  private func bindDetail(model: StandupDetailModel) {
    model.onMeetingStarted = { [weak self] standup in
      self?.path.append(
        .record(
          RecordMeetingModel(standup: standup)
        )
      )
    }

    model.onConfirmDeletion = { [weak model, weak self] in
      guard let model else { return }
      self?.standupsList.standups.remove(id: model.standup.id)
      self?.path.removeLast()
    }

    model.onMeetingTapped = { [weak model, weak self] meeting in
      guard let model else { return }
      self?.path.append(.meeting(meeting, standup: model.standup))
    }

    // TODO
//    self.detailCancellable = model.$standup
//      .sink { [weak self] standup in
//        self?.standupsList.standups[id: standup.id] = standup
//      }
  }

  private func bindRecord(model: RecordMeetingModel) {
    model.onDiscardMeeting = { [weak self] in
      self?.path.removeLast()
    }

    model.onMeetingFinished = { [weak self] transcript in
      guard let self else { return }

      guard
        case let .some(.detail(detailModel)) = self.path.dropLast().last
      else {
        return
      }

      let meeting = Meeting(
        id: Meeting.ID(self.uuid()),
        date: self.now,
        transcript: transcript
      )

      self.path.removeLast()
      let didCancel = (try? await self.clock.sleep(for: .milliseconds(400))) == nil
      _ = withAnimation(didCancel ? nil : .default) {
        detailModel.standup.meetings.insert(meeting, at: 0)
      }
    }
  }
}

struct AppView: View {
  @State var model: AppModel

  var body: some View {
    let _ = Self._printChanges()
    NavigationStack(path: self.$model.path) {
      StandupsList(model: self.model.standupsList)
        .navigationDestination(for: AppModel.Destination.self) { destination in
          switch destination {
          case let .detail(detailModel):
            StandupDetailView(model: detailModel)
          case let .meeting(meeting, standup: standup):
            MeetingView(meeting: meeting, standup: standup)
          case let .record(recordModel):
            RecordMeetingView(model: recordModel)
          }
        }
    }
  }
}

struct App_Previews: PreviewProvider {
  static var previews: some View {
    AppView(
      model: withDependencies {
        $0.dataManager = .mock(
          initialData: try! JSONEncoder().encode([
            Standup.mock,
            .engineeringMock,
            .designMock,
          ])
        )
      } operation: {
        AppModel(standupsList: StandupsListModel())
      }
    )
    .previewDisplayName("Happy path")

    Preview(
      message: """
        The preview demonstrates how you can start the application navigated to a very specific \
        screen just by constructing a piece of state. In particular we will start the app drilled \
        down to the detail screen of a standup, and then further drilled down to the record screen \
        for a new meeting.
        """
    ) {
      AppView(
        model: withDependencies {
          $0.dataManager = .mock(
            initialData: try! JSONEncoder().encode([
              Standup.mock,
              .engineeringMock,
              .designMock,
            ])
          )
        } operation: {
          AppModel(
            path: [
              .detail(StandupDetailModel(standup: .mock)),
              .record(RecordMeetingModel(standup: .mock)),
            ],
            standupsList: StandupsListModel()
          )
        }
      )
    }
    .previewDisplayName("Deep link record flow")
  }
}
