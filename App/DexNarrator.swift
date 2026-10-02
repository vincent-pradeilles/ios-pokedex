import AVFoundation
import Observation

@MainActor @Observable
final class DexNarrator: NSObject, AVSpeechSynthesizerDelegate {
  var automaticallyNarrates: Bool {
    didSet {
      UserDefaults.standard.set(automaticallyNarrates, forKey: "automaticallyNarrates")
      if !automaticallyNarrates { stop() }
    }
  }
  var voiceIdentifier: String {
    didSet {
      UserDefaults.standard.set(voiceIdentifier, forKey: "narratorVoice")
      stop()
    }
  }
  var electronicEffect: Bool {
    didSet {
      UserDefaults.standard.set(electronicEffect, forKey: "narratorElectronicEffect")
      stop()
    }
  }
  private(set) var isSpeaking = false
  var error: String?
  @ObservationIgnored private let voicePlayer = DexVoicePlayer()
  @ObservationIgnored private var renderedBuffers: [AVAudioPCMBuffer] = []
  @ObservationIgnored private var renderToken = UUID()
  @ObservationIgnored private var currentUtterance: AVSpeechUtterance?
  @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()

  override init() {
    automaticallyNarrates = UserDefaults.standard.object(forKey: "automaticallyNarrates") as? Bool ?? true
    voiceIdentifier = UserDefaults.standard.string(forKey: "narratorVoice") ?? ""
    electronicEffect = UserDefaults.standard.object(forKey: "narratorElectronicEffect") as? Bool ?? true
    super.init()
    synthesizer.delegate = self
  }

  var availableVoices: [AVSpeechSynthesisVoice] {
    AVSpeechSynthesisVoice.speechVoices()
      .filter { $0.language == "en-US" && !$0.voiceTraits.contains(.isPersonalVoice) }
      .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
  }

  private var voice: AVSpeechSynthesisVoice? {
    if !voiceIdentifier.isEmpty, let chosen = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
      return chosen
    }
    // A compact male voice provides a measured base for the electronic treatment.
    // No downloaded actor recordings or cloned voice are used.
    return availableVoices.first { $0.gender == .male && $0.quality == .default }
      ?? availableVoices.first { $0.gender == .male }
      ?? AVSpeechSynthesisVoice(language: "en-US")
  }

  func narrate(_ entry: DexEntry) {
    guard entry.number > 0 else { return }
    speak("\(entry.name). \(entry.type.replacingOccurrences(of: "/", with: " and ")) type Pokémon. \(entry.summary)")
  }

  func preview() {
    speak("Bulbasaur. The Seed Pokémon. A seed grows on its back, storing energy as it grows.")
  }

  private func speak(_ text: String) {
    stop()
    guard let voice else {
      error = "A US-English speech voice isn’t available on this device. Add an English voice in system Accessibility settings."
      return
    }
    do {
      let audio = AVAudioSession.sharedInstance()
      try audio.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
      try audio.setActive(true)
      let utterance = AVSpeechUtterance(string: text)
      utterance.voice = voice
      utterance.rate = 0.47
      utterance.pitchMultiplier = 0.94
      utterance.volume = 1
      utterance.preUtteranceDelay = 0.15
      currentUtterance = utterance
      isSpeaking = true
      let token = renderToken
      synthesizer.write(utterance) { [weak self] buffer in
        guard let pcm = buffer as? AVAudioPCMBuffer else { return }
        let finished = pcm.frameLength == 0
        let copied = finished ? nil : DexVoicePlayer.copy(pcm)
        // Dispatch FIFO keeps rendered chunks in their original order.
        DispatchQueue.main.async { [weak self] in
          guard let self, self.renderToken == token else { return }
          if let copied { self.renderedBuffers.append(copied) }
          if !finished && copied == nil {
            self.error = "Couldn’t prepare narration audio. Please try again."
            self.stop()
          } else if finished {
            self.playRenderedSpeech(token: token)
          }
        }
      }
    } catch {
      self.error = "Couldn’t start narration. Please try again."
      finish()
    }
  }

  func stop() {
    renderToken = UUID()
    renderedBuffers.removeAll()
    voicePlayer.stop()
    currentUtterance = nil
    synthesizer.stopSpeaking(at: .immediate)
    finish()
  }

  private func finish() {
    currentUtterance = nil
    isSpeaking = false
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }

  private func playRenderedSpeech(token: UUID) {
    guard !renderedBuffers.isEmpty else {
      error = "The selected voice couldn’t render audio. Try another US-English voice in Settings."
      finish()
      return
    }
    do {
      try voicePlayer.play(renderedBuffers, electronic: electronicEffect) { [weak self] in
        guard let self, self.renderToken == token else { return }
        self.voicePlayer.stop()
        self.renderedBuffers.removeAll()
        self.finish()
      }
    } catch {
      self.error = "Couldn’t play narration. Please try again."
      stop()
    }
  }

  // Speech synthesis finishing means buffers are ready, not that playback ended.
  // The audio player's dataPlayedBack callback owns normal completion.
  nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
    Task { @MainActor [weak self] in
      guard let self, self.currentUtterance === utterance else { return }
      self.stop()
    }
  }
}
