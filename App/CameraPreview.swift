import AVFoundation
import SwiftUI

struct CameraPreview: UIViewRepresentable {
  var camera: CameraCapture

  func makeUIView(context: Context) -> CameraPreviewView {
    let view = CameraPreviewView()
    view.previewLayer.session = camera.session
    view.previewLayer.videoGravity = .resizeAspectFill
    view.onFraming = { size, angle in
      camera.previewSize = size
      camera.rotationAngle = angle
    }
    return view
  }

  func updateUIView(_ view: CameraPreviewView, context: Context) {
    if camera.isReady { view.updateRotation() }
  }

  static func dismantleUIView(_ view: CameraPreviewView, coordinator: ()) {
    view.previewLayer.session = nil
  }
}

final class CameraPreviewView: UIView {
  override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
  var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
  var onFraming: ((CGSize, CGFloat) -> Void)?

  private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
  private var rotationObservation: NSKeyValueObservation?

  override func layoutSubviews() {
    super.layoutSubviews()
    updateRotation()
  }

  func updateRotation() {
    if rotationCoordinator == nil,
       let input = previewLayer.session?.inputs.first as? AVCaptureDeviceInput {
      let coordinator = AVCaptureDevice.RotationCoordinator(device: input.device, previewLayer: previewLayer)
      rotationCoordinator = coordinator
      rotationObservation = coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.new]) { [weak self] _, _ in
        Task { @MainActor in self?.updateRotation() }
      }
    }
    guard let coordinator = rotationCoordinator else { return }
    let angle = coordinator.videoRotationAngleForHorizonLevelPreview
    if let connection = previewLayer.connection, connection.isVideoRotationAngleSupported(angle) {
      connection.videoRotationAngle = angle
    }
    // Capture uses the same rotation as the visible preview, not a separately
    // horizon-leveled angle that could rotate the subject at the shutter.
    onFraming?(bounds.size, angle)
  }
}
