import Flutter
import UIKit
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // The background alert check starts a second Flutter engine without a
    // screen; it needs the plugins (secure storage, notifications) there too.
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    // With the scene lifecycle the plugin cannot register the check in time
    // by itself.
    WorkmanagerPlugin.registerLaunchHandlers()
    // iOS only accepts a BGTask handler registered before launch finishes;
    // registering later (what the Dart side does the first time the setting is
    // turned on) raises an exception that cannot be caught and kills the app.
    // The id must match `_taskName` in background_alerts.dart and Info.plist.
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "hu.adrian.truenasmobile.alertCheck",
      earliestBeginInSeconds: NSNumber(value: 15 * 60))
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Progress of running jobs as a Live Activity.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LiveProgressPlugin") {
      LiveProgressPlugin.register(with: registrar)
    }
  }
}
