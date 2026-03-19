import Cocoa
import AVFoundation
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private let permissionsChannelName = "helium_flash_tuner/permissions"

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    configurePermissionChannel(for: flutterViewController)

    super.awakeFromNib()
  }

  private func configurePermissionChannel(for flutterViewController: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: permissionsChannelName,
      binaryMessenger: flutterViewController.engine.binaryMessenger)

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "requestMicrophoneAccess":
        self.requestMicrophoneAccess(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func requestMicrophoneAccess(result: @escaping FlutterResult) {
    switch AVCaptureDevice.authorizationStatus(for: .audio) {
    case .authorized:
      result(true)
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .audio) { granted in
        DispatchQueue.main.async {
          result(granted)
        }
      }
    case .denied, .restricted:
      result(false)
    @unknown default:
      result(false)
    }
  }
}
