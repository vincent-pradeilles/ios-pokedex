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
  private(set) var isSpeaking = false
  var error: String?
  @ObservationIgnored private var currentUtterance: AVSpeechUtterance?
  @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()

  override init() {
    automaticallyNarrates = UserDefaults.standard.object(forKey: "automaticallyNarrates") as? Bool ?? true
    voiceIdentifier = UserDefaults.standard.string(forKey: "narratorVoice") ?? ""
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
    // A compact male voice with lowered pitch evokes the electronic US delivery.
    // No downloaded actor recordings or cloned voice are used.
    return availableVoices.first { $0.gender == .male && $0.quality == .default }
      ?? availableVoices.first { $0.gender == .male }
      ?? AVSpeechSynthesisVoice(language: "en-US")
  }

  func narrate(_ entry: DexEntry) {
    guard entry.number > 0 else { return }
    speak("\(entry.name). Number \(entry.number). \(entry.type.replacingOccurrences(of: "/", with: " and ")) type. \(entry.summary)")
  }

  func preview() {
    speak("Pokédex online. Pikachu. The Electric type Pokémon. It stores electricity in the pouches on its cheeks.")
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
      utterance.rate = 0.43
      utterance.pitchMultiplier = 0.72
      utterance.volume = 1
      utterance.preUtteranceDelay = 0.15
      currentUtterance = utterance
      isSpeaking = true
      synthesizer.speak(utterance)
    } catch {
      self.error = "Couldn’t start narration. Please try again."
      finish()
    }
  }

  func stop() {
    currentUtterance = nil
    synthesizer.stopSpeaking(at: .immediate)
    finish()
  }

  private func finish() {
    currentUtterance = nil
    isSpeaking = false
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }

  nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
    Task { @MainActor [weak self] in
      guard let self, self.currentUtterance === utterance else { return }
      self.finish()
    }
  }

  nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
    Task { @MainActor [weak self] in
      guard let self, self.currentUtterance === utterance else { return }
      self.finish()
    }
  }
}
