import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var settingsChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 로컬 일정 알림: 앱이 포그라운드일 때도 알림이 표시되도록 델리게이트 지정.
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerSettingsChannel(messenger: engineBridge.applicationRegistrar.messenger())
  }

  private func registerSettingsChannel(messenger: FlutterBinaryMessenger) {
    settingsChannel = FlutterMethodChannel(
      name: "com.sidore.catholiccalendar/settings",
      binaryMessenger: messenger
    )
    settingsChannel?.setMethodCallHandler { call, result in
      if call.method == "openNotificationSettings" {
        if let url = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(url, options: [:])
        }
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
