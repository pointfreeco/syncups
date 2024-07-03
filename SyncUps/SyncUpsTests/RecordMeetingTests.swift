import CasePaths
import CustomDump
import Dependencies

@testable import SyncUps

#if canImport(Testing)
  import Testing

  extension BaseTestSuite {
    @Suite
    @MainActor
    struct RecordMeetingTests {}
  }
  extension BaseTestSuite.RecordMeetingTests {
    @Test
    func timer() async throws {
      let clock = TestClock()
      let soundEffectPlayCount = LockIsolated(0)

      let model = withDependencies {
        $0.continuousClock = clock
        $0.soundEffectClient = .noop
        $0.soundEffectClient.play = { soundEffectPlayCount.withValue { $0 += 1 } }
        $0.speechClient.authorizationStatus = { .denied }
      } operation: {
        RecordMeetingModel(
          syncUp: SyncUp(
            id: SyncUp.ID(),
            attendees: [
              Attendee(id: Attendee.ID()),
              Attendee(id: Attendee.ID()),
              Attendee(id: Attendee.ID()),
            ],
            duration: .seconds(3)
          )
        )
      }

      try await confirmation { confirmation in
        model.onMeetingFinished = {
          #expect($0 == "")
          confirmation()
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
    }

    @Test
    func recordTranscript() async throws {
      let model = withDependencies {
        $0.continuousClock = ImmediateClock()
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
      } operation: {
        RecordMeetingModel(
          syncUp: SyncUp(
            id: SyncUp.ID(),
            attendees: [Attendee(id: Attendee.ID())],
            duration: .seconds(3)
          )
        )
      }

      await confirmation { confirmation in
        model.onMeetingFinished = {
          #expect($0 == "I completed the project")
          confirmation()
        }

        await model.task()
      }
    }

    @Test
    func endMeetingSave() async throws {
      let clock = TestClock()

      let model = withDependencies {
        $0.continuousClock = clock
        $0.soundEffectClient = .noop
        $0.speechClient.authorizationStatus = { .denied }
      } operation: {
        RecordMeetingModel(syncUp: .mock)
      }

      try await confirmation { confirmation in
        model.onMeetingFinished = {
          #expect($0 == "")
          confirmation()
        }

        let task = Task {
          await model.task()
        }

        model.endMeetingButtonTapped()

        let alert = try #require(model.destination?.alert)

        expectNoDifference(alert, .endMeeting(isDiscardable: true))

        await clock.advance(by: .seconds(5))

        #expect(model.speakerIndex == 0)
        #expect(model.durationRemaining == .seconds(60))

        await model.alertButtonTapped(.confirmSave)

        task.cancel()
        await task.value
      }
    }

    @Test
    func endMeetingDiscard() async throws {
      let clock = TestClock()

      let model = withDependencies {
        $0.continuousClock = clock
        $0.soundEffectClient = .noop
        $0.speechClient.authorizationStatus = { .denied }
      } operation: {
        RecordMeetingModel(syncUp: .mock)
      }

      let task = Task {
        await model.task()
      }

      model.endMeetingButtonTapped()

      let alert = try #require(model.destination?.alert)

      expectNoDifference(alert, .endMeeting(isDiscardable: true))

      await model.alertButtonTapped(.confirmDiscard)

      task.cancel()
      await task.value
      #expect(model.isDismissed == true)
    }

    @Test
    func nextSpeaker() async throws {
      let clock = TestClock()
      let soundEffectPlayCount = LockIsolated(0)

      let model = withDependencies {
        $0.continuousClock = clock
        $0.soundEffectClient = .noop
        $0.soundEffectClient.play = { soundEffectPlayCount.withValue { $0 += 1 } }
        $0.speechClient.authorizationStatus = { .denied }

      } operation: {
        RecordMeetingModel(
          syncUp: SyncUp(
            id: SyncUp.ID(),
            attendees: [
              Attendee(id: Attendee.ID()),
              Attendee(id: Attendee.ID()),
              Attendee(id: Attendee.ID()),
            ],
            duration: .seconds(3)
          )
        )
      }

      try await confirmation { confirmation in
        model.onMeetingFinished = {
          #expect($0 == "")
          confirmation()
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

        let alert = try #require(model.destination?.alert)

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
    }

    @Test
    func speechRecognitionFailure_Continue() async throws {
      let model = withDependencies {
        $0.continuousClock = ImmediateClock()
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
      } operation: {
        RecordMeetingModel(
          syncUp: SyncUp(
            id: SyncUp.ID(),
            attendees: [Attendee(id: Attendee.ID())],
            duration: .seconds(3)
          )
        )
      }

      try await confirmation { confirmation in
        model.onMeetingFinished = { transcript in
          #expect(transcript == "I completed the project ❌")
          confirmation()
        }

        let task = Task {
          await model.task()
        }

        // NB: This should not be necessary, but it doesn't seem like there is a better way to
        //     guarantee that the timer has started up. See this forum discussion for more information
        //     on the difficulties of testing async code in Swift:
        //     https://forums.swift.org/t/reliably-testing-code-that-adopts-swift-concurrency/57304
        try await Task.sleep(for: .milliseconds(100))

        let alert = try #require(model.destination?.alert)
        #expect(alert == .speechRecognizerFailed)

        model.destination = nil  // NB: Simulate SwiftUI closing alert.

        await task.value

        #expect(model.secondsElapsed == 3)
      }
    }

    @Test
    func speechRecognitionFailure_Discard() async throws {
      let clock = TestClock()

      let model = withDependencies {
        $0.continuousClock = clock
        $0.soundEffectClient = .noop
        $0.speechClient.authorizationStatus = { .authorized }
        $0.speechClient.startTask = { @Sendable _ in
          struct SpeechRecognitionFailure: Error {}
          return AsyncThrowingStream.finished(throwing: SpeechRecognitionFailure())
        }
      } operation: {
        RecordMeetingModel(
          syncUp: SyncUp(
            id: SyncUp.ID(),
            attendees: [Attendee(id: Attendee.ID())],
            duration: .seconds(3)
          )
        )
      }

      Task {
        await model.task()
      }

      // NB: This should not be necessary, but it doesn't seem like there is a better way to
      //     guarantee that the timer has started up. See this forum discussion for more information
      //     on the difficulties of testing async code in Swift:
      //     https://forums.swift.org/t/reliably-testing-code-that-adopts-swift-concurrency/57304
      try await Task.sleep(for: .milliseconds(100))

      let alert = try #require(model.destination?.alert)
      #expect(alert == .speechRecognizerFailed)

      await model.alertButtonTapped(.confirmDiscard)
      model.destination = nil  // NB: Simulate SwiftUI closing alert.

      #expect(model.isDismissed == true)
    }
  }
#else
  import XCTest

  final class RecordMeetingTests: BaseTestCase {
    @MainActor
    func testTimer() async throws {
      let clock = TestClock()
      let soundEffectPlayCount = LockIsolated(0)

      let model = withDependencies {
        $0.continuousClock = clock
        $0.soundEffectClient = .noop
        $0.soundEffectClient.play = { soundEffectPlayCount.withValue { $0 += 1 } }
        $0.speechClient.authorizationStatus = { .denied }
      } operation: {
        RecordMeetingModel(
          syncUp: SyncUp(
            id: SyncUp.ID(),
            attendees: [
              Attendee(id: Attendee.ID()),
              Attendee(id: Attendee.ID()),
              Attendee(id: Attendee.ID()),
            ],
            duration: .seconds(3)
          )
        )
      }

      let onMeetingFinishedExpectation = self.expectation(description: "onMeetingFinished")
      model.onMeetingFinished = {
        XCTAssertEqual($0, "")
        onMeetingFinishedExpectation.fulfill()
      }

      let task = Task {
        await model.task()
      }

      // NB: This should not be necessary, but it doesn't seem like there is a better way to
      //     guarantee that the timer has started up. See this forum discussion for more information
      //     on the difficulties of testing async code in Swift:
      //     https://forums.swift.org/t/reliably-testing-code-that-adopts-swift-concurrency/57304
      try await Task.sleep(for: .milliseconds(300))

      XCTAssertEqual(model.speakerIndex, 0)
      XCTAssertEqual(model.durationRemaining, .seconds(3))

      await clock.advance(by: .seconds(1))
      XCTAssertEqual(model.speakerIndex, 1)
      XCTAssertEqual(model.durationRemaining, .seconds(2))
      XCTAssertEqual(soundEffectPlayCount.value, 1)

      await clock.advance(by: .seconds(1))
      XCTAssertEqual(model.speakerIndex, 2)
      XCTAssertEqual(model.durationRemaining, .seconds(1))
      XCTAssertEqual(soundEffectPlayCount.value, 2)

      await clock.advance(by: .seconds(1))
      XCTAssertEqual(model.speakerIndex, 2)
      XCTAssertEqual(model.durationRemaining, .seconds(0))
      XCTAssertEqual(soundEffectPlayCount.value, 2)

      await task.value

      await self.fulfillment(of: [onMeetingFinishedExpectation])
      XCTAssertEqual(soundEffectPlayCount.value, 2)
    }

    @MainActor
    func testRecordTranscript() async throws {
      let model = withDependencies {
        $0.continuousClock = ImmediateClock()
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
      } operation: {
        RecordMeetingModel(
          syncUp: SyncUp(
            id: SyncUp.ID(),
            attendees: [Attendee(id: Attendee.ID())],
            duration: .seconds(3)
          )
        )
      }

      let onMeetingFinishedExpectation = self.expectation(description: "onMeetingFinished")
      model.onMeetingFinished = {
        XCTAssertEqual($0, "I completed the project")
        onMeetingFinishedExpectation.fulfill()
      }

      await model.task()

      await self.fulfillment(of: [onMeetingFinishedExpectation])
    }

    @MainActor
    func testEndMeetingSave() async throws {
      let clock = TestClock()

      let model = withDependencies {
        $0.continuousClock = clock
        $0.soundEffectClient = .noop
        $0.speechClient.authorizationStatus = { .denied }
      } operation: {
        RecordMeetingModel(syncUp: .mock)
      }

      let onMeetingFinishedExpectation = self.expectation(description: "onMeetingFinished")
      model.onMeetingFinished = {
        XCTAssertEqual($0, "")
        onMeetingFinishedExpectation.fulfill()
      }

      let task = Task {
        await model.task()
      }

      model.endMeetingButtonTapped()

      let alert = try XCTUnwrap(model.destination?.alert)

      expectNoDifference(alert, .endMeeting(isDiscardable: true))

      await clock.advance(by: .seconds(5))

      XCTAssertEqual(model.speakerIndex, 0)
      XCTAssertEqual(model.durationRemaining, .seconds(60))

      await model.alertButtonTapped(.confirmSave)

      await self.fulfillment(of: [onMeetingFinishedExpectation])

      task.cancel()
      await task.value
    }

    @MainActor
    func testEndMeetingDiscard() async throws {
      let clock = TestClock()

      let model = withDependencies {
        $0.continuousClock = clock
        $0.soundEffectClient = .noop
        $0.speechClient.authorizationStatus = { .denied }
      } operation: {
        RecordMeetingModel(syncUp: .mock)
      }

      let task = Task {
        await model.task()
      }

      model.endMeetingButtonTapped()

      let alert = try XCTUnwrap(model.destination?.alert)

      expectNoDifference(alert, .endMeeting(isDiscardable: true))

      await model.alertButtonTapped(.confirmDiscard)

      task.cancel()
      await task.value
      XCTAssertEqual(model.isDismissed, true)
    }

    @MainActor
    func testNextSpeaker() async throws {
      let clock = TestClock()
      let soundEffectPlayCount = LockIsolated(0)

      let model = withDependencies {
        $0.continuousClock = clock
        $0.soundEffectClient = .noop
        $0.soundEffectClient.play = { soundEffectPlayCount.withValue { $0 += 1 } }
        $0.speechClient.authorizationStatus = { .denied }

      } operation: {
        RecordMeetingModel(
          syncUp: SyncUp(
            id: SyncUp.ID(),
            attendees: [
              Attendee(id: Attendee.ID()),
              Attendee(id: Attendee.ID()),
              Attendee(id: Attendee.ID()),
            ],
            duration: .seconds(3)
          )
        )
      }

      let onMeetingFinishedExpectation = self.expectation(description: "onMeetingFinished")
      model.onMeetingFinished = {
        XCTAssertEqual($0, "")
        onMeetingFinishedExpectation.fulfill()
      }

      let task = Task {
        await model.task()
      }

      model.nextButtonTapped()

      XCTAssertEqual(model.speakerIndex, 1)
      XCTAssertEqual(model.durationRemaining, .seconds(2))
      XCTAssertEqual(soundEffectPlayCount.value, 1)

      model.nextButtonTapped()

      XCTAssertEqual(model.speakerIndex, 2)
      XCTAssertEqual(model.durationRemaining, .seconds(1))
      XCTAssertEqual(soundEffectPlayCount.value, 2)

      model.nextButtonTapped()

      let alert = try XCTUnwrap(model.destination?.alert)

      expectNoDifference(alert, .endMeeting(isDiscardable: false))

      await clock.advance(by: .seconds(5))

      XCTAssertEqual(model.speakerIndex, 2)
      XCTAssertEqual(model.durationRemaining, .seconds(1))
      XCTAssertEqual(soundEffectPlayCount.value, 2)

      await model.alertButtonTapped(.confirmSave)

      await self.fulfillment(of: [onMeetingFinishedExpectation])
      XCTAssertEqual(soundEffectPlayCount.value, 2)

      task.cancel()
      await task.value
    }

    @MainActor
    func testSpeechRecognitionFailure_Continue() async throws {
      let model = withDependencies {
        $0.continuousClock = ImmediateClock()
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
      } operation: {
        RecordMeetingModel(
          syncUp: SyncUp(
            id: SyncUp.ID(),
            attendees: [Attendee(id: Attendee.ID())],
            duration: .seconds(3)
          )
        )
      }

      let onMeetingFinishedExpectation = self.expectation(description: "onMeetingFinished")
      model.onMeetingFinished = { transcript in
        XCTAssertEqual(transcript, "I completed the project ❌")
        onMeetingFinishedExpectation.fulfill()
      }

      let task = Task {
        await model.task()
      }

      // NB: This should not be necessary, but it doesn't seem like there is a better way to
      //     guarantee that the timer has started up. See this forum discussion for more information
      //     on the difficulties of testing async code in Swift:
      //     https://forums.swift.org/t/reliably-testing-code-that-adopts-swift-concurrency/57304
      try await Task.sleep(for: .milliseconds(100))

      let alert = try XCTUnwrap(model.destination?.alert)
      XCTAssertEqual(alert, .speechRecognizerFailed)

      model.destination = nil  // NB: Simulate SwiftUI closing alert.

      await task.value

      XCTAssertEqual(model.secondsElapsed, 3)
      await self.fulfillment(of: [onMeetingFinishedExpectation])
    }

    @MainActor
    func testSpeechRecognitionFailure_Discard() async throws {
      let clock = TestClock()

      let model = withDependencies {
        $0.continuousClock = clock
        $0.soundEffectClient = .noop
        $0.speechClient.authorizationStatus = { .authorized }
        $0.speechClient.startTask = { @Sendable _ in
          struct SpeechRecognitionFailure: Error {}
          return AsyncThrowingStream.finished(throwing: SpeechRecognitionFailure())
        }
      } operation: {
        RecordMeetingModel(
          syncUp: SyncUp(
            id: SyncUp.ID(),
            attendees: [Attendee(id: Attendee.ID())],
            duration: .seconds(3)
          )
        )
      }

      Task {
        await model.task()
      }

      // NB: This should not be necessary, but it doesn't seem like there is a better way to
      //     guarantee that the timer has started up. See this forum discussion for more information
      //     on the difficulties of testing async code in Swift:
      //     https://forums.swift.org/t/reliably-testing-code-that-adopts-swift-concurrency/57304
      try await Task.sleep(for: .milliseconds(100))

      let alert = try XCTUnwrap(model.destination?.alert)
      XCTAssertEqual(alert, .speechRecognizerFailed)

      await model.alertButtonTapped(.confirmDiscard)
      model.destination = nil  // NB: Simulate SwiftUI closing alert.

      XCTAssertEqual(model.isDismissed, true)
    }
  }
#endif
