import Clocks
import CustomDump
import Dependencies
import IssueReporting
import SwiftUI
import SwiftUINavigation

@MainActor
@Observable
final class SyncUpDetailModel {
  var destination: Destination?
  var isDismissed = false
  var syncUp: SyncUp {
    didSet {
      onSyncUpUpdated(syncUp)
    }
  }

  @ObservationIgnored
  @Dependency(\.continuousClock) var clock
  @ObservationIgnored
  @Dependency(\.date.now) var now
  @ObservationIgnored
  @Dependency(\.openSettings) var openSettings
  @ObservationIgnored
  @Dependency(\.speechClient.authorizationStatus) var authorizationStatus
  @ObservationIgnored
  @Dependency(\.uuid) var uuid

  var onConfirmDeletion: () -> Void = unimplemented("onConfirmDeletion")
  var onMeetingTapped: (Meeting) -> Void = unimplemented("onMeetingTapped")
  var onMeetingStarted: (SyncUp) -> Void = unimplemented("onMeetingStarted")
  var onSyncUpUpdated: (SyncUp) -> Void = unimplemented("onSyncUpUpdated")

  @CasePathable
  @dynamicMemberLookup
  enum Destination {
    case alert(AlertState<AlertAction>)
    case edit(SyncUpFormModel)
  }
  enum AlertAction {
    case confirmDeletion
    case continueWithoutRecording
    case openSettings
  }

  init(
    destination: Destination? = nil,
    syncUp: SyncUp
  ) {
    self.destination = destination
    self.syncUp = syncUp
  }

  func deleteMeetings(atOffsets indices: IndexSet) {
    syncUp.meetings.remove(atOffsets: indices)
  }

  func meetingTapped(_ meeting: Meeting) {
    onMeetingTapped(meeting)
  }

  func deleteButtonTapped() {
    destination = .alert(.deleteSyncUp)
  }

  func alertButtonTapped(_ action: AlertAction?) async {
    switch action {
    case .confirmDeletion?:
      onConfirmDeletion()
      isDismissed = true

    case .continueWithoutRecording?:
      onMeetingStarted(syncUp)

    case .openSettings?:
      await openSettings()

    case nil:
      break
    }
  }

  func editButtonTapped() {
    destination = .edit(
      withDependencies(from: self) {
        SyncUpFormModel(syncUp: self.syncUp)
      }
    )
  }

  func cancelEditButtonTapped() {
    destination = nil
  }

  func doneEditingButtonTapped() {
    guard case let .edit(model) = destination
    else { return }

    syncUp = model.syncUp
    destination = nil
  }

  func startMeetingButtonTapped() {
    switch authorizationStatus() {
    case .notDetermined, .authorized:
      onMeetingStarted(syncUp)

    case .denied:
      destination = .alert(.speechRecognitionDenied)

    case .restricted:
      destination = .alert(.speechRecognitionRestricted)

    @unknown default:
      break
    }
  }
}

extension SyncUpDetailModel: HashableObject {}

struct SyncUpDetailView: View {
  @State var model: SyncUpDetailModel

  var body: some View {
    List {
      Section {
        Button {
          model.startMeetingButtonTapped()
        } label: {
          Label("Start Meeting", systemImage: "timer")
            .font(.headline)
            .foregroundColor(.accentColor)
        }
        HStack {
          Label("Length", systemImage: "clock")
          Spacer()
          Text(model.syncUp.duration.formatted(.units()))
        }

        HStack {
          Label("Theme", systemImage: "paintpalette")
          Spacer()
          Text(model.syncUp.theme.name)
            .padding(4)
            .foregroundColor(model.syncUp.theme.accentColor)
            .background(model.syncUp.theme.mainColor)
            .cornerRadius(4)
        }
      } header: {
        Text("Sync-up Info")
      }

      if !model.syncUp.meetings.isEmpty {
        Section {
          ForEach(model.syncUp.meetings) { meeting in
            Button {
              model.meetingTapped(meeting)
            } label: {
              HStack {
                Image(systemName: "calendar")
                Text(meeting.date, style: .date)
                Text(meeting.date, style: .time)
              }
            }
          }
          .onDelete { indices in
            model.deleteMeetings(atOffsets: indices)
          }
        } header: {
          Text("Past meetings")
        }
      }

      Section {
        ForEach(model.syncUp.attendees) { attendee in
          Label(attendee.name, systemImage: "person")
        }
      } header: {
        Text("Attendees")
      }

      Section {
        Button("Delete") {
          model.deleteButtonTapped()
        }
        .foregroundColor(.red)
        .frame(maxWidth: .infinity)
      }
    }
    .navigationTitle(model.syncUp.title)
    .toolbar {
      Button("Edit") {
        model.editButtonTapped()
      }
    }
    .alert($model.destination.alert) { action in
      await model.alertButtonTapped(action)
    }
    .sheet(item: $model.destination.edit) { editModel in
      NavigationStack {
        SyncUpFormView(model: editModel)
          .navigationTitle(model.syncUp.title)
          .toolbar {
            ToolbarItem(placement: .cancellationAction) {
              Button("Cancel") {
                model.cancelEditButtonTapped()
              }
            }
            ToolbarItem(placement: .confirmationAction) {
              Button("Done") {
                model.doneEditingButtonTapped()
              }
            }
          }
      }
    }
  }
}

