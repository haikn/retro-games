import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}

/// Root view controller (set in Main.storyboard). Defers the system edge
/// gestures so holding near a screen edge flies instead of triggering the
/// home indicator or Control Center on the first swipe, and hides the
/// home indicator and status bar.
class GameViewController: FlutterViewController {
  override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .all }
  override var prefersHomeIndicatorAutoHidden: Bool { true }
  override var prefersStatusBarHidden: Bool { true }
}
