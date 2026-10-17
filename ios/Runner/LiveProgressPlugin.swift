import ActivityKit
import Flutter
import UIKit

/// Starts, updates and ends the Live Activity of a running TrueNAS job.
///
/// Nothing pushes to the activities: the Dart side updates them while the app
/// runs. A few seconds of background time are requested when the app is left
/// so the last update still goes out; after that the activity turns stale
/// once its stale date passes.
final class LiveProgressPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "hu.adrian.truenasmobile/live_progress",
      binaryMessenger: registrar.messenger()
    )
    let instance = LiveProgressPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    NotificationCenter.default.addObserver(
      instance,
      selector: #selector(didEnterBackground),
      name: UIApplication.didEnterBackgroundNotification,
      object: nil
    )
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(iOS 16.2, *) else {
      switch call.method {
      case "isSupported", "requestPermission": result(false)
      case "status": result("unavailable")
      default: result(nil)
      }
      return
    }
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "status":
      result(status())
    case "isSupported", "requestPermission":
      // Live Activities need no permission prompt; the user can turn them
      // off for the app in Settings. Without the extension the system would
      // show an empty Dynamic Island, so none is started.
      result(status() == "ok")
    case "show":
      show(args, result: result)
    case "end":
      let id = args["id"] as? String
      end(where: { $0 == id })
      result(nil)
    case "endAllExcept":
      let keep = Set(args["keep"] as? [String] ?? [])
      end(where: { !keep.contains($0) })
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// ok, disabled (turned off for the app in iOS Settings) or noExtension.
  @available(iOS 16.2, *)
  private func status() -> String {
    guard extensionEmbedded() else { return "noExtension" }
    return ActivityAuthorizationInfo().areActivitiesEnabled ? "ok" : "disabled"
  }

  /// Whether the JobActivityWidget extension, which draws the activity, is in
  /// the app. Some sideloading tools remove app extensions.
  private func extensionEmbedded() -> Bool {
    guard let plugIns = Bundle.main.builtInPlugInsURL,
      let items = try? FileManager.default.contentsOfDirectory(
        at: plugIns, includingPropertiesForKeys: nil)
    else { return false }
    return items.contains {
      $0.pathExtension == "appex" && $0.lastPathComponent.hasPrefix("JobActivityWidget")
    }
  }

  @available(iOS 16.2, *)
  private func show(_ args: [String: Any], result: @escaping FlutterResult) {
    guard let id = args["id"] as? String else {
      result(FlutterError(code: "bad_args", message: "id is missing", details: nil))
      return
    }
    let status = args["status"] as? String ?? "running"
    let isFinal = status == "done" || status == "failed" || status == "aborted"
    let state = JobActivityAttributes.ContentState(
      detail: args["detail"] as? String ?? "",
      progress: args["progress"] as? Double,
      status: status,
      statusLabel: args["statusLabel"] as? String ?? "",
      staleLabel: args["staleLabel"] as? String ?? ""
    )
    // The app sends news every 30 seconds while it follows the job; without
    // it the activity turns stale. A lost connection turns it stale at once.
    let staleDate: Date? =
      isFinal ? nil : (status == "stale" ? Date() : Date().addingTimeInterval(90))
    let content = ActivityContent(state: state, staleDate: staleDate)

    if let activity = Activity<JobActivityAttributes>.activities.first(where: {
      $0.attributes.jobId == id && $0.activityState != .ended && $0.activityState != .dismissed
    }) {
      Task {
        if isFinal {
          // Leave the result on the lock screen for a while.
          await activity.end(content, dismissalPolicy: .after(Date().addingTimeInterval(15 * 60)))
        } else {
          await activity.update(content)
        }
      }
      result(nil)
      return
    }
    // A job that was never seen running does not get an activity of its own.
    if isFinal {
      result(nil)
      return
    }
    let startedAt = Date(timeIntervalSince1970: (args["startedAt"] as? Double ?? 0) / 1000)
    let attributes = JobActivityAttributes(
      jobId: id,
      kind: args["kind"] as? String ?? "",
      title: args["title"] as? String ?? "",
      server: args["server"] as? String ?? "",
      startedAt: startedAt
    )
    do {
      _ = try Activity.request(attributes: attributes, content: content, pushType: nil)
      result(nil)
    } catch {
      result(FlutterError(code: "request_failed", message: error.localizedDescription, details: nil))
    }
  }

  @available(iOS 16.2, *)
  private func end(where matches: @escaping (String) -> Bool) {
    for activity in Activity<JobActivityAttributes>.activities
    where matches(activity.attributes.jobId) {
      Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
  }

  /// Asks for a little time to send the last update when the app is left.
  @objc private func didEnterBackground() {
    guard #available(iOS 16.2, *), !Activity<JobActivityAttributes>.activities.isEmpty else {
      return
    }
    var task = UIBackgroundTaskIdentifier.invalid
    task = UIApplication.shared.beginBackgroundTask(withName: "job-progress") {
      UIApplication.shared.endBackgroundTask(task)
      task = .invalid
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 25) {
      if task != .invalid {
        UIApplication.shared.endBackgroundTask(task)
        task = .invalid
      }
    }
  }
}
