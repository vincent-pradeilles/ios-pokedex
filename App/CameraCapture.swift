import AVFoundation
import Observation
import UIKit

@MainActor
@Observable
final class CameraCapture {
  private(set) var isActive = false
  private(set) var isReady = false
  private(set) var isCapturing = false
  @ObservationIgnored var rotationAngle: CGFloat = 90
  @ObservationIgnored var previewSize: CGSize = .zero
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
      try await engine.start()
      guard generation == token else { return }
      isReady = true
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
    // Freeze the framing at the shutter so layout changes during capture cannot
    // change which part of the photo is retained.
    let viewport = previewSize
    let token = generation
    isCapturing = true
    do {
      let data = try await engine.capture(angle: rotationAngle)
      guard generation == token else { return nil }
      guard let image = UIImage(data: data) else {
        throw DexError.message("Couldn’t read the camera photo. Please try again.")
      }
      let cropped = CameraPhotoCrop.crop(image, to: viewport)
      return cropped
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
    isCapturing = false
    engine.stop()
  }
}

// All capture-session configuration and blocking operations run on this serial queue.
private final class CameraEngine: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
  let session = AVCaptureSession()
  private let queue = DispatchQueue(label: "PocketDex.camera")
  private let output = AVCapturePhotoOutput()
  private var pending: CheckedContinuation<Data, Error>?
  private var captureID: Int64?

  func start() async throws {
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
            self.session.sessionPreset = .photo
            guard self.session.canAddInput(input) else {
              self.session.commitConfiguration()
              throw DexError.message("Couldn’t connect to the camera. Please try again.")
            }
            self.session.addInput(input)
            guard self.session.canAddOutput(self.output) else {
              self.session.removeInput(input)
              self.session.commitConfiguration()
              throw DexError.message("Photo capture isn’t available. Choose a photo from your library instead.")
            }
            self.session.addOutput(self.output)
            self.session.commitConfiguration()
          }
          self.session.startRunning()
          guard self.session.isRunning else {
            throw DexError.message("Couldn’t start the camera. Please try again.")
          }
          continuation.resume()
        } catch { continuation.resume(throwing: error) }
      }
    }
  }

  func capture(angle: CGFloat) async throws -> Data {
    try await withCheckedThrowingContinuation { continuation in
      queue.async {
        guard self.session.isRunning, !self.session.isInterrupted, self.pending == nil else {
          continuation.resume(throwing: DexError.message("The camera is unavailable. Cancel and reopen the camera to try again."))
          return
        }
        self.pending = continuation
        if let connection = self.output.connection(with: .video), connection.isVideoRotationAngleSupported(angle) {
          connection.videoRotationAngle = angle
        }
        let settings = AVCapturePhotoSettings()
        self.captureID = settings.uniqueID
        self.output.capturePhoto(with: settings, delegate: self)
      }
    }
  }

  func stop() {
    queue.async {
      self.session.stopRunning()
      self.pending?.resume(throwing: CancellationError())
      self.pending = nil
      self.captureID = nil
    }
  }

  func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
    let data = photo.fileDataRepresentation()
    let id = photo.resolvedSettings.uniqueID
    queue.async {
      guard self.captureID == id else { return }
      if let error { self.pending?.resume(throwing: error) }
      else if let data { self.pending?.resume(returning: data) }
      else { self.pending?.resume(throwing: DexError.message("Couldn’t capture the photo. Please try again.")) }
      self.pending = nil
    }
  }
}
