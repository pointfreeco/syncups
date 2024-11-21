import CasePaths
import CustomDump
import Dependencies
import Foundation
import Sharing
import Testing

@testable import SyncUps

@MainActor
@Suite
struct RecordMeetingTests {
  let clock = TestClock()
  @Shared(.path) var path

  @Test
  func timer() async throws {
    let soundEffectPlayCount = LockIsolated(0)

    let model = withDependencies {
      $0.continuousClock = clock
      $0.date.now = Date(timeIntervalSince1970: 1234567890)
      $0.soundEffectClient = .noop
      $0.soundEffectClient.play = { soundEffectPlayCount.withValue { $0 += 1 } }
      $0.speechClient.authorizationStatus = { .denied }
      $0.uuid = .incrementing
    } operation: {
      RecordMeetingModel(
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
    }

    let task = Task {
      await model.task()
    }

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
    #expect(soundEffectPlayCount.value == 1)

    await clock.advance(by: .seconds(1))
    #expect(model.speakerIndex == 2)
    #expect(model.durationRemaining == .seconds(1))
    #expect(soundEffectPlayCount.value == 2)

    await clock.advance(by: .seconds(1))
    #expect(model.speakerIndex == 2)
    #expect(model.durationRemaining == .seconds(0))
    #expect(soundEffectPlayCount.value == 2)

    await task.value

    #expect(soundEffectPlayCount.value == 2)
  }

  @Test
  func recordTranscript() async throws {
    let model = withDependencies {
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
      RecordMeetingModel(
        syncUp: Shared(
          value: SyncUp(
            id: SyncUp.ID(),
            attendees: [Attendee(id: Attendee.ID())],
            duration: .seconds(3)
          )
        )
      )
    }

    await model.task()

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

  @Test
  func endMeetingSave() async throws {
    let syncUp = SyncUp.mock
    $path.withLock { $0 = [.detail(id: syncUp.id), .record(id: syncUp.id)] }

    let model = withDependencies {
      $0.continuousClock = clock
      $0.date.now = Date(timeIntervalSince1970: 1234567890)
      $0.soundEffectClient = .noop
      $0.speechClient.authorizationStatus = { .denied }
      $0.uuid = .incrementing
    } operation: {
      RecordMeetingModel(syncUp: Shared(value: syncUp))
    }

    let task = Task {
      await model.task()
    }

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
    #expect(path == [.detail(id: syncUp.id)])

    task.cancel()
    await task.value
  }

  @Test
  func endMeetingDiscard() async throws {
    let syncUp = SyncUp.mock
    $path.withLock { $0 = [.detail(id: syncUp.id), .record(id: syncUp.id)] }

    let model = withDependencies {
      $0.continuousClock = clock
      $0.soundEffectClient = .noop
      $0.speechClient.authorizationStatus = { .denied }
    } operation: {
      RecordMeetingModel(syncUp: Shared(value: syncUp))
    }

    let task = Task {
      await model.task()
    }

    model.endMeetingButtonTapped()

    let alert = try #require(model.alert)

    expectNoDifference(alert, .endMeeting(isDiscardable: true))

    await model.alertButtonTapped(.confirmDiscard)

    task.cancel()
    await task.value
    #expect(path == [.detail(id: syncUp.id)])
  }

  @Test
  func nextSpeaker() async throws {
    let soundEffectPlayCount = LockIsolated(0)

    let model = withDependencies {
      $0.continuousClock = clock
      $0.date.now = Date(timeIntervalSince1970: 1234567890)
      $0.soundEffectClient = .noop
      $0.soundEffectClient.play = { soundEffectPlayCount.withValue { $0 += 1 } }
      $0.speechClient.authorizationStatus = { .denied }
      $0.uuid = .incrementing

    } operation: {
      RecordMeetingModel(
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
    }

    let task = Task {
      await model.task()
    }

    model.nextButtonTapped()

    #expect(model.speakerIndex == 1)
    #expect(model.durationRemaining == .seconds(2))
    #expect(soundEffectPlayCount.value == 1)

    model.nextButtonTapped()

    #expect(model.speakerIndex == 2)
    #expect(model.durationRemaining == .seconds(1))
    #expect(soundEffectPlayCount.value == 2)

    model.nextButtonTapped()

    let alert = try #require(model.alert)

    expectNoDifference(alert, .endMeeting(isDiscardable: false))

    await clock.advance(by: .seconds(5))

    #expect(model.speakerIndex == 2)
    #expect(model.durationRemaining == .seconds(1))
    #expect(soundEffectPlayCount.value == 2)

    await model.alertButtonTapped(.confirmSave)

    #expect(soundEffectPlayCount.value == 2)

    task.cancel()
    await task.value
  }

  @Test
  func speechRecognitionFailure_Continue() async throws {
    let model = withDependencies {
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
      RecordMeetingModel(
        syncUp: Shared(
          value: SyncUp(
            id: SyncUp.ID(),
            attendees: [Attendee(id: Attendee.ID())],
            duration: .seconds(3)
          )
        )
      )
    }

    let task = Task {
      await model.task()
    }

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

  @Test
  func speechRecognitionFailure_Discard() async throws {
    let syncUp = SyncUp(
      id: SyncUp.ID(),
      attendees: [Attendee(id: Attendee.ID())],
      duration: .seconds(3)
    )
    $path.withLock { $0 = [.detail(id: syncUp.id), .record(id: syncUp.id)] }

    let model = withDependencies {
      $0.continuousClock = clock
      $0.soundEffectClient = .noop
      $0.speechClient.authorizationStatus = { .authorized }
      $0.speechClient.startTask = { @Sendable _ in
        struct SpeechRecognitionFailure: Error {}
        return AsyncThrowingStream.finished(throwing: SpeechRecognitionFailure())
      }
    } operation: {
      RecordMeetingModel(syncUp: Shared(value: syncUp))
    }

    Task {
      await model.task()
    }

    // NB: This should not be necessary, but it doesn't seem like there is a better way to
    //     guarantee that the timer has started up. See this forum discussion for more information
    //     on the difficulties of testing async code in Swift:
    //     https://forums.swift.org/t/reliably-testing-code-that-adopts-swift-concurrency/57304
    try await Task.sleep(for: .milliseconds(100))

    let alert = try #require(model.alert)
    #expect(alert == .speechRecognizerFailed)

    await model.alertButtonTapped(.confirmDiscard)
    model.alert = nil  // NB: Simulate SwiftUI closing alert.

    #expect(path == [.detail(id: syncUp.id)])
  }
}
