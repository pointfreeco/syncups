import Clocks
import Dependencies
import IssueReporting
import Speech
import SwiftUI
import SwiftUINavigation

@MainActor
@Observable
final class RecordMeetingModel {
  var destination: Destination?
  var isDismissed = false
  var secondsElapsed = 0
  var speakerIndex = 0
  let syncUp: SyncUp
  private var transcript = ""

  @ObservationIgnored
  @Dependency(\.continuousClock) var clock
  @ObservationIgnored
  @Dependency(\.soundEffectClient) var soundEffectClient
  @ObservationIgnored
  @Dependency(\.speechClient) var speechClient

  var onMeetingFinished: (_ transcript: String) async -> Void = unimplemented("onMeetingFinished")

  @CasePathable
  @dynamicMemberLookup
  enum Destination {
    case alert(AlertState<AlertAction>)
  }

  enum AlertAction {
    case confirmSave
    case confirmDiscard
  }

  init(
    destination: Destination? = nil,
    syncUp: SyncUp
  ) {
    self.destination = destination
    self.syncUp = syncUp
  }

  var durationRemaining: Duration {
    syncUp.duration - .seconds(secondsElapsed)
  }

  var isAlertOpen: Bool {
    switch destination {
    case .alert:
      return true
    case .none:
      return false
    }
  }

  func nextButtonTapped() {
    guard speakerIndex < syncUp.attendees.count - 1
    else {
      destination = .alert(.endMeeting(isDiscardable: false))
      return
    }

    speakerIndex += 1
    soundEffectClient.play()
    secondsElapsed = speakerIndex * Int(syncUp.durationPerAttendee.components.seconds)
  }

  func endMeetingButtonTapped() {
    destination = .alert(.endMeeting(isDiscardable: true))
  }

  func alertButtonTapped(_ action: AlertAction?) async {
    switch action {
    case .confirmSave?:
      await finishMeeting()
    case .confirmDiscard?:
      isDismissed = true
    case nil:
      break
    }
  }

  func task() async {
    soundEffectClient.load(fileName: "ding.wav")

    let authorization =
      await speechClient.authorizationStatus() == .notDetermined
      ? speechClient.requestAuthorization()
      : speechClient.authorizationStatus()

    await withTaskGroup(of: Void.self) { group in
      if authorization == .authorized {
        group.addTask {
          await self.startSpeechRecognition()
        }
      }
      group.addTask {
        await self.startTimer()
      }
    }
  }

  private func startSpeechRecognition() async {
    do {
      let speechTask = await speechClient.startTask(
        request: SFSpeechAudioBufferRecognitionRequest()
      )
      for try await result in speechTask {
        transcript = result.bestTranscription.formattedString
      }
    } catch {
      if !transcript.isEmpty {
        transcript += " ❌"
      }
      destination = .alert(.speechRecognizerFailed)
    }
  }

  private func startTimer() async {
    for await _ in clock.timer(interval: .seconds(1)) where !isAlertOpen {
      secondsElapsed += 1

      let secondsPerAttendee = Int(syncUp.durationPerAttendee.components.seconds)
      if secondsElapsed.isMultiple(of: secondsPerAttendee) {
        if speakerIndex == syncUp.attendees.count - 1 {
          await finishMeeting()
          break
        }
        speakerIndex += 1
        soundEffectClient.play()
      }
    }
  }

  private func finishMeeting() async {
    isDismissed = true
    await onMeetingFinished(transcript)
  }
}

extension RecordMeetingModel: HashableObject {}

extension AlertState where Action == RecordMeetingModel.AlertAction {
  static func endMeeting(isDiscardable: Bool) -> Self {
    Self {
      TextState("End meeting?")
    } actions: {
      ButtonState(action: .confirmSave) {
        TextState("Save and end")
      }
      if isDiscardable {
        ButtonState(role: .destructive, action: .confirmDiscard) {
          TextState("Discard")
        }
      }
      ButtonState(role: .cancel) {
        TextState("Resume")
      }
    } message: {
      TextState("You are ending the meeting early. What would you like to do?")
    }
  }

  static let speechRecognizerFailed = Self {
    TextState("Speech recognition failure")
  } actions: {
    ButtonState(role: .cancel) {
      TextState("Continue meeting")
    }
    ButtonState(role: .destructive, action: .confirmDiscard) {
      TextState("Discard meeting")
    }
  } message: {
    TextState(
      """
      The speech recognizer has failed for some reason and so your meeting will no longer be \
      recorded. What do you want to do?
      """)
  }
}

struct RecordMeetingView: View {
  @State var model: RecordMeetingModel
  @Environment(\.dismiss) var dismiss

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 16)
        .fill(self.model.syncUp.theme.mainColor)

      VStack {
        MeetingHeaderView(
          secondsElapsed: self.model.secondsElapsed,
          durationRemaining: self.model.durationRemaining,
          theme: self.model.syncUp.theme
        )
        MeetingTimerView(
          syncUp: self.model.syncUp,
          speakerIndex: self.model.speakerIndex
        )
        MeetingFooterView(
          syncUp: self.model.syncUp,
          nextButtonTapped: { self.model.nextButtonTapped() },
          speakerIndex: self.model.speakerIndex
        )
      }
    }
    .padding()
    .foregroundColor(self.model.syncUp.theme.accentColor)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("End meeting") {
          self.model.endMeetingButtonTapped()
        }
      }
    }
    .navigationBarBackButtonHidden(true)
    .alert(self.$model.destination.alert) { action in
      await self.model.alertButtonTapped(action)
    }
    .task { await self.model.task() }
    .onChange(of: self.model.isDismissed) { _, _ in self.dismiss() }
  }
}

