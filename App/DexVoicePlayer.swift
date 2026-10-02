import AVFoundation

/// Plays synthesized PCM through a restrained electronic speaker treatment.
/// The reference recording is not included or played by the app.
@MainActor
final class DexVoicePlayer {
  private let engine = AVAudioEngine()
  private let player = AVAudioPlayerNode()
  private let equalizer = AVAudioUnitEQ(numberOfBands: 3)
  private let distortion = AVAudioUnitDistortion()
  private let doubling = AVAudioUnitDelay()
  private var generation = UUID()

  init() {
    engine.attach(player)
    engine.attach(equalizer)
    engine.attach(distortion)
    engine.attach(doubling)

    let lowCut = equalizer.bands[0]
    lowCut.filterType = .highPass
    lowCut.frequency = 230
    lowCut.bypass = false
    let presence = equalizer.bands[1]
    presence.filterType = .parametric
    presence.frequency = 1900
    presence.bandwidth = 1.4
    presence.gain = 3
    presence.bypass = false
    let highCut = equalizer.bands[2]
    highCut.filterType = .lowPass
    highCut.frequency = 4800
    highCut.bypass = false
    equalizer.globalGain = -3

    distortion.loadFactoryPreset(.speechRadioTower)
    distortion.preGain = -6
    distortion.wetDryMix = 7
    doubling.delayTime = 0.009
    doubling.feedback = 0
    doubling.lowPassCutoff = 4800
    doubling.wetDryMix = 10
  }

  func play(_ buffers: [AVAudioPCMBuffer], electronic: Bool, completion: @escaping @MainActor () -> Void) throws {
    stop()
    guard let first = buffers.first else { completion(); return }
    let token = generation
    let format = first.format
    engine.connect(player, to: equalizer, format: format)
    engine.connect(equalizer, to: distortion, format: format)
    engine.connect(distortion, to: doubling, format: format)
    engine.connect(doubling, to: engine.mainMixerNode, format: format)
    equalizer.bypass = !electronic
    distortion.bypass = !electronic
    doubling.bypass = !electronic
    engine.prepare()
    try engine.start()
    for (index, buffer) in buffers.enumerated() {
      if index == buffers.count - 1 {
        player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
          Task { @MainActor in
            guard let self, self.generation == token else { return }
            completion()
          }
        }
      } else {
        player.scheduleBuffer(buffer)
      }
    }
    player.play()
  }

  func stop() {
    generation = UUID()
    player.stop()
    engine.stop()
  }

  nonisolated static func copy(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
    guard let result = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength) else { return nil }
    result.frameLength = buffer.frameLength
    let source = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: buffer.audioBufferList))
    let destination = UnsafeMutableAudioBufferListPointer(result.mutableAudioBufferList)
    for index in 0..<source.count {
      guard let input = source[index].mData, let output = destination[index].mData else { return nil }
      memcpy(output, input, Int(source[index].mDataByteSize))
    }
    return result
  }
}
