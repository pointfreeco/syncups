import CasePaths
import CustomDump
import DebugSnapshots
import Dependencies
import Foundation
import Sharing
import Synchronization
import Testing

@testable import SyncUps

@Suite(
  .dependencies {
    $0.continuousClock = TestClock()
    $0.date.now = Date(timeIntervalSince1970: 1_234_567_890)
    $0.soundEffectClient = .noop
    $0.uuid = .incrementing
  }
)
struct RecordMeetingTests {
  @Dependency(\.continuousClock, as: TestClock<Duration>.self) var clock

  @Test(
    .dependencies {
      $0.speechClient.authorizationStatus = { .denied }
    }
  )
  func timer() async throws {
    let soundEffectPlayCount = Mutex(0)

    try await withDependencies {
      $0.soundEffectClient.play = { soundEffectPlayCount.withLock { $0 += 1 } }

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

      let task = Task.immediate { await model.onTask() }

      // NB: This should not be necessary, but it doesn't seem like there is a better way to
      //     guarantee that the timer has started up. See this forum discussion for more information
      //     on the difficulties of testing async code in Swift:
      //     https://forums.swift.org/t/reliably-testing-code-that-adopts-swift-concurrency/57304
      try await Task.sleep(for: .milliseconds(300))

      expect(model) {
        $0.speakerIndex = 0
        $0.durationRemaining = .seconds(3)
      }

      await expect(model) {
        await clock.advance(by: .seconds(1))
      } changes: {
        $0.speakerIndex = 1
        $0.secondsElapsed = 1
        $0.durationRemaining = .seconds(2)
        #expect(soundEffectPlayCount.withLock { $0 } == 1)
      }

      await expect(model) {
        await clock.advance(by: .seconds(1))
      } changes: {
        $0.speakerIndex = 2
        $0.secondsElapsed = 2
        $0.durationRemaining = .seconds(1)
        #expect(soundEffectPlayCount.withLock { $0 } == 2)
      }

      await expect(model) {
        await clock.advance(by: .seconds(1))
      } changes: {
        $0.isDismissed = true
        $0.speakerIndex = 2
        $0.secondsElapsed = 3
        $0.durationRemaining = .seconds(0)
        #expect(soundEffectPlayCount.withLock { $0 } == 2)
      }

      await expect(model) {
        await clock.run()
        await task.value
      } changes: {
        $0.syncUp.meetings = [
          Meeting(
            id: Meeting.ID(UUID(0)),
            date: Date(timeIntervalSince1970: 1_234_567_890),
            transcript: ""
          )
        ]
        #expect(soundEffectPlayCount.withLock { $0 } == 2)
      }
    }
  }

  @Test(
    .dependencies {
      $0.continuousClock = ImmediateClock()
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
    }
  )
  func `finish meeting with speech recognition transcript`() async throws {
    let model = RecordMeetingModel(
      syncUp: Shared(
        value: SyncUp(
          id: SyncUp.ID(),
          attendees: [Attendee(id: Attendee.ID())],
          duration: .seconds(3)
        )
      )
    )

    await expect(model) {
      await model.onTask()
    } changes: {
      $0.isDismissed = true
      $0.secondsElapsed = 3
      $0.durationRemaining = .seconds(0)
      $0.syncUp.meetings = [
        Meeting(
          id: Meeting.ID(UUID(0)),
          date: Date(timeIntervalSince1970: 1_234_567_890),
          transcript: "I completed the project"
        )
      ]
    }
  }

  @Test(
    .dependencies {
      $0.speechClient.authorizationStatus = { .denied }
    }
  )
  func endMeetingSave() async throws {
    let syncUp = SyncUp.mock
    let model = RecordMeetingModel(syncUp: Shared(value: syncUp))

    Task.immediate { await model.onTask() }

    expect(model) {
      model.endMeetingButtonTapped()
    } changes: {
      $0.alert = .endMeeting(isDiscardable: true)
    }

    // TODO: should we be allowed to assert that state did not change?
    await withKnownIssue {
      await expect(model) {
        await clock.advance(by: .seconds(5))
      } changes: {
        // NB: State doesn't change while clock advances and alert is displayed.
        _ = $0
      }
    }

    try await expect(model) {
      let saveTask = Task.immediate { await model.alertButtonTapped(.confirmSave) }
      try await Task.sleep(for: .seconds(0.1))
      await clock.advance(by: .seconds(0.4))
      await saveTask.value
    } changes: {
      $0.isDismissed = true
      $0.syncUp.meetings.insert(
        Meeting(
          id: Meeting.ID(UUID(0)),
          date: Date(timeIntervalSince1970: 1_234_567_890),
          transcript: ""
        ),
        at: 0
      )
    }
  }

  @Test(
    .dependencies {
      $0.speechClient.authorizationStatus = { .denied }
    }
  )
  func endMeetingDiscard() async throws {
    let model = RecordMeetingModel(syncUp: Shared(value: .mock))

    Task.immediate { await model.onTask() }

    expect(model) {
      model.endMeetingButtonTapped()
    } changes: {
      $0.alert = .endMeeting(isDiscardable: true)
    }

    await expect(model) {
      await model.alertButtonTapped(.confirmDiscard)
    } changes: {
      $0.isDismissed = true
    }
  }

