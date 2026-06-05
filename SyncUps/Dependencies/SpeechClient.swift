import Dependencies
import DependenciesMacros
@preconcurrency import Speech

nonisolated protocol SpeechClient: Sendable {
  nonisolated var authorizationStatus: SFSpeechRecognizerAuthorizationStatus { get }
  func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus
  func startTask(
    request: SFSpeechAudioBufferRecognitionRequest
  ) async -> AsyncThrowingStream<SpeechRecognitionResult, Error>
}

extension DependencyValues {
  @DependencyEntry(liveValue: LiveSpeechClient(), previewValue: MockSpeechClient())
  nonisolated var speechClient: any SpeechClient = TestSpeechClient()
}

@dynamicMemberLookup
nonisolated struct TestSpeechClient: SpeechClient {
  struct Endpoints {
    var authorizationStatus: @Sendable () -> SFSpeechRecognizerAuthorizationStatus = {
      reportIssue("""
        'SpeechClient.authorizationStatus' unimplemented
        """)
      return .authorized
    }
    var requestAuthorization: @Sendable () async -> SFSpeechRecognizerAuthorizationStatus = {
      reportIssue("""
        'SpeechClient.requestAuthorization' unimplemented
        """)
      return .authorized
    }
    var startTask: @Sendable (_ request: SFSpeechAudioBufferRecognitionRequest) async -> AsyncThrowingStream<SpeechRecognitionResult, Error> = { _ in
      reportIssue("""
        'SpeechClient.startTask' unimplemented
        """)
      return .finished()
    }
  }
  var endpoints = Endpoints()
  subscript<Member>(dynamicMember keyPath: WritableKeyPath<Endpoints, Member>) -> Member {
    get {
      endpoints[keyPath: keyPath]
    }
    set {
      endpoints[keyPath: keyPath] = newValue
    }
  }
  nonisolated var authorizationStatus: SFSpeechRecognizerAuthorizationStatus {
    endpoints.authorizationStatus()
  }
  func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
    await endpoints.requestAuthorization()
  }
  func startTask(request: SFSpeechAudioBufferRecognitionRequest) async -> AsyncThrowingStream<SpeechRecognitionResult, any Error> {
    await endpoints.startTask(request)
  }
}

actor LiveSpeechClient: SpeechClient {
  private var audioEngine: AVAudioEngine? = nil
  private var recognitionTask: SFSpeechRecognitionTask? = nil
  private var recognitionContinuation: AsyncThrowingStream<SpeechRecognitionResult, Error>.Continuation?

  nonisolated var authorizationStatus: SFSpeechRecognizerAuthorizationStatus {
    SFSpeechRecognizer.authorizationStatus()
  }
  func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
    await withUnsafeContinuation { continuation in
      SFSpeechRecognizer.requestAuthorization { status in
        continuation.resume(returning: status)
      }
    }
  }

  func startTask(
    request: SFSpeechAudioBufferRecognitionRequest
  ) -> AsyncThrowingStream<SpeechRecognitionResult, Error> {
    AsyncThrowingStream { continuation in
      recognitionContinuation = continuation
      let audioSession = AVAudioSession.sharedInstance()
      do {
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
      } catch {
        continuation.finish(throwing: error)
        return
      }

      audioEngine = AVAudioEngine()
      let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
      recognitionTask = speechRecognizer.recognitionTask(with: request) { result, error in
        switch (result, error) {
        case let (.some(result), _):
          continuation.yield(SpeechRecognitionResult(result))
        case (_, .some):
          continuation.finish(throwing: error)
        case (.none, .none):
          fatalError("It should not be possible to have both a nil result and nil error.")
        }
      }

      continuation.onTermination = { [audioEngine, recognitionTask] _ in
        _ = speechRecognizer
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionTask?.finish()
      }

      audioEngine?.inputNode.installTap(
        onBus: 0,
        bufferSize: 1024,
        format: audioEngine?.inputNode.outputFormat(forBus: 0)
      ) { buffer, when in
        request.append(buffer)
      }

      audioEngine?.prepare()
      do {
        try audioEngine?.start()
      } catch {
        continuation.finish(throwing: error)
        return
      }
    }
  }
}

struct MockSpeechClient: SpeechClient {
  var failAfter: Duration = .seconds(Int.max)
  nonisolated var authorizationStatus: SFSpeechRecognizerAuthorizationStatus {
    .authorized
  }
  func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
    .authorized
  }
  func startTask(request: SFSpeechAudioBufferRecognitionRequest) async -> AsyncThrowingStream<SpeechRecognitionResult, any Error> {
    AsyncThrowingStream { continuation in
      let start = ContinuousClock.now
      Task {
        var finalText = """
          Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor \
          incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud \
          exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute \
          irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla \
          pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui \
          officia deserunt mollit anim id est laborum.
          """
        var text = ""
        while !finalText.isEmpty {
          guard ContinuousClock.now - start < failAfter
          else {
            struct SpeechRecognitionFailed: Error {}
            continuation.finish(throwing: SpeechRecognitionFailed())
            break
          }
          let word = finalText.prefix { $0 != " " }
          try await Task.sleep(for: .milliseconds(word.count * 50 + .random(in: 0...200)))
          finalText.removeFirst(word.count)
          if finalText.first == " " {
            finalText.removeFirst()
          }
          text += word + " "
          continuation.yield(
            SpeechRecognitionResult(
              bestTranscription: Transcription(
                formattedString: text
              ),
              isFinal: false
            )
          )
        }
      }
    }
  }
}

nonisolated struct SpeechRecognitionResult: Equatable {
  var bestTranscription: Transcription
  var isFinal: Bool
}

nonisolated struct Transcription: Equatable {
  var formattedString: String
}

nonisolated extension SpeechRecognitionResult {
  init(_ speechRecognitionResult: SFSpeechRecognitionResult) {
    self.bestTranscription = Transcription(speechRecognitionResult.bestTranscription)
    self.isFinal = speechRecognitionResult.isFinal
  }
}

nonisolated extension Transcription {
  init(_ transcription: SFTranscription) {
    self.formattedString = transcription.formattedString
  }
}
