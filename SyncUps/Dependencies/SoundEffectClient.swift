import AVFoundation
import Dependencies
import DependenciesMacros
import Synchronization

nonisolated protocol SoundEffectClient: Sendable {
  func load(fileName: String) async
  func play() async
}

extension DependencyValues {
  nonisolated var soundEffectClient: SoundEffectClient {
    get { self[SoundEffectClientKey.self] }
    set { self[SoundEffectClientKey.self] = newValue }
  }
}

nonisolated private enum SoundEffectClientKey: DependencyKey {
  static var liveValue: any SoundEffectClient {
    LiveSoundEffectClient()
  }
  static var testValue: any SoundEffectClient {
    UnimplementedSoundEffectClient()
  }
}

actor MockSoundEffectClient: SoundEffectClient {
  var loads: [String] = []
  var playCount = 0
  func load(fileName: String) {
    loads.append(fileName)
  }
  func play() {
    playCount += 1
  }
}

private struct UnimplementedSoundEffectClient: SoundEffectClient {
  func load(fileName: String) async {
    reportIssue("SoundEffectClient.load unimplemented")
  }
  func play() async {
    reportIssue("SoundEffectClient.play unimplemented")
  }
}

struct NoopSoundEffectClient: SoundEffectClient {
  func load(fileName: String) {}
  func play() {}
}

private actor LiveSoundEffectClient: SoundEffectClient {
  let player = AVPlayer()
  func load(fileName: String) {
    guard let url = Bundle.main.url(forResource: fileName, withExtension: "")
    else { return }
    player.replaceCurrentItem(with: AVPlayerItem(url: url))
  }
  func play() {
    player.seek(to: .zero)
    player.play()
  }
}