  @Test(
    .dependencies {
      $0.speechClient.authorizationStatus = { .denied }
    }
  )
  func nextSpeaker() async throws {
    let soundEffectPlayCount = Mutex(0)

    await withDependencies {
      $0.soundEffectClient.play = { soundEffectPlayCount.withLock { $0 += 1 } }
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

      Task.immediate { await model.onTask() }

      expect(model) {
        model.nextButtonTapped()
      } changes: {
        $0.speakerIndex = 1
        $0.secondsElapsed = 1
        $0.durationRemaining = .seconds(2)
        #expect(soundEffectPlayCount.withLock { $0 } == 1)
      }

      expect(model) {
        model.nextButtonTapped()
      } changes: {
        $0.speakerIndex = 2
        $0.secondsElapsed = 2
        $0.durationRemaining = .seconds(1)
        #expect(soundEffectPlayCount.withLock { $0 } == 2)
      }

      expect(model) {
        model.nextButtonTapped()
      } changes: {
        $0.alert = .endMeeting(isDiscardable: false)
      }

      // TODO: should we be allowed to assert that state did not change?
      await withKnownIssue {
        await expect(model) {
          await clock.advance(by: .seconds(5))
        } changes: {
          _ = $0
        }
      }

      await expect(model) {
        let saveTask = Task.immediate { await model.alertButtonTapped(.confirmSave) }
        await clock.run()
        await saveTask.value
      } changes: {
        $0.isDismissed = true
        $0.syncUp.meetings.insert(
          Meeting(
            id: Meeting.ID(UUID(0)),
            date: Date(timeIntervalSince1970: 1_234_567_890),
            transcript: ""
          ),
          at: 0
        )
        #expect(soundEffectPlayCount.withLock { $0 } == 2)
      }
    }
  }

  @Test(
    .dependencies {
      $0.continuousClock = ImmediateClock()
      $0.speechClient.authorizationStatus = { .authorized }
      $0.speechClient.startTask = { _ in
        AsyncThrowingStream {
          $0.yield(
            SpeechRecognitionResult(
              bestTranscription: Transcription(formattedString: "I completed the project"),
              isFinal: true
            )
          )
          $0.finish(throwing: SpeechRecognitionFailure())
        }
      }
    }
  )
  func `speech recognizer fails mid-meeting, user continues anyway`() async throws {
    let model = RecordMeetingModel(
      syncUp: Shared(
        value: SyncUp(
          id: SyncUp.ID(),
          attendees: [Attendee(id: Attendee.ID())],
          duration: .seconds(3)
        )
      )
    )


    let task = try await expect(model) {
      let task = Task.immediate { await model.onTask() }
      // NB: This should not be necessary, but it doesn't seem like there is a better way to
      //     guarantee that the timer has started up. See this forum discussion for more information
      //     on the difficulties of testing async code in Swift:
      //     https://forums.swift.org/t/reliably-testing-code-that-adopts-swift-concurrency/57304
      try await Task.sleep(for: .milliseconds(100))
      return task
    } changes: {
      $0.secondsElapsed = 1
      $0.durationRemaining = .seconds(2)
      $0.alert = .speechRecognizerFailed
    }

    await expect(model) {
      model.alert = nil  // NB: Simulate SwiftUI closing alert.
      await task.value
    } changes: {
      $0.isDismissed = true
      $0.alert = nil
      $0.secondsElapsed = 3
      $0.durationRemaining = .seconds(0)
      $0.syncUp.meetings.insert(
        Meeting(
          id: Meeting.ID(UUID(0)),
          date: Date(timeIntervalSince1970: 1_234_567_890),
          transcript: "I completed the project ❌"
        ),
        at: 0
      )
    }
  }

  @Test(
    .dependencies {
      $0.speechClient.authorizationStatus = { .authorized }
      $0.speechClient.startTask = { @Sendable _ in
        AsyncThrowingStream.finished(throwing: SpeechRecognitionFailure())
      }
    }
  )
  func `speech recognizer fails mid-meeting, user abandons meeting`() async throws {
    let model = RecordMeetingModel(
      syncUp: Shared(
        value: SyncUp(
          id: SyncUp.ID(),
          attendees: [Attendee(id: Attendee.ID())],
          duration: .seconds(3)
        )
      )
    )

    try await expect(model) {
      // NB: This should not be necessary, but it doesn't seem like there is a better way to
      //     guarantee that the timer has started up. See this forum discussion for more information
      //     on the difficulties of testing async code in Swift:
      //     https://forums.swift.org/t/reliably-testing-code-that-adopts-swift-concurrency/57304
      Task.immediate { await model.onTask() }
      try await Task.sleep(for: .milliseconds(100))
    } changes: {
      $0.alert = .speechRecognizerFailed
    }

    await expect(model) {
      await model.alertButtonTapped(.confirmDiscard)
    } changes: {
      $0.isDismissed = true
    }
  }
}

private struct SpeechRecognitionFailure: Error {}
