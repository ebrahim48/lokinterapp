import FirebaseCore
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // FirebaseApp.configure() raises when GoogleService-Info.plist is not in the
    // bundle, which takes the whole app down at launch. PushService degrades to
    // "no push" in that case, and android/app/build.gradle.kts skips the Google
    // Services plugin the same way — so keep a fresh clone runnable here too, it
    // just gets no notifications.
    if Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil {
      // Configure Firebase before any plugin registers, so firebase_messaging is
      // already listening when APNs hands over the device token below.
      FirebaseApp.configure()
      // Asking APNs for a token here (rather than waiting on the permission
      // prompt) means FirebaseMessaging.getToken() has what it needs the first
      // time PushService asks — otherwise the first launch registers no token.
      application.registerForRemoteNotifications()
    } else {
      NSLog("GoogleService-Info.plist not found — running without Firebase; push notifications are disabled.")
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
