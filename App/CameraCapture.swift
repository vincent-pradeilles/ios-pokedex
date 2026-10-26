import AVFoundation
import Observation
import CoreImage
import UIKit

@MainActor
@Observable
final class CameraCapture {
  private(set) var isActive = false
  private(set) var isReady = false
  private(set) var isSessionRunning = false
  private(set) var isCapturing = false
  @ObservationIgnored var rotationAngle: CGFloat = 90 {
    didSet {
      if rotationAngle != oldValue { engine.updateRotation(rotationAngle) }
    }
  }
  @ObservationIgnored var previewSize: CGSize = .zero {
    didSet {
      if previewSize != oldValue { engine.updateViewport(previewSize) }
    }
  }
  private let engine = CameraEngine()
  private var generation = UUID()
  var session: AVCaptureSession { engine.session }

  func start() async throws {
    guard !isActive else { return }
    let token = UUID()
    generation = token
    isActive = true
    let granted = await AVCaptureDevice.requestAccess(for: .video)
    guard generation == token else { return }
    guard granted else {
      stop()
      throw DexError.message("Camera access is off. Allow it in system Settings, or choose a photo from your library.")
    }
    do {
      try await engine.start { [weak self] in
        Task { @MainActor in
          guard let self, self.generation == token else { return }
          self.isReady = true
        }
      }
      guard generation == token else { return }
      isSessionRunning = true
    } catch {
      guard generation == token else { return }
      stop()
      throw error
    }
  }

  func capture() async throws -> UIImage? {
    guard isReady, !isCapturing else { return nil }
    guard previewSize.width > 0, previewSize.height > 0 else {
      throw DexError.message("The camera preview is still starting. Please try again.")
    }
    // Take the latest prepared snapshot; no image conversion runs on the tap.
    let token = generation
    isCapturing = true
    CaptureTiming.mark("shutter tapped")
    do {
      let image = try await engine.capture()
      guard generation == token else { return nil }
      CaptureTiming.mark("prepared frame delivered")
      return image
    } catch {
      guard generation == token else { return nil }
      isCapturing = false
      throw error
    }
  }

  func stop() {
    generation = UUID()
    isActive = false
    isReady = false
    isSessionRunning = false
    isCapturing = false
    engine.stop()
  }
}

// Capture the latest preview frame instead of waiting for the still-photo pipeline.
// Session changes, frame delivery, and rendering share a serial queue.
private final class CameraEngine: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
  let session = AVCaptureSession()
  private let queue = DispatchQueue(label: "PocketDex.camera", qos: .userInitiated)
  private let output = AVCaptureVideoDataOutput()
  private let context = CIContext()
  private var latestPhoto: UIImage?
  private var viewport: CGSize = .zero
  private var lastRenderedAt: TimeInterval = 0
  private var onFrameReady: (@Sendable () -> Void)?
  private var rotationAngle: CGFloat = 90

  func start(onFrameReady: @escaping @Sendable () -> Void) async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      queue.async {
        do {
          if self.session.inputs.isEmpty {
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
              ?? AVCaptureDevice.default(for: .video) else {
              throw DexError.message("A camera isn’t available here. Choose a photo from your library instead.")
            }
            let input = try AVCaptureDeviceInput(device: device)
            self.session.beginConfiguration()
            defer { self.session.commitConfiguration() }
            self.session.sessionPreset = self.session.canSetSessionPreset(.hd1920x1080) ? .hd1920x1080 : .high
            guard self.session.canAddInput(input) else {
              throw DexError.message("Couldn’t connect to the camera. Please try again.")
            }
            self.session.addInput(input)
            guard self.session.canAddOutput(self.output) else {
              self.session.removeInput(input)
              throw DexError.message("Camera capture isn’t available. Choose a photo from your library instead.")
            }
            self.output.alwaysDiscardsLateVideoFrames = true
            self.output.setSampleBufferDelegate(self, queue: self.queue)
            self.session.addOutput(self.output)
            self.configureConnection()
          }
          self.latestPhoto = nil
          self.lastRenderedAt = 0
          self.onFrameReady = onFrameReady
          self.session.startRunning()
          guard self.session.isRunning else {
            throw DexError.message("Couldn’t start the camera. Please try again.")
          }
          continuation.resume()
        } catch { continuation.resume(throwing: error) }
      }
    }
  }

  func updateRotation(_ angle: CGFloat) {
    queue.async {
      self.rotationAngle = angle
      self.latestPhoto = nil
      self.configureConnection()
    }
  }

  private func configureConnection() {
    guard let connection = output.connection(with: .video) else { return }
    if connection.isVideoRotationAngleSupported(rotationAngle) {
      connection.videoRotationAngle = rotationAngle
    }
    if connection.isVideoMirroringSupported {
      connection.automaticallyAdjustsVideoMirroring = false
      connection.isVideoMirrored = false
    }
    if connection.isVideoStabilizationSupported {
      connection.preferredVideoStabilizationMode = .off
    }
  }

  func updateViewport(_ viewport: CGSize) {
    queue.async {
      self.viewport = viewport
      self.latestPhoto = nil
      self.lastRenderedAt = 0
    }
  }

  func capture() async throws -> UIImage {
    try await withCheckedThrowingContinuation { continuation in
      queue.async {
        guard self.session.isRunning, !self.session.isInterrupted, let photo = self.latestPhoto else {
          continuation.resume(throwing: DexError.message("The camera is still getting ready. Please try again."))
          return
        }
        CaptureTiming.mark("prepared frame selected")
        continuation.resume(returning: photo)
      }
    }
  }

  func stop() {
    queue.async {
      self.latestPhoto = nil
      self.onFrameReady = nil
      self.session.stopRunning()
    }
  }

  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    // Prepare snapshots while the user frames the subject, never on the shutter
    // path. Retain only the latest image, and limit CPU/GPU readback to 15 fps.
    let now = ProcessInfo.processInfo.systemUptime
    guard viewport.width > 0, viewport.height > 0,
          now - lastRenderedAt >= 1.0 / 15,
          let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    lastRenderedAt = now
    autoreleasepool {
      let image = CIImage(cvPixelBuffer: buffer)
      guard let cgImage = context.createCGImage(image, from: image.extent) else { return }
      latestPhoto = CameraPhotoCrop.crop(UIImage(cgImage: cgImage), to: viewport)
    }
    if latestPhoto != nil, let ready = onFrameReady {
      onFrameReady = nil
      ready()
    }
  }
}