struct MeetingHeaderView: View {
  let secondsElapsed: Int
  let durationRemaining: Duration
  let theme: Theme

  var body: some View {
    VStack {
      ProgressView(value: progress)
        .progressViewStyle(MeetingProgressViewStyle(theme: theme))
      HStack {
        VStack(alignment: .leading) {
          Text("Time Elapsed")
            .font(.caption)
          Label(
            Duration.seconds(secondsElapsed).formatted(.units()),
            systemImage: "hourglass.bottomhalf.fill"
          )
        }
        Spacer()
        VStack(alignment: .trailing) {
          Text("Time Remaining")
            .font(.caption)
          Label(durationRemaining.formatted(.units()), systemImage: "hourglass.tophalf.fill")
            .font(.body.monospacedDigit())
            .labelStyle(.trailingIcon)
        }
      }
    }
    .padding([.top, .horizontal])
  }

  private var totalDuration: Duration {
    .seconds(secondsElapsed) + durationRemaining
  }

  private var progress: Double {
    guard totalDuration > .seconds(0) else { return 0 }
    return Double(secondsElapsed) / Double(totalDuration.components.seconds)
  }
}

struct MeetingProgressViewStyle: ProgressViewStyle {
  var theme: Theme

  func makeBody(configuration: Configuration) -> some View {
    ZStack {
      RoundedRectangle(cornerRadius: 10.0)
        .fill(theme.accentColor)
        .frame(height: 20.0)

      ProgressView(configuration)
        .tint(theme.mainColor)
        .frame(height: 12.0)
        .padding(.horizontal)
    }
  }
}

struct MeetingTimerView: View {
  let syncUp: SyncUp
  let speakerIndex: Int

  var body: some View {
    Circle()
      .strokeBorder(lineWidth: 24)
      .overlay {
        VStack {
          Group {
            if speakerIndex < syncUp.attendees.count {
              Text(syncUp.attendees[speakerIndex].name)
            } else {
              Text("Someone")
            }
          }
          .font(.title)
          Text("is speaking")
          Image(systemName: "mic.fill")
            .font(.largeTitle)
            .padding(.top)
        }
        .foregroundStyle(syncUp.theme.accentColor)
      }
      .overlay {
        ForEach(Array(syncUp.attendees.enumerated()), id: \.element.id) { index, attendee in
          if index < speakerIndex + 1 {
            SpeakerArc(totalSpeakers: syncUp.attendees.count, speakerIndex: index)
              .rotation(Angle(degrees: -90))
              .stroke(syncUp.theme.mainColor, lineWidth: 12)
          }
        }
      }
      .padding(.horizontal)
  }
}

struct SpeakerArc: Shape {
  let totalSpeakers: Int
  let speakerIndex: Int

  func path(in rect: CGRect) -> Path {
    let diameter = min(rect.size.width, rect.size.height) - 24.0
    let radius = diameter / 2.0
    let center = CGPoint(x: rect.midX, y: rect.midY)
    return Path { path in
      path.addArc(
        center: center,
        radius: radius,
        startAngle: startAngle,
        endAngle: endAngle,
        clockwise: false
      )
    }
  }

  private var degreesPerSpeaker: Double {
    360.0 / Double(totalSpeakers)
  }
  private var startAngle: Angle {
    Angle(degrees: degreesPerSpeaker * Double(speakerIndex) + 1.0)
  }
  private var endAngle: Angle {
    Angle(degrees: startAngle.degrees + degreesPerSpeaker - 1.0)
  }
}

struct MeetingFooterView: View {
  let syncUp: SyncUp
  var nextButtonTapped: () -> Void
  let speakerIndex: Int

  var body: some View {
    VStack {
      HStack {
        if speakerIndex < syncUp.attendees.count - 1 {
          Text("Speaker \(speakerIndex + 1) of \(syncUp.attendees.count)")
        } else {
          Text("No more speakers.")
        }
        Spacer()
        Button(action: nextButtonTapped) {
          Image(systemName: "forward.fill")
        }
      }
    }
    .padding([.bottom, .horizontal])
  }
}

struct RecordMeeting_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      RecordMeetingView(
        model: RecordMeetingModel(syncUp: .mock)
      )
    }
    .previewDisplayName("Happy path")

    Preview(
      message: """
        This preview demonstrates how the feature behaves when the speech recognizer emits a \
        failure after 2 seconds of transcribing.
        """
    ) {
      NavigationStack {
        RecordMeetingView(
          model: withDependencies {
            $0.speechClient = .fail(after: .seconds(2))
          } operation: {
            RecordMeetingModel(syncUp: .mock)
          }
        )
      }
    }
    .previewDisplayName("Speech failure after 2 secs")
  }
}