extension AlertState where Action == SyncUpDetailModel.AlertAction {
  static let deleteSyncUp = Self {
    TextState("Delete?")
  } actions: {
    ButtonState(role: .destructive, action: .confirmDeletion) {
      TextState("Yes")
    }
    ButtonState(role: .cancel) {
      TextState("Nevermind")
    }
  } message: {
    TextState("Are you sure you want to delete this sync-up?")
  }

  static let speechRecognitionDenied = Self {
    TextState("Speech recognition denied")
  } actions: {
    ButtonState(action: .continueWithoutRecording) {
      TextState("Continue without recording")
    }
    ButtonState(action: .openSettings) {
      TextState("Open settings")
    }
    ButtonState(role: .cancel) {
      TextState("Cancel")
    }
  } message: {
    TextState(
      """
      You previously denied speech recognition and so your meeting meeting will not be \
      recorded. You can enable speech recognition in settings, or you can continue without \
      recording.
      """
    )
  }

  static let speechRecognitionRestricted = Self {
    TextState("Speech recognition restricted")
  } actions: {
    ButtonState(action: .continueWithoutRecording) {
      TextState("Continue without recording")
    }
    ButtonState(role: .cancel) {
      TextState("Cancel")
    }
  } message: {
    TextState(
      """
      Your device does not support speech recognition and so your meeting will not be recorded.
      """
    )
  }
}

struct MeetingView: View {
  let meeting: Meeting
  let syncUp: SyncUp

  var body: some View {
    ScrollView {
      VStack(alignment: .leading) {
        Divider()
          .padding(.bottom)
        Text("Attendees")
          .font(.headline)
        ForEach(self.syncUp.attendees) { attendee in
          Text(attendee.name)
        }
        Text("Transcript")
          .font(.headline)
          .padding(.top)
        Text(self.meeting.transcript)
      }
    }
    .navigationTitle(Text(self.meeting.date, style: .date))
    .padding()
  }
}

struct SyncUpDetail_Previews: PreviewProvider {
  static var previews: some View {
    Preview(
      message: """
        This preview demonstrates the "happy path" of the application where everything works \
        perfectly. You can start a meeting, wait a few moments, end the meeting, and you will \
        see that a new transcription was added to the past meetings. The transcript will consist \
        of some "lorem ipsum" text because a mock speech recongizer is used for Xcode previews.
        """
    ) {
      NavigationStack {
        SyncUpDetailView(model: SyncUpDetailModel(syncUp: .mock))
      }
    }
    .previewDisplayName("Happy path")

    Preview(
      message: """
        This preview demonstrates an "unhappy path" of the application where the speech \
        recognizer mysteriously fails after 2 seconds of recording. This gives us an opportunity \
        to see how the application deals with this rare occurrence. To see the behavior, run the \
        preview, tap the "Start Meeting" button and wait 2 seconds.
        """
    ) {
      NavigationStack {
        SyncUpDetailView(
          model: withDependencies {
            $0.speechClient = .fail(after: .seconds(2))
          } operation: {
            SyncUpDetailModel(syncUp: .mock)
          }
        )
      }
    }
    .previewDisplayName("Speech recognition failed")

    Preview(
      message: """
        This preview demonstrates how the feature behaves when access to speech recognition has \
        been previously denied by the user. Tap the "Start Meeting" button to see how we handle \
        that situation.
        """
    ) {
      NavigationStack {
        SyncUpDetailView(
          model: withDependencies {
            $0.speechClient.authorizationStatus = { .denied }
          } operation: {
            SyncUpDetailModel(syncUp: .mock)
          }
        )
      }
    }
    .previewDisplayName("Speech recognition denied")

    Preview(
      message: """
        This preview demonstrates how the feature behaves when the device restricts access to \
        speech recognition APIs. Tap the "Start Meeting" button to see how we handle that \
        situation.
        """
    ) {
      NavigationStack {
        SyncUpDetailView(
          model: withDependencies {
            $0.speechClient.authorizationStatus = { .restricted }
          } operation: {
            SyncUpDetailModel(syncUp: .mock)
          }
        )
      }
    }
    .previewDisplayName("Speech recognition restricted")
  }
}
