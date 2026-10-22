import Flutter
import UIKit

/// Hands the saved servers' sign-in details to the home screen widgets, which
/// fetch their own data. They go into a Keychain group shared with the widget
/// extension (`WidgetKeychain`), not into the App Group's plain preferences.
final class WidgetCredentialsPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "hu.adrian.truenasmobile/widget_credentials",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(WidgetCredentialsPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "save":
      guard let json = call.arguments as? String, let data = json.data(using: .utf8) else {
        result(FlutterError(code: "bad_arguments", message: "Expected a JSON string", details: nil))
        return
      }
      if WidgetKeychain.save(data) {
        result(nil)
      } else {
        result(
          FlutterError(
            code: "no_keychain_group",
            message: "The widgets' Keychain group is not available in this install", details: nil))
      }
    case "clear":
      WidgetKeychain.delete()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
