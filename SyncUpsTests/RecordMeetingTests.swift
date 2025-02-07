import CasePaths
import CustomDump
import Dependencies
import Foundation
import Sharing
import Synchronization
import Testing

@testable import SyncUps

@MainActor
@Suite struct RecordMeetingTests {
  let clock = TestClock()

  @Test func timer() async throws {
    let soundEffectPlayCount = Mutex(0)

    try await withDependencies {
      $0.continuousClock = clock
      $0.date.now = Date(timeIntervalSince1970: 1234567890)
      $0.soundEffectClient = .noop
      $0.soundEffectClient.play = { soundEffectPlayCount.withLock { $0 += 1 } }
      $0.speechClient.authorizationStatus = { .denied }
      $0.uuid = .incrementing
    } operation: {
      let model = RecordMeetingModel(
        syncUp: Shared(
          value: SyncUp(
            id: SyncUp.ID(),
            attendees: [
              Attendee(id: Attendee.ID()),
              Attendee(id: Attendee.ID()),
              Attendee(id: Attendee.ID()),
            ],
            duration: .seconds(3)
          )
        )
      )

      let task = Task { await model.onTask() }

      // NB: This should not be necessary, but it doesn't seem like there is a better way to
      //     guarantee that the timer has started up. See this forum discussion for more information
      //     on the difficulties of testing async code in Swift:
      //     https://forums.swift.org/t/reliably-testing-code-that-adopts-swift-concurrency/57304
      try await Task.sleep(for: .milliseconds(300))

      #expect(model.speakerIndex == 0)
      #expect(model.durationRemaining == .seconds(3))

      await clock.advance(by: .seconds(1))
      #expect(model.speakerIndex == 1)
      #expect(model.durationRemaining == .seconds(2))
      #expect(soundEffectPlayCount.withLock { $0 } == 1)

      await clock.advance(by: .seconds(1))
      #expect(model.speakerIndex == 2)
      #expect(model.durationRemaining == .seconds(1))
      #expect(soundEffectPlayCount.withLock { $0 } == 2)

      await clock.advance(by: .seconds(1))
      #expect(model.speakerIndex == 2)
      #expect(model.durationRemaining == .seconds(0))
      #expect(soundEffectPlayCount.withLock { $0 } == 2)

      await clock.run()
      await task.value

      #expect(soundEffectPlayCount.withLock { $0 } == 2)
    }
  }

  @Test func recordTranscript() async throws {
    await withDependencies {
      $0.continuousClock = ImmediateClock()
      $0.date.now = Date(timeIntervalSince1970: 1234567890)
      $0.soundEffectClient = .noop
      $0.speechClient.authorizationStatus = { .authorized }
      $0.speechClient.startTask = { @Sendable _ in
        AsyncThrowingStream { continuation in
          continuation.yield(
            SpeechRecognitionResult(
              bestTranscription: Transcription(formattedString: "I completed the project"),
              isFinal: true
            )
          )
          continuation.finish()
        }
      }
      $0.uuid = .incrementing
    } operation: {
      let model = RecordMeetingModel(
        syncUp: Shared(
          value: SyncUp(
            id: SyncUp.ID(),
            attendees: [Attendee(id: Attendee.ID())],
            duration: .seconds(3)
          )
        )
      )

      await model.onTask()

      expectNoDifference(
        model.syncUp.meetings,
        [
          Meeting(
            id: Meeting.ID(UUID(0)),
            date: Date(timeIntervalSince1970: 1234567890),
            transcript: "I completed the project"
          )
        ]
      )
    }
  }

  @Test func endMeetingSave() async throws {
    try await withDependencies {
      $0.continuousClock = clock
      $0.date.now = Date(timeIntervalSince1970: 1234567890)
      $0.soundEffectClient = .noop
      $0.speechClient.authorizationStatus = { .denied }
      $0.uuid = .incrementing
    } operation: {
      let syncUp = SyncUp.mock
      let model = RecordMeetingModel(syncUp: Shared(value: syncUp))

      let task = Task { await model.onTask() }

      model.endMeetingButtonTapped()

      let alert = try #require(model.alert)

      expectNoDifference(alert, .endMeeting(isDiscardable: true))

      await clock.advance(by: .seconds(5))

      #expect(model.speakerIndex == 0)
      #expect(model.durationRemaining == .seconds(60))

      let saveTask = Task {
        await model.alertButtonTapped(.confirmSave)
      }
      try await Task.sleep(for: .seconds(0.1))
      await clock.advance(by: .seconds(0.4))
      await saveTask.value
      #expect(model.isDismissed)

      task.cancel()
      await task.value
    }
  }

  @Test func endMeetingDiscard() async throws {
    try await withDependencies {
      $0.continuousClock = clock
      $0.soundEffectClient = .noop
      $0.speechClient.authorizationStatus = { .denied }
    } operation: {
      let model = RecordMeetingModel(syncUp: Shared(value: .mock))

      let task = Task { await model.onTask() }

      model.endMeetingButtonTapped()

      let alert = try #require(model.alert)

      expectNoDifference(alert, .endMeeting(isDiscardable: true))

      await model.alertButtonTapped(.confirmDiscard)

      task.cancel()
      await task.value
      #expect(model.isDismissed)
    }
  }

