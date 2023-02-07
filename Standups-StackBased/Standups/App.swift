import Combine
import Dependencies
import SwiftUI

@MainActor
class AppModel: ObservableObject {
  @Published var path: [Destination] {
    didSet { self.bind() }
  }
  @Published var standupsList: StandupsListModel {
    didSet { self.bind() }
  }

  @Dependency(\.continuousClock) var clock
  @Dependency(\.date.now) var now
  @Dependency(\.uuid) var uuid

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
      guard let self else { return }

      self.path.append(
        .detail(
          StandupDetailModel(standup: standup)
        )
      )
    }

    for destination in self.path {
      switch destination {
      case let .detail(detailModel):
        detailModel.onMeetingStarted = { [weak self] standup in
          guard let self else { return }

          self.path.append(
            .record(
              RecordMeetingModel(standup: standup)
            )
          )
        }
        detailModel.onConfirmDeletion = { [weak detailModel, weak self] in
          guard let self, let detailModel else { return }
          self.standupsList.standups.remove(id: detailModel.standup.id)
          _ = self.path.popLast()
        }
        detailModel.onMeetingTapped = { [weak detailModel, weak self] meeting in
          guard let self, let detailModel else { return }

          self.path.append(.meeting(meeting, standup: detailModel.standup))
        }

        self.detailCancellable = detailModel.$standup
          .sink { [weak self] standup in
          self?.standupsList.standups[id: standup.id] = standup
        }

      case .meeting:
        break

      case let .record(recordModel):
        recordModel.onDiscardMeeting = { [weak self] in
          guard let self else { return }
          _ = self.path.popLast()
        }
        recordModel.onMeetingFinished = { [weak self] transcript in
          guard let self else { return }

          let meeting = Meeting(
            id: Meeting.ID(self.uuid()),
            date: self.now,
            transcript: transcript
          )

          guard
            case let .some(.detail(detailModel)) = self.path.dropLast().last
          else {
            return
          }

          _ = self.path.popLast()
          let didCancel = (try? await self.clock.sleep(for: .milliseconds(400))) == nil
          _ = withAnimation(didCancel ? nil : .default) {
            detailModel.standup.meetings.insert(meeting, at: 0)
          }
        }
        break
      }
    }
  }
}

struct AppView: View {
  @ObservedObject var model: AppModel

  var body: some View {
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