  @Test func nextSpeaker() async throws {
    let soundEffectPlayCount = Mutex(0)

    try await withDependencies {
      $0.continuousClock = ImmediateClock()
      $0.date.now = Date(timeIntervalSince1970: 1234567890)
      $0.soundEffectClient = .noop
      $0.soundEffectClient.play = { soundEffectPlayCount.withLock { $0 += 1 } }
      $0.speechClient.authorizationStatus = { .denied }
      $0.uuid = .incrementing
    } operation: {
      let model = RecordMeetingModel(
        syncUp: Shared(
          value: SyncUp(
            id: SyncUp.ID(),
            attendees: [
              Attendee(id: Attendee.ID()),
              Attendee(id: Attendee.ID()),
              Attendee(id: Attendee.ID()),
            ],
            duration: .seconds(3)
          )
        )
      )

      let task = Task { await model.onTask() }

      model.nextButtonTapped()

      #expect(model.speakerIndex == 1)
      #expect(model.durationRemaining == .seconds(2))
      #expect(soundEffectPlayCount.withLock { $0 } == 1)

      model.nextButtonTapped()

      #expect(model.speakerIndex == 2)
      #expect(model.durationRemaining == .seconds(1))
      #expect(soundEffectPlayCount.withLock { $0 } == 2)

      model.nextButtonTapped()

      let alert = try #require(model.alert)

      expectNoDifference(alert, .endMeeting(isDiscardable: false))

      await clock.advance(by: .seconds(5))

      #expect(model.speakerIndex == 2)
      #expect(model.durationRemaining == .seconds(1))
      #expect(soundEffectPlayCount.withLock { $0 } == 2)

      await model.alertButtonTapped(.confirmSave)

      #expect(soundEffectPlayCount.withLock { $0 } == 2)

      task.cancel()
      await task.value
    }
  }

  @Test func speechRecognitionFailure_Continue() async throws {
    try await withDependencies {
      $0.continuousClock = ImmediateClock()
      $0.date.now = Date(timeIntervalSince1970: 1234567890)
      $0.soundEffectClient = .noop
      $0.speechClient.authorizationStatus = { .authorized }
      $0.speechClient.startTask = { @Sendable _ in
        AsyncThrowingStream {
          $0.yield(
            SpeechRecognitionResult(
              bestTranscription: Transcription(formattedString: "I completed the project"),
              isFinal: true
            )
          )
          struct SpeechRecognitionFailure: Error {}
          $0.finish(throwing: SpeechRecognitionFailure())
        }
      }
      $0.uuid = .incrementing
    } operation: {
      let model = RecordMeetingModel(
        syncUp: Shared(
          value: SyncUp(
            id: SyncUp.ID(),
            attendees: [Attendee(id: Attendee.ID())],
            duration: .seconds(3)
          )
        )
      )

      let task = Task { await model.onTask() }

      // NB: This should not be necessary, but it doesn't seem like there is a better way to
      //     guarantee that the timer has started up. See this forum discussion for more information
      //     on the difficulties of testing async code in Swift:
      //     https://forums.swift.org/t/reliably-testing-code-that-adopts-swift-concurrency/57304
      try await Task.sleep(for: .milliseconds(100))

      let alert = try #require(model.alert)
      #expect(alert == .speechRecognizerFailed)

      model.alert = nil  // NB: Simulate SwiftUI closing alert.

      await task.value

      #expect(model.secondsElapsed == 3)
    }
  }

  @Test func speechRecognitionFailure_Discard() async throws {
    try await withDependencies {
      $0.continuousClock = clock
      $0.soundEffectClient = .noop
      $0.speechClient.authorizationStatus = { .authorized }
      $0.speechClient.startTask = { @Sendable _ in
        struct SpeechRecognitionFailure: Error {}
        return AsyncThrowingStream.finished(throwing: SpeechRecognitionFailure())
      }
    } operation: {
      let model = RecordMeetingModel(
        syncUp: Shared(
          value: SyncUp(
            id: SyncUp.ID(),
            attendees: [Attendee(id: Attendee.ID())],
            duration: .seconds(3)
          )
        )
      )

      Task { await model.onTask() }

      // NB: This should not be necessary, but it doesn't seem like there is a better way to
      //     guarantee that the timer has started up. See this forum discussion for more information
      //     on the difficulties of testing async code in Swift:
      //     https://forums.swift.org/t/reliably-testing-code-that-adopts-swift-concurrency/57304
      try await Task.sleep(for: .milliseconds(100))

      let alert = try #require(model.alert)
      #expect(alert == .speechRecognizerFailed)

      await model.alertButtonTapped(.confirmDiscard)
      model.alert = nil  // NB: Simulate SwiftUI closing alert.

      #expect(model.isDismissed)
    }
  }
}
